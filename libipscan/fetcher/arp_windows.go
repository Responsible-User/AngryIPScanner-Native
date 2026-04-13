//go:build windows

package fetcher

import (
	"os/exec"
	"strings"
	"sync"
	"syscall"
)

var (
	arpCache   map[string]string
	arpCacheMu sync.Mutex
)

// resolveARPAddress resolves a MAC address by reading the Windows ARP cache.
// Refreshes the cache on every miss so newly-created entries (from the prior
// ping step) are picked up immediately.
func resolveARPAddress(ip string) string {
	arpCacheMu.Lock()
	defer arpCacheMu.Unlock()

	// Fast path: cache hit
	if arpCache != nil {
		if mac, ok := arpCache[ip]; ok {
			return mac
		}
	}

	// Cache miss — refresh entire table and retry
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

		// Only keep dynamic or static entries
		entryType := strings.ToLower(fields[len(fields)-1])
		if entryType != "dynamic" && entryType != "static" {
			continue
		}

		macAddr := fields[1]
		if !macAddrRegex.MatchString(macAddr) {
			continue
		}

		ipAddr := fields[0]
		// Normalize: uppercase, colon-separated, zero-padded
		normalized := addLeadingZeroes(strings.ToUpper(strings.ReplaceAll(macAddr, "-", ":")))
		newCache[ipAddr] = normalized
	}

	arpCache = newCache
}
