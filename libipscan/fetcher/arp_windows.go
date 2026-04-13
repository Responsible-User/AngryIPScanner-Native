//go:build windows

package fetcher

import (
	"encoding/binary"
	"fmt"
	"net"
	"os/exec"
	"strings"
	"sync"
	"syscall"
	"unsafe"
)

var (
	iphlpapi    = syscall.NewLazyDLL("iphlpapi.dll")
	sendARPProc = iphlpapi.NewProc("SendARP")

	// Cached ARP table for fallback lookups
	arpCache   map[string]string
	arpCacheMu sync.Mutex
)

// resolveARPAddress resolves a MAC address on Windows.
// Primary: SendARP API (active ARP request, like the original Java app).
// Fallback: reads arp.exe output.
func resolveARPAddress(ip string) string {
	parsed := net.ParseIP(ip).To4()
	if parsed == nil {
		return ""
	}

	// Strategy 1: SendARP — sends an actual ARP request (matches legacy Java behavior)
	if mac := sendArp(parsed); mac != "" {
		return mac
	}

	// Strategy 2: read ARP cache via arp.exe
	return arpExeLookup(ip)
}

// sendArp calls the Windows SendARP API directly.
// This actively sends an ARP request and waits for a reply.
func sendArp(ip4 net.IP) string {
	destAddr := binary.LittleEndian.Uint32(ip4)

	// Buffer must be at least 2 ULONGs (8 bytes) per MSDN.
	// macLen MUST be set to the buffer size on input (not the expected MAC size).
	// The Java app sets this to 8 — matching that exactly.
	var mac [8]byte
	macLen := uint32(8)

	ret, _, _ := sendARPProc.Call(
		uintptr(destAddr),
		0, // source IP (0 = auto)
		uintptr(unsafe.Pointer(&mac[0])),
		uintptr(unsafe.Pointer(&macLen)),
	)

	if ret != 0 || macLen < 6 {
		return ""
	}

	// Skip zero MACs
	if mac[0]|mac[1]|mac[2]|mac[3]|mac[4]|mac[5] == 0 {
		return ""
	}

	return fmt.Sprintf("%02X:%02X:%02X:%02X:%02X:%02X",
		mac[0], mac[1], mac[2], mac[3], mac[4], mac[5])
}

// arpExeLookup reads the ARP cache via arp.exe as a fallback.
func arpExeLookup(ip string) string {
	arpCacheMu.Lock()
	defer arpCacheMu.Unlock()

	// Check cache
	if arpCache != nil {
		if mac, ok := arpCache[ip]; ok {
			return mac
		}
	}

	// Refresh and retry
	refreshArpCache()
	return arpCache[ip]
}

func refreshArpCache() {
	cmd := exec.Command("arp", "-a")
	cmd.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: 0x08000000, // CREATE_NO_WINDOW
	}
	out, err := cmd.CombinedOutput()
	if err != nil {
		return
	}

	newCache := make(map[string]string)
	for _, line := range strings.Split(string(out), "\n") {
		fields := strings.Fields(strings.TrimSpace(line))
		if len(fields) < 3 {
			continue
		}
		entryType := strings.ToLower(fields[len(fields)-1])
		if entryType != "dynamic" && entryType != "static" {
			continue
		}
		macAddr := fields[1]
		if !macAddrRegex.MatchString(macAddr) {
			continue
		}
		ipAddr := fields[0]
		normalized := addLeadingZeroes(strings.ToUpper(strings.ReplaceAll(macAddr, "-", ":")))
		newCache[ipAddr] = normalized
	}
	arpCache = newCache
}
