//go:build !windows

package pinger

import (
	"os/exec"
	"strconv"
)

// buildPingCmd creates a platform-appropriate ping command.
// macOS/Linux: ping -c <count> -W <timeout_ms> <address>
func buildPingCmd(address string, count int, timeoutMs int) *exec.Cmd {
	return exec.Command("ping",
		"-c", strconv.Itoa(count),
		"-W", strconv.Itoa(timeoutMs),
		address,
	)
}
