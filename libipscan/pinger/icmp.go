package pinger

import (
	"net"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var (
	ttlRegex  = regexp.MustCompile(`ttl=(\d+)`)
	timeRegex = regexp.MustCompile(`time[=<]([\d.]+)\s*ms`)
)

// ICMPPinger uses the system ping command for ICMP echo.
// This avoids the need for raw socket privileges.
type ICMPPinger struct {
	timeout time.Duration
}

// NewICMPPinger creates an ICMP pinger that shells out to /sbin/ping.
func NewICMPPinger(timeout time.Duration) *ICMPPinger {
	return &ICMPPinger{timeout: timeout}
}

func (p *ICMPPinger) ID() string { return "pinger.icmp" }

func (p *ICMPPinger) Ping(address net.IP, count int, timeout time.Duration) (*PingResult, error) {
	if timeout == 0 {
		timeout = p.timeout
	}
	result := NewPingResult(address, count)

	timeoutSec := int(timeout.Seconds())
	if timeoutSec < 1 {
		timeoutSec = 1
	}

	// Run system ping command
	// macOS ping: -c count -W timeout_ms -q (quiet) or without -q for parseable output
	args := []string{
		"-c", strconv.Itoa(count),
		"-W", strconv.Itoa(int(timeout.Milliseconds())),
		address.String(),
	}

	cmd := exec.Command("ping", args...)
	output, _ := cmd.CombinedOutput()
	// We don't check error because ping returns non-zero for unreachable hosts

	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		// Look for reply lines like: "64 bytes from 127.0.0.1: icmp_seq=0 ttl=64 time=0.042 ms"
		if !strings.Contains(line, "bytes from") {
			continue
		}

		// Extract TTL
		if m := ttlRegex.FindStringSubmatch(line); len(m) > 1 {
			if ttl, err := strconv.Atoi(m[1]); err == nil {
				result.TTL = ttl
			}
		}

		// Extract time
		if m := timeRegex.FindStringSubmatch(line); len(m) > 1 {
			if t, err := strconv.ParseFloat(m[1], 64); err == nil {
				result.AddReply(int64(t))
			}
		}
	}

	return result, nil
}

func (p *ICMPPinger) Close() error { return nil }
