package pinger

import (
	"encoding/binary"
	"net"
	"strings"
	"time"
)

const probeUDPPort = 33435

// UDPPinger probes host reachability via UDP. No root privileges required.
type UDPPinger struct {
	timeout time.Duration
}

// NewUDPPinger creates a UDP pinger with the given timeout.
func NewUDPPinger(timeout time.Duration) *UDPPinger {
	return &UDPPinger{timeout: timeout}
}

func (p *UDPPinger) ID() string { return "pinger.udp" }

func (p *UDPPinger) Ping(address net.IP, count int, timeout time.Duration) (*PingResult, error) {
	if timeout == 0 {
		timeout = p.timeout
	}
	result := NewPingResult(address, count)

	conn, err := net.DialTimeout("udp", net.JoinHostPort(address.String(), "33435"), timeout)
	if err != nil {
		return result, nil
	}
	defer conn.Close()

	for i := 0; i < count; i++ {
		start := time.Now()

		// Send a small payload with timestamp
		payload := make([]byte, 8)
		binary.BigEndian.PutUint64(payload, uint64(start.UnixMilli()))

		conn.SetDeadline(time.Now().Add(timeout))
		_, err := conn.Write(payload)
		if err != nil {
			if isHostDown(err) {
				break
			}
			continue
		}

		buf := make([]byte, 64)
		_, err = conn.Read(buf)
		elapsed := time.Since(start).Milliseconds()

		if err != nil {
			if isPortUnreachable(err) {
				// ICMP port unreachable — host is alive
				result.AddReply(elapsed)
			} else if isHostDown(err) {
				break
			}
			// Timeout or other error — continue
		} else {
			// Got a response (unlikely for UDP to random port)
			result.AddReply(elapsed)
		}
	}

	return result, nil
}

func (p *UDPPinger) Close() error { return nil }

func isPortUnreachable(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "connection refused")
}

func isHostDown(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "route to host") ||
		strings.Contains(msg, "unreachable") ||
		strings.Contains(msg, "down")
}
