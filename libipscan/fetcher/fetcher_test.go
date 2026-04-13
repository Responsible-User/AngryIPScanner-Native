package fetcher

import (
	"net"
	"testing"

	"github.com/angryip/libipscan/scanner"
)

func TestIPFetcher(t *testing.T) {
	f := &IPFetcher{}
	f.Init()
	defer f.Cleanup()

	subject := scanner.NewScanningSubject(net.ParseIP("192.168.1.1").To4())
	result := f.Scan(subject)

	if result != "192.168.1.1" {
		t.Errorf("IPFetcher.Scan = %v, want %q", result, "192.168.1.1")
	}
}

func TestIPFetcherID(t *testing.T) {
	f := &IPFetcher{}
	if f.ID() != "fetcher.ip" {
		t.Errorf("ID = %q, want %q", f.ID(), "fetcher.ip")
	}
	if f.Name() != "IP" {
		t.Errorf("Name = %q, want %q", f.Name(), "IP")
	}
}

func TestHostnameFetcherLocalhost(t *testing.T) {
	f := &HostnameFetcher{}
	f.Init()
	defer f.Cleanup()

	subject := scanner.NewScanningSubject(net.ParseIP("127.0.0.1").To4())
	result := f.Scan(subject)
	// 127.0.0.1 should resolve to "localhost" on most systems
	if result != nil {
		s, ok := result.(string)
		if !ok {
			t.Errorf("Expected string result, got %T", result)
		}
		if s == "127.0.0.1" {
			t.Error("Should not return IP as hostname")
		}
	}
}

func TestCommentFetcher(t *testing.T) {
	comments := map[string]string{
		"10.0.0.1": "my router",
	}
	f := NewCommentFetcher(comments)
	f.Init()
	defer f.Cleanup()

	// Test hit
	subject := scanner.NewScanningSubject(net.ParseIP("10.0.0.1").To4())
	result := f.Scan(subject)
	if result != "my router" {
		t.Errorf("Comment = %v, want %q", result, "my router")
	}

	// Test miss
	subject2 := scanner.NewScanningSubject(net.ParseIP("10.0.0.2").To4())
	result2 := f.Scan(subject2)
	if result2 != nil {
		t.Errorf("Expected nil for unknown IP, got %v", result2)
	}
}

func TestCommentFetcherSetComment(t *testing.T) {
	f := NewCommentFetcher(nil)
	f.SetComment("10.0.0.5", "test comment")

	subject := scanner.NewScanningSubject(net.ParseIP("10.0.0.5").To4())
	result := f.Scan(subject)
	if result != "test comment" {
		t.Errorf("Comment = %v, want %q", result, "test comment")
	}
}

func TestPortsFormatting(t *testing.T) {
	tests := []struct {
		ports    []int
		expected string
	}{
		{[]int{80}, "80"},
		{[]int{80, 443}, "80,443"},
		{[]int{80, 81, 82}, "80-82"},
		{[]int{22, 80, 81, 82, 443}, "22,80-82,443"},
		{[]int{}, ""},
	}
	for _, tt := range tests {
		result := formatPorts(tt.ports)
		if result != tt.expected {
			t.Errorf("formatPorts(%v) = %q, want %q", tt.ports, result, tt.expected)
		}
	}
}

func TestMACVendorLookup(t *testing.T) {
	// Load vendors
	vendors := LoadMACVendors()

	// If the embedded data isn't available (running without resources init), skip
	if len(vendors) == 0 {
		t.Skip("MAC vendor database not embedded in test binary")
	}

	// Look up a known Xerox OUI
	if vendor, ok := vendors["000000"]; !ok || vendor != "XEROX" {
		t.Errorf("vendor[000000] = %q, want XEROX", vendor)
	}
}

func TestResultTypeUpgrade(t *testing.T) {
	s := scanner.NewScanningSubject(net.ParseIP("10.0.0.1").To4())

	s.UpgradeResultType(scanner.ResultDead)
	if s.ResultType != scanner.ResultDead {
		t.Error("Should upgrade to Dead")
	}

	s.UpgradeResultType(scanner.ResultAlive)
	if s.ResultType != scanner.ResultAlive {
		t.Error("Should upgrade to Alive")
	}

	s.UpgradeResultType(scanner.ResultWithPorts)
	if s.ResultType != scanner.ResultWithPorts {
		t.Error("Should upgrade to WithPorts")
	}

	// Should NOT downgrade
	s.UpgradeResultType(scanner.ResultAlive)
	if s.ResultType != scanner.ResultWithPorts {
		t.Error("Should not downgrade from WithPorts to Alive")
	}

	s.UpgradeResultType(scanner.ResultDead)
	if s.ResultType != scanner.ResultWithPorts {
		t.Error("Should not downgrade from WithPorts to Dead")
	}
}
