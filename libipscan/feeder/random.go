package feeder

import (
	"crypto/rand"
	"fmt"
	"net"

	"github.com/angryip/libipscan/ipnet"
	"github.com/angryip/libipscan/scanner"
)

// RandomFeeder generates random IP addresses within a given range.
type RandomFeeder struct {
	protoBytes []byte
	maskBytes  []byte
	count      int
	current    int
}

// NewRandomFeeder creates a feeder that generates count random IPs
// within the range defined by prototypeIP and mask.
func NewRandomFeeder(prototypeIP, mask string, count int) (*RandomFeeder, error) {
	ip := net.ParseIP(prototypeIP)
	if ip == nil {
		return nil, fmt.Errorf("invalid IP: %s", prototypeIP)
	}
	if ip4 := ip.To4(); ip4 != nil {
		ip = ip4
	}

	netmask, err := ipnet.ParseNetmask(mask)
	if err != nil {
		return nil, fmt.Errorf("invalid netmask: %s", mask)
	}
	if m4 := netmask.To4(); m4 != nil {
		netmask = m4
	}

	if count <= 0 {
		return nil, fmt.Errorf("count must be positive")
	}

	return &RandomFeeder{
		protoBytes: []byte(ip),
		maskBytes:  []byte(netmask),
		count:      count,
	}, nil
}

func (f *RandomFeeder) HasNext() bool { return f.current < f.count }

func (f *RandomFeeder) Next() *scanner.ScanningSubject {
	f.current++

	randomBytes := make([]byte, len(f.protoBytes))
	rand.Read(randomBytes)

	// Apply mask: where mask is set, use prototype; where cleared, use random
	ipnet.MaskPrototypeAddressBytes(randomBytes, f.maskBytes, f.protoBytes)

	return scanner.NewScanningSubject(net.IP(randomBytes))
}

func (f *RandomFeeder) PercentComplete() float64 {
	if f.count == 0 {
		return 1.0
	}
	return float64(f.current) / float64(f.count)
}

func (f *RandomFeeder) Info() string {
	return fmt.Sprintf("%d: %s / %s", f.count, net.IP(f.protoBytes), net.IP(f.maskBytes))
}

func (f *RandomFeeder) IsLocalNetwork() bool { return false }
