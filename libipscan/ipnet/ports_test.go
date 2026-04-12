package ipnet

import (
	"strings"
	"testing"
)

func iterateToString(pi *PortIterator) string {
	var sb strings.Builder
	for pi.HasNext() {
		port := pi.Next()
		sb.WriteString(strings.TrimSpace(strings.Replace(
			func() string { return string(rune(0)) }(), string(rune(0)), "", -1)))
		// Simple int to string
		sb.WriteString(itoa(port))
		sb.WriteByte(' ')
	}
	return sb.String()
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	digits := make([]byte, 0, 6)
	for n > 0 {
		digits = append(digits, byte('0'+n%10))
		n /= 10
	}
	// Reverse
	for i, j := 0, len(digits)-1; i < j; i, j = i+1, j-1 {
		digits[i], digits[j] = digits[j], digits[i]
	}
	if neg {
		return "-" + string(digits)
	}
	return string(digits)
}

func TestPortIteratorBasic(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"1,2,3,5,7", "1 2 3 5 7 "},
		{"1,\n2,   3,\t\t5,7", "1 2 3 5 7 "},
		{"27, 1;65535", "27 1 65535 "},
		{"16", "16 "},
		{"", ""},
		{"   12", "12 "},
		{"12, ", "12 "},
	}
	for _, tt := range tests {
		pi, err := ParsePorts(tt.input)
		if err != nil {
			t.Errorf("ParsePorts(%q) error: %v", tt.input, err)
			continue
		}
		result := iterateToString(pi)
		if result != tt.expected {
			t.Errorf("ParsePorts(%q) = %q, want %q", tt.input, result, tt.expected)
		}
	}
}

func TestPortIteratorRange(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"1-3", "1 2 3 "},
		{"65530-65535", "65530 65531 65532 65533 65534 65535 "},
		{"100,13-14,17-20", "100 13 14 17 18 19 20 "},
	}
	for _, tt := range tests {
		pi, err := ParsePorts(tt.input)
		if err != nil {
			t.Errorf("ParsePorts(%q) error: %v", tt.input, err)
			continue
		}
		result := iterateToString(pi)
		if result != tt.expected {
			t.Errorf("ParsePorts(%q) = %q, want %q", tt.input, result, tt.expected)
		}
	}
}

func TestPortIteratorSize(t *testing.T) {
	tests := []struct {
		input    string
		expected int
	}{
		{"", 0},
		{"80", 1},
		{"5,10-12,1", 5},
		{"1-65000", 65000},
	}
	for _, tt := range tests {
		pi, err := ParsePorts(tt.input)
		if err != nil {
			t.Errorf("ParsePorts(%q) error: %v", tt.input, err)
			continue
		}
		if pi.Size() != tt.expected {
			t.Errorf("ParsePorts(%q).Size() = %d, want %d", tt.input, pi.Size(), tt.expected)
		}
	}
}

func TestPortIteratorCopy(t *testing.T) {
	pi, _ := ParsePorts("1")
	cp := pi.Copy()
	if cp == nil {
		t.Fatal("Copy() returned nil")
	}
	if !cp.HasNext() {
		t.Error("Copy should have next")
	}
}

func TestPortIteratorErrors(t *testing.T) {
	errorCases := []string{
		"foo",
		"65536",
		"1,2,0,3",
	}
	for _, input := range errorCases {
		_, err := ParsePorts(input)
		if err == nil {
			t.Errorf("ParsePorts(%q) should have returned error", input)
		}
	}
}

func TestPortIteratorNegative(t *testing.T) {
	// "-3" is ambiguous — treated as a range from start "" which should error
	_, err := ParsePorts("-3")
	if err == nil {
		t.Error("ParsePorts(\"-3\") should have returned error")
	}
}
