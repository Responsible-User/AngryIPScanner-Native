// Package feeder provides IP address generators for scanning.
package feeder

import "github.com/angryip/libipscan/scanner"

// Feeder generates ScanningSubject instances to be scanned.
type Feeder interface {
	// Next returns the next scanning subject, or nil when exhausted.
	Next() *scanner.ScanningSubject

	// HasNext returns true if more subjects are available.
	HasNext() bool

	// PercentComplete returns the scan progress as a float 0.0 - 1.0.
	PercentComplete() float64

	// Info returns a human-readable description of the feeder's current config.
	Info() string

	// IsLocalNetwork returns true if this feeder covers the local network.
	IsLocalNetwork() bool
}
