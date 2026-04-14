package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDefaultScannerConfig(t *testing.T) {
	cfg := DefaultScannerConfig()
	if cfg.MaxThreads != 100 {
		t.Errorf("MaxThreads = %d, want 100", cfg.MaxThreads)
	}
	if cfg.PingTimeout != 2000 {
		t.Errorf("PingTimeout = %d, want 2000", cfg.PingTimeout)
	}
	if cfg.PingCount != 5 {
		t.Errorf("PingCount = %d, want 5", cfg.PingCount)
	}
	if cfg.PortString != "22,80,443" {
		t.Errorf("PortString = %q, want %q", cfg.PortString, "22,80,443")
	}
	if !cfg.SkipBroadcastAddrs {
		t.Error("SkipBroadcastAddrs should be true")
	}
	if !cfg.AdaptPortTimeout {
		t.Error("AdaptPortTimeout should be true")
	}
}

func TestDefaultAppConfig(t *testing.T) {
	cfg := DefaultAppConfig()
	if cfg.Comments == nil {
		t.Error("Comments map should not be nil")
	}
	if len(cfg.Openers) == 0 {
		t.Error("Openers should have defaults")
	}
	// Check default openers include SSH and Web Browser
	found := false
	for _, o := range cfg.Openers {
		if o.Name == "SSH" {
			found = true
		}
	}
	if !found {
		t.Error("Default openers should include SSH")
	}
}

func TestSaveAndLoad(t *testing.T) {
	// Use a temp directory
	tmpDir := t.TempDir()
	OverrideConfigDir = tmpDir
	defer func() { OverrideConfigDir = "" }()

	// Create and save config
	cfg := DefaultAppConfig()
	cfg.Scanner.MaxThreads = 42
	cfg.Scanner.PortString = "22,80,443,8080"
	cfg.Comments["10.0.0.1"] = "test router"
	cfg.Favorites = append(cfg.Favorites, FavoriteEntry{
		Name:       "My LAN",
		FeederArgs: "192.168.1.1 - 192.168.1.255",
	})

	if err := cfg.Save(); err != nil {
		t.Fatalf("Save failed: %v", err)
	}

	// Verify file exists
	path := filepath.Join(tmpDir, "config.json")
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("Config file not created: %v", err)
	}

	// Load it back
	loaded, err := Load()
	if err != nil {
		t.Fatalf("Load failed: %v", err)
	}

	if loaded.Scanner.MaxThreads != 42 {
		t.Errorf("MaxThreads = %d, want 42", loaded.Scanner.MaxThreads)
	}
	if loaded.Scanner.PortString != "22,80,443,8080" {
		t.Errorf("PortString = %q, want %q", loaded.Scanner.PortString, "22,80,443,8080")
	}
	if loaded.Comments["10.0.0.1"] != "test router" {
		t.Errorf("Comment = %q, want %q", loaded.Comments["10.0.0.1"], "test router")
	}
	if len(loaded.Favorites) != 1 || loaded.Favorites[0].Name != "My LAN" {
		t.Errorf("Favorites not loaded correctly: %v", loaded.Favorites)
	}
}

func TestLoadMissingFile(t *testing.T) {
	tmpDir := t.TempDir()
	OverrideConfigDir = tmpDir
	defer func() { OverrideConfigDir = "" }()

	// Should return defaults when file doesn't exist
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load should not error on missing file: %v", err)
	}
	if cfg.Scanner.MaxThreads != 100 {
		t.Errorf("Should return default MaxThreads, got %d", cfg.Scanner.MaxThreads)
	}
}

func TestConfigDir(t *testing.T) {
	tmpDir := t.TempDir()
	OverrideConfigDir = tmpDir
	defer func() { OverrideConfigDir = "" }()

	dir, err := ConfigDir()
	if err != nil {
		t.Fatalf("ConfigDir failed: %v", err)
	}
	if dir != tmpDir {
		t.Errorf("ConfigDir = %q, want %q", dir, tmpDir)
	}
}
