// Package scanner provides the core scanning engine types and orchestration.
package scanner

import (
	"net"
	"sync"
)

// ResultType indicates the result of scanning an IP address.
type ResultType int

const (
	ResultUnknown  ResultType = iota
	ResultDead
	ResultAlive
	ResultWithPorts
)

// Matches returns true if this result type matches the filter.
// UNKNOWN and DEAD match each other; ALIVE matches ALIVE and WITH_PORTS.
func (rt ResultType) Matches(other ResultType) bool {
	if rt <= ResultDead {
		return other <= ResultDead
	}
	return rt <= other
}

// ScanningSubject represents a single IP address being scanned.
type ScanningSubject struct {
	Address          net.IP
	InterfaceName    string
	InterfaceAddr    net.IP
	BroadcastAddr    net.IP
	PrefixLen        int
	RequestedPorts   []int
	ResultType       ResultType
	Aborted          bool
	AdaptedPortTimeout int

	mu         sync.RWMutex
	parameters map[string]interface{}
}

// NewScanningSubject creates a new scanning subject for the given IP.
func NewScanningSubject(address net.IP) *ScanningSubject {
	return &ScanningSubject{
		Address:            address,
		ResultType:         ResultUnknown,
		AdaptedPortTimeout: -1,
		parameters:         make(map[string]interface{}),
	}
}

// SetParameter stores an arbitrary parameter (used for inter-fetcher communication).
func (s *ScanningSubject) SetParameter(name string, value interface{}) {
	s.mu.Lock()
	s.parameters[name] = value
	s.mu.Unlock()
}

// GetParameter retrieves a named parameter.
func (s *ScanningSubject) GetParameter(name string) (interface{}, bool) {
	s.mu.RLock()
	v, ok := s.parameters[name]
	s.mu.RUnlock()
	return v, ok
}

// IsIPv6 returns true if the address is IPv6.
func (s *ScanningSubject) IsIPv6() bool {
	return s.Address.To4() == nil
}

// IsLocal returns true if interface info is available (LAN scan).
func (s *ScanningSubject) IsLocal() bool {
	return s.InterfaceAddr != nil
}

// String returns the address as a string, with ports if any.
func (s *ScanningSubject) String() string {
	str := s.Address.String()
	if len(s.RequestedPorts) > 0 {
		str += ":"
		for i, port := range s.RequestedPorts {
			if i > 0 {
				str += ","
			}
			str += string(rune('0' + port)) // placeholder - will use fmt
		}
	}
	return str
}
