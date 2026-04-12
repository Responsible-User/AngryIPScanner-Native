package feeder

import (
	"fmt"
	"math"
	"net"

	"github.com/angryip/libipscan/ipnet"
	"github.com/angryip/libipscan/scanner"
)

// RangeFeeder generates scanning subjects from a start to end IP range.
type RangeFeeder struct {
	startIP     net.IP
	endIP       net.IP // exclusive (one past the real end)
	originalEnd net.IP
	currentIP   net.IP
	isReverse   bool

	ifInfo *ipnet.InterfaceInfo

	percentComplete   float64
	percentIncrement  float64
}

// NewRangeFeeder creates a feeder that iterates from startIP to endIP (inclusive).
func NewRangeFeeder(startIPStr, endIPStr string) (*RangeFeeder, error) {
	startIP := net.ParseIP(startIPStr)
	if startIP == nil {
		return nil, fmt.Errorf("invalid start IP: %s", startIPStr)
	}
	endIP := net.ParseIP(endIPStr)
	if endIP == nil {
		return nil, fmt.Errorf("invalid end IP: %s", endIPStr)
	}

	// Normalize to 4-byte form for IPv4
	if s4 := startIP.To4(); s4 != nil {
		startIP = s4
	}
	if e4 := endIP.To4(); e4 != nil {
		endIP = e4
	}

	if len(startIP) != len(endIP) {
		return nil, fmt.Errorf("start and end IP must be same protocol")
	}

	f := &RangeFeeder{
		startIP:     startIP,
		originalEnd: copyIP(endIP),
		currentIP:   copyIP(startIP),
	}

	// Detect local interface
	f.ifInfo = ipnet.GetLocalInterface()

	// Handle reverse range
	if ipnet.GreaterThan(startIP, endIP) {
		f.isReverse = true
		endIP = ipnet.Decrement(ipnet.Decrement(endIP))
	}

	// Calculate percentage increment
	f.initPercentIncrement(startIP, endIP)

	// Make endIP exclusive (one past the real end)
	f.endIP = ipnet.Increment(endIP)

	return f, nil
}

func (f *RangeFeeder) initPercentIncrement(startIP, endIP net.IP) {
	// Use the last 4 bytes for percentage calculation
	rawStart := ipToUint32(startIP)
	rawEnd := ipToUint32(endIP)

	diff := float64(rawEnd) - float64(rawStart)
	if diff == 0 {
		f.percentIncrement = 100.0
	} else {
		f.percentIncrement = math.Abs(100.0 / (diff + 1))
	}
	f.percentComplete = 0
}

func ipToUint32(ip net.IP) uint32 {
	b := ip
	if len(b) > 4 {
		b = b[len(b)-4:]
	}
	return uint32(b[0])<<24 | uint32(b[1])<<16 | uint32(b[2])<<8 | uint32(b[3])
}

func (f *RangeFeeder) HasNext() bool {
	return !f.currentIP.Equal(f.endIP)
}

func (f *RangeFeeder) Next() *scanner.ScanningSubject {
	f.percentComplete += f.percentIncrement

	prevIP := copyIP(f.currentIP)
	if f.isReverse {
		f.currentIP = ipnet.Decrement(f.currentIP)
	} else {
		f.currentIP = ipnet.Increment(f.currentIP)
	}

	subject := scanner.NewScanningSubject(prevIP)
	if f.ifInfo != nil {
		subject.InterfaceName = f.ifInfo.Name
		subject.InterfaceAddr = f.ifInfo.Address
		subject.BroadcastAddr = f.ifInfo.Broadcast
		subject.PrefixLen = f.ifInfo.PrefixLen
	}
	return subject
}

func (f *RangeFeeder) PercentComplete() float64 {
	pct := f.percentComplete / 100.0
	if pct > 1.0 {
		return 1.0
	}
	return pct
}

func (f *RangeFeeder) Info() string {
	return f.startIP.String() + " - " + f.originalEnd.String()
}

func (f *RangeFeeder) IsLocalNetwork() bool {
	return f.ifInfo != nil
}

func copyIP(ip net.IP) net.IP {
	dup := make(net.IP, len(ip))
	copy(dup, ip)
	return dup
}
