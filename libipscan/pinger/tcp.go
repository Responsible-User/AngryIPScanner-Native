package pinger

import (
	"fmt"
	"net"
	"strings"
	"time"
)

// ProbeTCPPorts are tried in sequence until one works.
// Covers HTTP, HTTPS, SSH, NetBIOS, SMB, RDP, and HTTP alternates so
// hosts that only expose one common service are still detected as alive.
var ProbeTCPPorts = []int{80, 443, 22, 3389, 445, 139, 8080, 7}

// TCPPinger probes host reachability via TCP connect. No root privileges required.
type TCPPinger struct {
	timeout time.Duration
}

// NewTCPPinger creates a TCP pinger with the given timeout.
func NewTCPPinger(timeout time.Duration) *TCPPinger {
	return &TCPPinger{timeout: timeout}
}

func (p *TCPPinger) ID() string { return "pinger.tcp" }

func (p *TCPPinger) Ping(address net.IP, count int, timeout time.Duration) (*PingResult, error) {
	if timeout == 0 {
		timeout = p.timeout
	}
	result := NewPingResult(address, count)
	workingPort := -1

	for i := 0; i < count; i++ {
		probePort := ProbeTCPPorts[i%len(ProbeTCPPorts)]
		if workingPort >= 0 {
			probePort = workingPort
		}

		start := time.Now()
		effectiveTimeout := timeout
		if result.TimeoutAdaptAllowed && result.LongestTime > 0 {
			adapted := time.Duration(result.LongestTime*2) * time.Millisecond
			if adapted < effectiveTimeout {
				effectiveTimeout = adapted
			}
		}

		addr := net.JoinHostPort(address.String(), fmt.Sprintf("%d", probePort))
		conn, err := net.DialTimeout("tcp", addr, effectiveTimeout)
		elapsed := time.Since(start).Milliseconds()

		if conn != nil {
			conn.Close()
			result.AddReply(elapsed)
			result.TimeoutAdaptAllowed = true
			workingPort = probePort
			continue
		}

		if err != nil {
			msg := err.Error()
			if strings.Contains(msg, "refused") || strings.Contains(msg, "forcibly closed") {
				// RST / connection reset — host is alive
				result.AddReply(elapsed)
				result.TimeoutAdaptAllowed = true
				workingPort = probePort
			} else if strings.Contains(msg, "route to host") ||
				strings.Contains(msg, "down") ||
				strings.Contains(msg, "unreachable") {
				// Host is down, stop trying
				break
			}
			// Timeout or other error — just continue
		}
	}

	return result, nil
}

func (p *TCPPinger) Close() error { return nil }
