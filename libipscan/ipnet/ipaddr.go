// Package ipnet provides IP address arithmetic and network utility functions.
package ipnet

import (
	"fmt"
	"net"
	"regexp"
	"strconv"
	"strings"
)

// IPv4Regex matches IPv4 addresses.
var IPv4Regex = regexp.MustCompile(
	`\b(?:(?:25[0-5]|(?:2[0-4]|1?[0-9])?[0-9])\.){3}(?:25[0-5]|(?:2[0-4]|1?[0-9])?[0-9])\b`,
)

// IPv6Regex matches common IPv6 address formats.
var IPv6Regex = regexp.MustCompile(
	`(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}` +
		`|(?:[0-9a-fA-F]{1,4}:){1,7}:` +
		`|(?:[0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}` +
		`|(?:[0-9a-fA-F]{1,4}:){1,5}(?::[0-9a-fA-F]{1,4}){1,2}` +
		`|(?:[0-9a-fA-F]{1,4}:){1,4}(?::[0-9a-fA-F]{1,4}){1,3}` +
		`|(?:[0-9a-fA-F]{1,4}:){1,3}(?::[0-9a-fA-F]{1,4}){1,4}` +
		`|(?:[0-9a-fA-F]{1,4}:){1,2}(?::[0-9a-fA-F]{1,4}){1,5}` +
		`|[0-9a-fA-F]{1,4}:(?::[0-9a-fA-F]{1,4}){1,6}` +
		`|:(?::[0-9a-fA-F]{1,4}){1,7}` +
		`|::`,
)

// HostnameRegex matches DNS hostnames (e.g. "example.com", "www.example.com").
var HostnameRegex = regexp.MustCompile(
	`\b(?:[a-zA-Z]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])(?:\.(?:[a-zA-Z]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9]))+\.?\b`,
)

// ParseAddress tries to parse a string as an IPv4 address, IPv6 address, or hostname.
// Returns the parsed IP or nil if the string is a hostname that needs resolution.
func ParseAddress(s string) net.IP {
	if ip := net.ParseIP(s); ip != nil {
		return ip
	}
	return nil
}

// Increment adds 1 to an IP address, wrapping on overflow.
func Increment(ip net.IP) net.IP {
	result := copyIP(ip)
	for i := len(result) - 1; i >= 0; i-- {
		result[i]++
		if result[i] != 0 {
			break
		}
	}
	return result
}

// Decrement subtracts 1 from an IP address, wrapping on underflow.
func Decrement(ip net.IP) net.IP {
	result := copyIP(ip)
	for i := len(result) - 1; i >= 0; i-- {
		result[i]--
		if result[i] != 0xFF {
			break
		}
	}
	return result
}

// GreaterThan returns true if a > b (unsigned byte comparison).
func GreaterThan(a, b net.IP) bool {
	a4 := a.To4()
	b4 := b.To4()
	if a4 != nil && b4 != nil {
		a, b = a4, b4
	}
	for i := 0; i < len(a) && i < len(b); i++ {
		if a[i] > b[i] {
			return true
		}
		if a[i] < b[i] {
			return false
		}
	}
	return false
}

// Equal returns true if two IPs are equal.
func Equal(a, b net.IP) bool {
	return a.Equal(b)
}

// StartRangeByNetmask returns the network address (start of range) given an address and netmask.
func StartRangeByNetmask(address, netmask net.IP) net.IP {
	addr := normalize(address)
	mask := normalize(netmask)
	result := make(net.IP, len(addr))
	for i := 0; i < len(addr); i++ {
		if i < len(mask) {
			result[i] = addr[i] & mask[i]
		} else {
			result[i] = 0
		}
	}
	return result
}

// EndRangeByNetmask returns the broadcast address (end of range) given an address and netmask.
func EndRangeByNetmask(address, netmask net.IP) net.IP {
	addr := normalize(address)
	mask := normalize(netmask)
	result := make(net.IP, len(addr))
	for i := 0; i < len(addr); i++ {
		if i < len(mask) {
			result[i] = addr[i] | ^mask[i]
		} else {
			result[i] = 0xFF
		}
	}
	return result
}

