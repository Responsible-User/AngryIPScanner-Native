//go:build !windows

package fetcher

import (
	"os/exec"
	"strings"
)

// resolveARPAddress uses the system arp command to resolve a MAC address.
// macOS/Linux: arp -n <ip>
func resolveARPAddress(ip string) string {
	out, err := exec.Command("arp", "-n", ip).CombinedOutput()
	if err != nil {
		return ""
	}

	lines := strings.Split(string(out), "\n")
	for _, line := range lines {
		if strings.Contains(line, ip) {
			if mac := extractMAC(line); mac != "" {
				return mac
			}
		}
	}
	return ""
}
