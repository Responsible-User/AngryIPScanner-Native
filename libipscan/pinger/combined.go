package pinger

import (
	"net"
	"time"
)

// CombinedPinger uses both UDP and TCP for pinging — the best default for unprivileged users.
type CombinedPinger struct {
	tcp *TCPPinger
	udp *UDPPinger
}

// NewCombinedPinger creates a combined TCP+UDP pinger.
func NewCombinedPinger(timeout time.Duration) *CombinedPinger {
	return &CombinedPinger{
		tcp: NewTCPPinger(timeout),
		udp: NewUDPPinger(timeout),
	}
}

func (p *CombinedPinger) ID() string { return "pinger.combined" }

func (p *CombinedPinger) Ping(address net.IP, count int, timeout time.Duration) (*PingResult, error) {
	// Try UDP first — generally more reliable
	udpCount := count / 2
	if udpCount < 1 {
		udpCount = 1
	}

	udpResult, err := p.udp.Ping(address, udpCount, timeout)
	if err != nil {
		return udpResult, err
	}

	if udpResult.IsAlive() {
		// UDP worked, do the rest with UDP too
		remaining := count - udpCount
		if remaining > 0 {
			moreResult, _ := p.udp.Ping(address, remaining, timeout)
			udpResult.Merge(moreResult)
		}
		return udpResult, nil
	}

	// Fallback to TCP
	return p.tcp.Ping(address, count, timeout)
}

func (p *CombinedPinger) Close() error { return nil }
