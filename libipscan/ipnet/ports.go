package ipnet

import (
	"fmt"
	"strconv"
	"strings"
)

// PortRange represents a contiguous range of ports (inclusive).
type PortRange struct {
	Start int
	End   int
}

// PortIterator iterates over ports specified in a format like "1,5-7,35-40".
type PortIterator struct {
	ranges     []PortRange
	rangeIndex int
	current    int
	done       bool
}

// ParsePorts parses a port string like "80,443,1000-2000" and returns a PortIterator.
func ParsePorts(portString string) (*PortIterator, error) {
	portString = strings.TrimSpace(portString)
	if portString == "" {
		return &PortIterator{done: true}, nil
	}

	// Split on commas, semicolons, and whitespace
	parts := splitPorts(portString)

	ranges := make([]PortRange, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part == "" {
			continue
		}

		dashIdx := strings.Index(part, "-")
		if dashIdx == -1 {
			// Single port
			port, err := strconv.Atoi(part)
			if err != nil {
				return nil, fmt.Errorf("invalid port: %s", part)
			}
			if err := validatePort(port); err != nil {
				return nil, err
			}
			ranges = append(ranges, PortRange{Start: port, End: port})
		} else {
			// Port range
			startStr := part[:dashIdx]
			endStr := part[dashIdx+1:]
			start, err := strconv.Atoi(startStr)
			if err != nil {
				return nil, fmt.Errorf("invalid port range: %s", part)
			}
			end, err := strconv.Atoi(endStr)
			if err != nil {
				return nil, fmt.Errorf("invalid port range: %s", part)
			}
			if err := validatePort(end); err != nil {
				return nil, err
			}
			ranges = append(ranges, PortRange{Start: start, End: end})
		}
	}

	if len(ranges) == 0 {
		return &PortIterator{done: true}, nil
	}

	return &PortIterator{
		ranges:  ranges,
		current: ranges[0].Start,
		done:    false,
	}, nil
}

func splitPorts(s string) []string {
	// Split on commas, semicolons, whitespace
	var parts []string
	var current strings.Builder
	for _, ch := range s {
		if ch == ',' || ch == ';' || ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
			if current.Len() > 0 {
				parts = append(parts, current.String())
				current.Reset()
			}
		} else {
			current.WriteRune(ch)
		}
	}
	if current.Len() > 0 {
		parts = append(parts, current.String())
	}
	return parts
}

func validatePort(port int) error {
	if port <= 0 || port >= 65536 {
		return fmt.Errorf("%d port is out of range", port)
	}
	return nil
}

// HasNext returns true if there are more ports to iterate.
func (pi *PortIterator) HasNext() bool {
	return !pi.done
}

// Next returns the next port number. Call HasNext() first.
func (pi *PortIterator) Next() int {
	port := pi.current
	pi.current++

	if pi.current > pi.ranges[pi.rangeIndex].End {
		pi.rangeIndex++
		if pi.rangeIndex >= len(pi.ranges) {
			pi.done = true
		} else {
			pi.current = pi.ranges[pi.rangeIndex].Start
		}
	}

	return port
}

// Size returns the total number of ports in the iterator.
func (pi *PortIterator) Size() int {
	size := 0
	for _, r := range pi.ranges {
		size += r.End - r.Start + 1
	}
	return size
}

// Copy returns a fresh copy of the iterator, reset to the beginning.
func (pi *PortIterator) Copy() *PortIterator {
	if len(pi.ranges) == 0 {
		return &PortIterator{done: true}
	}
	return &PortIterator{
		ranges:  pi.ranges,
		current: pi.ranges[0].Start,
		done:    false,
	}
}

// All returns all ports as a slice.
func (pi *PortIterator) All() []int {
	cp := pi.Copy()
	result := make([]int, 0, cp.Size())
	for cp.HasNext() {
		result = append(result, cp.Next())
	}
	return result
}