// ParseNetmask parses a netmask in either CIDR notation ("/24") or dotted notation ("255.255.255.0").
// Empty octets in dotted notation default to 255 (e.g. "255...192" → "255.255.255.192").
func ParseNetmask(s string) (net.IP, error) {
	if strings.HasPrefix(s, "/") {
		bits, err := strconv.Atoi(s[1:])
		if err != nil {
			return nil, fmt.Errorf("invalid CIDR netmask: %s", s)
		}
		return ParseNetmaskBits(bits), nil
	}

	// Replace empty octets with 255
	s = strings.ReplaceAll(s, "..", ".255.")
	s = strings.ReplaceAll(s, "..", ".255.")
	ip := net.ParseIP(s)
	if ip == nil {
		return nil, fmt.Errorf("invalid netmask: %s", s)
	}
	if ip4 := ip.To4(); ip4 != nil {
		return ip4, nil
	}
	return ip, nil
}

// ParseNetmaskBits creates a netmask from a prefix length (e.g. 24 → 255.255.255.0).
func ParseNetmaskBits(prefixBits int) net.IP {
	size := 4
	if prefixBits > 32 {
		size = 16
	}
	mask := make(net.IP, size)
	for i := 0; i < size; i++ {
		curByteBits := prefixBits
		if curByteBits > 8 {
			curByteBits = 8
		}
		if curByteBits < 0 {
			curByteBits = 0
		}
		prefixBits -= curByteBits
		mask[i] = byte(((1 << curByteBits) - 1) << (8 - curByteBits) & 0xFF)
	}
	return mask
}

// MaskPrototypeAddressBytes applies a mask: where mask bits are set, use prototype bits;
// where mask bits are cleared, keep address bits.
func MaskPrototypeAddressBytes(address, mask, prototype []byte) {
	for i := 0; i < len(address); i++ {
		address[i] = (address[i] & ^mask[i]) | (prototype[i] & mask[i])
	}
}

// IsLikelyBroadcast checks whether the given address is likely a broadcast or network address.
// If ifAddr is provided, checks against the interface's broadcast address and network address.
// If ifAddr is nil, checks if the last byte is 0 or 255.
func IsLikelyBroadcast(address net.IP, ifAddr *InterfaceInfo) bool {
	addr := normalize(address)
	last := len(addr) - 1

	if ifAddr != nil {
		if addr.Equal(ifAddr.Broadcast) {
			return true
		}
		// Check if it's the network address (last byte 0, same prefix)
		ifNet := normalize(ifAddr.Address)
		if addr[last] == 0 {
			for i := 0; i < last; i++ {
				if addr[i] != ifNet[i] {
					return false
				}
			}
			return true
		}
		return false
	}
	return addr[last] == 0 || addr[last] == 0xFF
}

// InterfaceInfo holds information about a network interface address.
type InterfaceInfo struct {
	Address   net.IP
	Broadcast net.IP
	PrefixLen int
	Name      string
}

// GetLocalInterface returns the best local IPv4 interface address.
func GetLocalInterface() *InterfaceInfo {
	var anyAddr *InterfaceInfo

	ifaces, err := net.Interfaces()
	if err != nil {
		return nil
	}

	for _, iface := range ifaces {
		if iface.Flags&net.FlagLoopback != 0 {
			continue
		}
		hw := iface.HardwareAddr
		if len(hw) == 0 {
			continue
		}

		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}

		for _, addr := range addrs {
			ipNet, ok := addr.(*net.IPNet)
			if !ok {
				continue
			}
			ip := ipNet.IP
			info := &InterfaceInfo{
				Address:   ip,
				PrefixLen: maskBits(ipNet.Mask),
				Name:      iface.Name,
			}
			// Calculate broadcast for IPv4
			if ip4 := ip.To4(); ip4 != nil {
				broadcast := make(net.IP, 4)
				for i := 0; i < 4; i++ {
					broadcast[i] = ip4[i] | ^ipNet.Mask[i]
				}
				info.Broadcast = broadcast
			}

			anyAddr = info

			if ip4 := ip.To4(); ip4 != nil && !ip.IsLoopback() {
				return info
			}
		}
	}
	return anyAddr
}

func maskBits(mask net.IPMask) int {
	ones, _ := mask.Size()
	return ones
}

func normalize(ip net.IP) net.IP {
	if ip4 := ip.To4(); ip4 != nil {
		return ip4
	}
	return ip
}

func copyIP(ip net.IP) net.IP {
	dup := make(net.IP, len(ip))
	copy(dup, ip)
	return dup
}
