package ipnet

import (
	"net"
	"testing"
)

func ip(s string) net.IP {
	return net.ParseIP(s)
}

func ip4(s string) net.IP {
	return net.ParseIP(s).To4()
}

func TestIncrement(t *testing.T) {
	tests := []struct {
		input, expected string
	}{
		{"127.0.0.1", "127.0.0.2"},
		{"127.255.255.255", "128.0.0.0"},
		{"255.255.255.255", "0.0.0.0"},
	}
	for _, tt := range tests {
		result := Increment(ip4(tt.input))
		if result.String() != tt.expected {
			t.Errorf("Increment(%s) = %s, want %s", tt.input, result, tt.expected)
		}
	}
}

func TestDecrement(t *testing.T) {
	tests := []struct {
		input, expected string
	}{
		{"127.0.0.2", "127.0.0.1"},
		{"128.0.0.0", "127.255.255.255"},
		{"0.0.0.0", "255.255.255.255"},
	}
	for _, tt := range tests {
		result := Decrement(ip4(tt.input))
		if result.String() != tt.expected {
			t.Errorf("Decrement(%s) = %s, want %s", tt.input, result, tt.expected)
		}
	}
}

func TestGreaterThan(t *testing.T) {
	tests := []struct {
		a, b     string
		expected bool
	}{
		{"127.0.0.1", "127.0.0.0", true},
		{"129.0.0.1", "128.0.0.0", true},
		{"255.0.0.0", "254.255.255.255", true},
		{"0.0.0.0", "255.255.255.255", false},
		{"0.0.0.0", "0.0.0.0", false},
		{"127.0.0.1", "127.0.5.0", false},
	}
	for _, tt := range tests {
		result := GreaterThan(ip4(tt.a), ip4(tt.b))
		if result != tt.expected {
			t.Errorf("GreaterThan(%s, %s) = %v, want %v", tt.a, tt.b, result, tt.expected)
		}
	}
}

func TestStartRangeByNetmask(t *testing.T) {
	tests := []struct {
		addr, mask, expected string
	}{
		{"127.0.1.92", "255.255.255.192", "127.0.1.64"},
		{"127.0.0.15", "255.255.255.255", "127.0.0.15"},
		{"192.10.11.13", "255.255.0.0", "192.10.0.0"},
	}
	for _, tt := range tests {
		result := StartRangeByNetmask(ip4(tt.addr), ip4(tt.mask))
		if result.String() != tt.expected {
			t.Errorf("StartRangeByNetmask(%s, %s) = %s, want %s", tt.addr, tt.mask, result, tt.expected)
		}
	}
}

func TestEndRangeByNetmask(t *testing.T) {
	tests := []struct {
		addr, mask, expected string
	}{
		{"127.0.1.92", "255.255.255.192", "127.0.1.127"},
		{"127.0.0.15", "255.255.255.255", "127.0.0.15"},
		{"192.10.11.13", "255.255.0.0", "192.10.255.255"},
	}
	for _, tt := range tests {
		result := EndRangeByNetmask(ip4(tt.addr), ip4(tt.mask))
		if result.String() != tt.expected {
			t.Errorf("EndRangeByNetmask(%s, %s) = %s, want %s", tt.addr, tt.mask, result, tt.expected)
		}
	}
}

func TestParseNetmask(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"255.255.255.255", "255.255.255.255"},
		{"255...255", "255.255.255.255"},
		{"255.0..255", "255.0.255.255"},
		{"255...192", "255.255.255.192"},
		{"255.0..0", "255.0.255.0"},
		{"0.0.0.0", "0.0.0.0"},
		// CIDR
		{"/0", "0.0.0.0"},
		{"/1", "128.0.0.0"},
		{"/16", "255.255.0.0"},
		{"/24", "255.255.255.0"},
		{"/25", "255.255.255.128"},
		{"/29", "255.255.255.248"},
		{"/32", "255.255.255.255"},
	}
	for _, tt := range tests {
		result, err := ParseNetmask(tt.input)
		if err != nil {
			t.Errorf("ParseNetmask(%s) error: %v", tt.input, err)
			continue
		}
		if result.String() != tt.expected {
			t.Errorf("ParseNetmask(%s) = %s, want %s", tt.input, result, tt.expected)
		}
	}
}

func TestParseNetmaskIPv6(t *testing.T) {
	result := ParseNetmaskBits(64)
	expected := "ffff:ffff:ffff:ffff::"
	// net.IP.String() for IPv6 masks
	if result.String() != expected {
		// Go may format differently, compare bytes
		expectedIP := net.ParseIP(expected)
		if expectedIP == nil {
			t.Fatalf("Cannot parse expected IP %s", expected)
		}
		// Compare the first 8 bytes should be 0xFF and last 8 should be 0x00
		for i := 0; i < 8; i++ {
			if result[i] != 0xFF {
				t.Errorf("ParseNetmaskBits(64) byte[%d] = %02x, want ff", i, result[i])
			}
		}
		for i := 8; i < 16; i++ {
			if result[i] != 0x00 {
				t.Errorf("ParseNetmaskBits(64) byte[%d] = %02x, want 00", i, result[i])
			}
		}
	}
}

func TestMaskPrototypeAddressBytes(t *testing.T) {
	tests := []struct {
		addr, mask, proto, expected string
	}{
		{"32.23.34.254", "255.0.0.255", "29.1.2.255", "29.23.34.255"},
		{"250.250.250.250", "0.0.0.0", "29.1.2.255", "250.250.250.250"},
		{"250.250.250.250", "255.255.255.255", "29.128.127.73", "29.128.127.73"},
	}
	for _, tt := range tests {
		addr := ip4(tt.addr)
		mask := ip4(tt.mask)
		proto := ip4(tt.proto)
		addrBytes := []byte(addr)
		MaskPrototypeAddressBytes(addrBytes, []byte(mask), []byte(proto))
		result := net.IP(addrBytes).String()
		if result != tt.expected {
			t.Errorf("MaskPrototypeAddressBytes(%s, %s, %s) = %s, want %s",
				tt.addr, tt.mask, tt.proto, result, tt.expected)
		}
	}
}

func TestIsLikelyBroadcast(t *testing.T) {
	// Without interface info
	if !IsLikelyBroadcast(ip4("127.0.2.0"), nil) {
		t.Error("Expected 127.0.2.0 to be broadcast (last byte 0)")
	}
	if !IsLikelyBroadcast(ip4("127.6.32.255"), nil) {
		t.Error("Expected 127.6.32.255 to be broadcast (last byte 255)")
	}
	if IsLikelyBroadcast(ip4("127.4.5.6"), nil) {
		t.Error("Expected 127.4.5.6 to NOT be broadcast")
	}

	// With interface info
	ifInfo := &InterfaceInfo{
		Address:   ip4("192.168.0.1"),
		Broadcast: ip4("192.168.0.127"),
	}
	if !IsLikelyBroadcast(ip4("192.168.0.127"), ifInfo) {
		t.Error("Expected 192.168.0.127 to be broadcast (matches broadcast)")
	}
	if !IsLikelyBroadcast(ip4("192.168.0.0"), ifInfo) {
		t.Error("Expected 192.168.0.0 to be broadcast (network address)")
	}
	if IsLikelyBroadcast(ip4("192.168.0.1"), ifInfo) {
		t.Error("Expected 192.168.0.1 to NOT be broadcast")
	}
	if IsLikelyBroadcast(ip4("192.168.0.126"), ifInfo) {
		t.Error("Expected 192.168.0.126 to NOT be broadcast")
	}
}
