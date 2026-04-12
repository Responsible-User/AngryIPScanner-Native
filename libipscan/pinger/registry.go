package pinger

import "time"

// NewPinger creates a Pinger by ID. If the ID is unknown, returns a CombinedPinger.
func NewPinger(id string, timeout time.Duration) Pinger {
	switch id {
	case "pinger.tcp":
		return NewTCPPinger(timeout)
	case "pinger.udp":
		return NewUDPPinger(timeout)
	case "pinger.icmp":
		return NewICMPPinger(timeout)
	case "pinger.combined":
		return NewCombinedPinger(timeout)
	default:
		return NewCombinedPinger(timeout)
	}
}
