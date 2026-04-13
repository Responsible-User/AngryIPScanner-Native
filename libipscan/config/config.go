// Package config provides scanner configuration with JSON persistence.
package config

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// ScannerConfig holds all scanner-related settings.
type ScannerConfig struct {
	MaxThreads           int    `json:"maxThreads"`
	ThreadDelay          int    `json:"threadDelay"`
	ScanDeadHosts        bool   `json:"scanDeadHosts"`
	SelectedPinger       string `json:"selectedPinger"`
	PingTimeout          int    `json:"pingTimeout"`
	PingCount            int    `json:"pingCount"`
	SkipBroadcastAddrs   bool   `json:"skipBroadcastAddresses"`
	PortTimeout          int    `json:"portTimeout"`
	AdaptPortTimeout     bool   `json:"adaptPortTimeout"`
	MinPortTimeout       int    `json:"minPortTimeout"`
	PortString           string `json:"portString"`
	UseRequestedPorts    bool   `json:"useRequestedPorts"`
	NotAvailableText     string `json:"notAvailableText"`
	NotScannedText       string `json:"notScannedText"`
	SelectedFetcherIDs   []string `json:"selectedFetchers,omitempty"`
}

// defaultPingerID can be overridden per-platform via init() in build-tagged files.
var defaultPingerID = "pinger.combined"

// DefaultScannerConfig returns a config with sensible defaults.
func DefaultScannerConfig() *ScannerConfig {
	return &ScannerConfig{
		MaxThreads:         100,
		ThreadDelay:        20,
		ScanDeadHosts:      false,
		SelectedPinger:     defaultPingerID,
		PingTimeout:        2000,
		PingCount:          3,
		SkipBroadcastAddrs: true,
		PortTimeout:        2000,
		AdaptPortTimeout:   true,
		MinPortTimeout:     100,
		PortString:         "22,80,443",
		UseRequestedPorts:  true,
		NotAvailableText:   "[n/a]",
		NotScannedText:     "[n/s]",
	}
}

// AppConfig holds the full application configuration.
type AppConfig struct {
	Scanner   ScannerConfig   `json:"scanner"`
	Favorites []FavoriteEntry `json:"favorites,omitempty"`
	Openers   []OpenerEntry   `json:"openers,omitempty"`
	Comments  map[string]string `json:"comments,omitempty"`
}

// FavoriteEntry stores a saved scan configuration.
type FavoriteEntry struct {
	Name       string `json:"name"`
	FeederType string `json:"feederType"`
	FeederArgs string `json:"feederArgs"`
}

// OpenerEntry stores an external command definition.
type OpenerEntry struct {
	Name    string `json:"name"`
	Command string `json:"command"`
}

// DefaultAppConfig returns the full config with defaults.
func DefaultAppConfig() *AppConfig {
	return &AppConfig{
		Scanner: *DefaultScannerConfig(),
		Openers: defaultOpeners(),
		Comments: make(map[string]string),
	}
}

func defaultOpeners() []OpenerEntry {
	return []OpenerEntry{
		{Name: "Web Browser", Command: "open http://${fetcher.ip}"},
		{Name: "SSH", Command: "ssh ${fetcher.ip}"},
		{Name: "Ping", Command: "ping ${fetcher.ip}"},
		{Name: "Traceroute", Command: "traceroute ${fetcher.ip}"},
	}
}

// OverrideConfigDir can be set by the host app (e.g. Swift) before
// calling ipscan_new. Supports sandboxed apps that must use their container.
var OverrideConfigDir string

// ConfigDir returns the configuration directory path, creating it if needed.
// If OverrideConfigDir is set, uses that. Otherwise falls back to platform default.
func ConfigDir() (string, error) {
	var dir string
	if OverrideConfigDir != "" {
		dir = OverrideConfigDir
	} else {
		var err error
		dir, err = platformConfigDir()
		if err != nil {
			return "", err
		}
	}
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", err
	}
	return dir, nil
}

// ConfigPath returns the full path to the config file.
func ConfigPath() (string, error) {
	dir, err := ConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "config.json"), nil
}

// Load reads the configuration from disk. Returns defaults if file doesn't exist.
func Load() (*AppConfig, error) {
	path, err := ConfigPath()
	if err != nil {
		cfg := DefaultAppConfig()
		return cfg, nil
	}

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			cfg := DefaultAppConfig()
			return cfg, nil
		}
		return nil, err
	}

	cfg := DefaultAppConfig()
	if err := json.Unmarshal(data, cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}

// Save writes the configuration to disk.
func (c *AppConfig) Save() error {
	path, err := ConfigPath()
	if err != nil {
		return err
	}

	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}
