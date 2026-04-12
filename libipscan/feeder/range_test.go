package feeder

import (
	"testing"
)

func TestRangeFeederBasic(t *testing.T) {
	f, err := NewRangeFeeder("192.168.1.1", "192.168.1.5")
	if err != nil {
		t.Fatal(err)
	}

	var ips []string
	for f.HasNext() {
		s := f.Next()
		ips = append(ips, s.Address.String())
	}

	expected := []string{"192.168.1.1", "192.168.1.2", "192.168.1.3", "192.168.1.4", "192.168.1.5"}
	if len(ips) != len(expected) {
		t.Fatalf("got %d IPs, want %d: %v", len(ips), len(expected), ips)
	}
	for i, ip := range ips {
		if ip != expected[i] {
			t.Errorf("IP[%d] = %s, want %s", i, ip, expected[i])
		}
	}
}

func TestRangeFeederSingleIP(t *testing.T) {
	f, err := NewRangeFeeder("10.0.0.1", "10.0.0.1")
	if err != nil {
		t.Fatal(err)
	}

	count := 0
	for f.HasNext() {
		s := f.Next()
		if s.Address.String() != "10.0.0.1" {
			t.Errorf("expected 10.0.0.1, got %s", s.Address)
		}
		count++
	}
	if count != 1 {
		t.Errorf("expected 1 IP, got %d", count)
	}
}

func TestRangeFeederReverse(t *testing.T) {
	f, err := NewRangeFeeder("192.168.1.5", "192.168.1.3")
	if err != nil {
		t.Fatal(err)
	}

	var ips []string
	for f.HasNext() {
		s := f.Next()
		ips = append(ips, s.Address.String())
	}

	expected := []string{"192.168.1.5", "192.168.1.4", "192.168.1.3"}
	if len(ips) != len(expected) {
		t.Fatalf("got %d IPs, want %d: %v", len(ips), len(expected), ips)
	}
	for i, ip := range ips {
		if ip != expected[i] {
			t.Errorf("IP[%d] = %s, want %s", i, ip, expected[i])
		}
	}
}

func TestRangeFeederPercentage(t *testing.T) {
	f, err := NewRangeFeeder("10.0.0.1", "10.0.0.10")
	if err != nil {
		t.Fatal(err)
	}

	for f.HasNext() {
		f.Next()
	}

	pct := f.PercentComplete()
	if pct < 0.99 {
		t.Errorf("expected ~1.0 at end, got %f", pct)
	}
}

func TestRangeFeederInfo(t *testing.T) {
	f, err := NewRangeFeeder("10.0.0.1", "10.0.0.255")
	if err != nil {
		t.Fatal(err)
	}

	info := f.Info()
	if info != "10.0.0.1 - 10.0.0.255" {
		t.Errorf("info = %q, want %q", info, "10.0.0.1 - 10.0.0.255")
	}
}

func TestRangeFeederDifferentProtocols(t *testing.T) {
	_, err := NewRangeFeeder("10.0.0.1", "::1")
	if err == nil {
		t.Error("expected error for mixed IPv4/IPv6")
	}
}

func TestRangeFeederInvalidIP(t *testing.T) {
	_, err := NewRangeFeeder("not-an-ip", "10.0.0.1")
	if err == nil {
		t.Error("expected error for invalid IP")
	}
}
