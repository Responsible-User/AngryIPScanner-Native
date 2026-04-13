package pinger

import "time"

// Platform-specific pingers registered via init() in build-tagged files.
var platformPingers = map[string]func(time.Duration) Pinger{}

// NewPinger creates a Pinger by ID. If the ID is unknown, returns a CombinedPinger.
func NewPinger(id string, timeout time.Duration) Pinger {
	// Check platform-specific pingers first (e.g. pinger.windows)
	if factory, ok := platformPingers[id]; ok {
		return factory(timeout)
	}

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
