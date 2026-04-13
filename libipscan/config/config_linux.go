//go:build !darwin && !windows

package config

import (
	"os"
	"path/filepath"
)

func platformConfigDir() (string, error) {
	// XDG Base Directory: use $XDG_CONFIG_HOME or ~/.config
	xdg := os.Getenv("XDG_CONFIG_HOME")
	if xdg == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return "", err
		}
		xdg = filepath.Join(home, ".config")
	}
	return filepath.Join(xdg, "AngryIPScanner"), nil
}
