package scanner

import (
	"net"
	"sync"
)

// ScanningResult holds the results for a single scanned IP address.
type ScanningResult struct {
	Address net.IP
	MAC     string
	Values  []interface{}
	Type    ResultType
}

// NewScanningResult creates a new result for the given address with space for numFetchers values.
func NewScanningResult(address net.IP, numFetchers int) *ScanningResult {
	values := make([]interface{}, numFetchers)
	values[0] = address.String()
	return &ScanningResult{
		Address: address,
		Values:  values,
		Type:    ResultUnknown,
	}
}

// Reset returns the result to an unscanned state (for rescanning).
func (r *ScanningResult) Reset(numFetchers int) {
	r.Values = make([]interface{}, numFetchers)
	r.Values[0] = r.Address.String()
	r.Type = ResultUnknown
	r.MAC = ""
}

// IsReady returns true if the result has been fully scanned.
func (r *ScanningResult) IsReady() bool {
	return r.Type != ResultUnknown
}

// ScanningResultList is a thread-safe collection of scanning results.
type ScanningResultList struct {
	mu      sync.RWMutex
	results []*ScanningResult

	// Statistics
	aliveCount    int
	withPortCount int
}

// NewScanningResultList creates an empty result list.
func NewScanningResultList() *ScanningResultList {
	return &ScanningResultList{
		results: make([]*ScanningResult, 0, 256),
	}
}

// Add appends a result to the list and updates statistics.
func (l *ScanningResultList) Add(result *ScanningResult) {
	l.mu.Lock()
	l.results = append(l.results, result)
	switch result.Type {
	case ResultAlive:
		l.aliveCount++
	case ResultWithPorts:
		l.aliveCount++
		l.withPortCount++
	}
	l.mu.Unlock()
}

// Len returns the number of results.
func (l *ScanningResultList) Len() int {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return len(l.results)
}

// Get returns the result at the given index.
func (l *ScanningResultList) Get(index int) *ScanningResult {
	l.mu.RLock()
	defer l.mu.RUnlock()
	if index < 0 || index >= len(l.results) {
		return nil
	}
	return l.results[index]
}

// All returns a copy of all results.
func (l *ScanningResultList) All() []*ScanningResult {
	l.mu.RLock()
	defer l.mu.RUnlock()
	cp := make([]*ScanningResult, len(l.results))
	copy(cp, l.results)
	return cp
}

// Clear removes all results and resets statistics.
func (l *ScanningResultList) Clear() {
	l.mu.Lock()
	l.results = l.results[:0]
	l.aliveCount = 0
	l.withPortCount = 0
	l.mu.Unlock()
}

// Stats returns scanning statistics.
func (l *ScanningResultList) Stats() (total, alive, withPorts int) {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return len(l.results), l.aliveCount, l.withPortCount
}

// FindText searches for a string in results starting from the given index.
// Returns the index of the first match, or -1 if not found.
func (l *ScanningResultList) FindText(text string, startIndex int) int {
	l.mu.RLock()
	defer l.mu.RUnlock()
	for i := startIndex; i < len(l.results); i++ {
		for _, val := range l.results[i].Values {
			if val == nil {
				continue
			}
			if s, ok := val.(string); ok {
				if containsIgnoreCase(s, text) {
					return i
				}
			}
		}
	}
	return -1
}

func containsIgnoreCase(s, substr string) bool {
	// Simple case-insensitive contains
	sl := len(s)
	subl := len(substr)
	if subl > sl {
		return false
	}
	for i := 0; i <= sl-subl; i++ {
		match := true
		for j := 0; j < subl; j++ {
			sc := s[i+j]
			tc := substr[j]
			if sc >= 'A' && sc <= 'Z' {
				sc += 32
			}
			if tc >= 'A' && tc <= 'Z' {
				tc += 32
			}
			if sc != tc {
				match = false
				break
			}
		}
		if match {
			return true
		}
	}
	return false
}
