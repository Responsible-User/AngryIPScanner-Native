// Package pinger provides network host reachability probing implementations.
package pinger

import (
	"net"
	"time"
)

// Pinger is the interface for all host reachability probes.
type Pinger interface {
	// Ping probes the given address for reachability.
	// count is the number of probes to send, timeout is per-probe.
	Ping(address net.IP, count int, timeout time.Duration) (*PingResult, error)

	// ID returns a unique identifier for this pinger type.
	ID() string

	// Close releases any resources held by the pinger.
	Close() error
}

// PingResult holds the results of pinging a host.
type PingResult struct {
	Address                net.IP
	TTL                    int
	TotalTime              int64 // milliseconds
	LongestTime            int64 // milliseconds
	PacketCount            int
	ReplyCount             int
	TimeoutAdaptAllowed    bool
}

// NewPingResult creates a new ping result for the given address and packet count.
func NewPingResult(address net.IP, packetCount int) *PingResult {
	return &PingResult{
		Address:     address,
		PacketCount: packetCount,
	}
}

// AddReply records a successful reply with the given round-trip time in milliseconds.
func (r *PingResult) AddReply(timeMs int64) {
	r.ReplyCount++
	if timeMs > r.LongestTime {
		r.LongestTime = timeMs
	}
	r.TotalTime += timeMs
	r.TimeoutAdaptAllowed = r.ReplyCount > 2
}

// AverageTime returns the average round-trip time in milliseconds.
func (r *PingResult) AverageTime() int64 {
	if r.ReplyCount == 0 {
		return 0
	}
	return r.TotalTime / int64(r.ReplyCount)
}

// PacketLoss returns the number of lost packets.
func (r *PingResult) PacketLoss() int {
	return r.PacketCount - r.ReplyCount
}

// PacketLossPercent returns the packet loss as a percentage (0-100).
func (r *PingResult) PacketLossPercent() int {
	if r.ReplyCount > 0 {
		return (r.PacketLoss() * 100) / r.PacketCount
	}
	return 100
}

// IsAlive returns true if at least one reply was received.
func (r *PingResult) IsAlive() bool {
	return r.ReplyCount > 0
}

// Merge combines another PingResult into this one.
func (r *PingResult) Merge(other *PingResult) {
	r.PacketCount += other.PacketCount
	r.ReplyCount += other.ReplyCount
	r.TotalTime += other.TotalTime
	if other.LongestTime > r.LongestTime {
		r.LongestTime = other.LongestTime
	}
}
