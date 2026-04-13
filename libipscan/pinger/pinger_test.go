package pinger

import (
	"net"
	"testing"
	"time"
)

func TestNewPingResult(t *testing.T) {
	r := NewPingResult(net.ParseIP("127.0.0.1"), 3)
	if r.PacketCount != 3 {
		t.Errorf("PacketCount = %d, want 3", r.PacketCount)
	}
	if r.IsAlive() {
		t.Error("Should not be alive with no replies")
	}
	if r.PacketLossPercent() != 100 {
		t.Errorf("PacketLoss = %d%%, want 100%%", r.PacketLossPercent())
	}
}

func TestPingResultAddReply(t *testing.T) {
	r := NewPingResult(net.ParseIP("10.0.0.1"), 3)
	r.AddReply(10)
	r.AddReply(20)

	if !r.IsAlive() {
		t.Error("Should be alive after replies")
	}
	if r.ReplyCount != 2 {
		t.Errorf("ReplyCount = %d, want 2", r.ReplyCount)
	}
	if r.AverageTime() != 15 {
		t.Errorf("AverageTime = %d, want 15", r.AverageTime())
	}
	if r.LongestTime != 20 {
		t.Errorf("LongestTime = %d, want 20", r.LongestTime)
	}
	if r.PacketLoss() != 1 {
		t.Errorf("PacketLoss = %d, want 1", r.PacketLoss())
	}
}

func TestPingResultMerge(t *testing.T) {
	r1 := NewPingResult(net.ParseIP("10.0.0.1"), 2)
	r1.AddReply(10)

	r2 := NewPingResult(net.ParseIP("10.0.0.1"), 2)
	r2.AddReply(20)
	r2.AddReply(30)

	r1.Merge(r2)
	if r1.PacketCount != 4 {
		t.Errorf("Merged PacketCount = %d, want 4", r1.PacketCount)
	}
	if r1.ReplyCount != 3 {
		t.Errorf("Merged ReplyCount = %d, want 3", r1.ReplyCount)
	}
	if r1.LongestTime != 30 {
		t.Errorf("Merged LongestTime = %d, want 30", r1.LongestTime)
	}
}

func TestNewPingerRegistry(t *testing.T) {
	timeout := 1000 * time.Millisecond

	tests := []struct {
		id       string
		expected string
	}{
		{"pinger.tcp", "pinger.tcp"},
		{"pinger.udp", "pinger.udp"},
		{"pinger.icmp", "pinger.icmp"},
		{"pinger.combined", "pinger.combined"},
		{"pinger.unknown", "pinger.combined"}, // fallback
	}

	for _, tt := range tests {
		p := NewPinger(tt.id, timeout)
		if p.ID() != tt.expected {
			t.Errorf("NewPinger(%q).ID() = %q, want %q", tt.id, p.ID(), tt.expected)
		}
	}
}

func TestTCPPingerLocalhost(t *testing.T) {
	// This is a real network test — ping localhost which should always respond
	p := NewTCPPinger(2 * time.Second)
	result, err := p.Ping(net.ParseIP("127.0.0.1"), 1, 2*time.Second)
	if err != nil {
		t.Fatalf("Ping localhost failed: %v", err)
	}
	// Localhost TCP connect to port 80 might or might not work,
	// but the function should not crash
	_ = result
}
