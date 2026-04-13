//go:build windows

package pinger

import (
	"os/exec"
	"strconv"
	"syscall"
)

// buildPingCmd creates a platform-appropriate ping command.
// Windows: ping -n <count> -w <timeout_ms> <address>, with the console window hidden.
func buildPingCmd(address string, count int, timeoutMs int) *exec.Cmd {
	cmd := exec.Command("ping",
		"-n", strconv.Itoa(count),
		"-w", strconv.Itoa(timeoutMs),
		address,
	)
	cmd.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: 0x08000000, // CREATE_NO_WINDOW
	}
	return cmd
}
