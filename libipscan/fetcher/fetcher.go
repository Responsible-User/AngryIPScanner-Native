// Package fetcher provides the Fetcher interface and registry for data collection plugins.
package fetcher

import "github.com/Responsible-User/GoNetworkScanner/libipscan/scanner"

// Fetcher gathers one type of information for a scanned host (one column in results).
type Fetcher interface {
	// ID returns a unique identifier for this fetcher.
	ID() string

	// Name returns the human-readable name of this fetcher.
	Name() string

	// Scan performs the fetch for the given subject and returns the result value.
	// The value is typically a string, but can be any type that serializes to JSON.
	Scan(subject *scanner.ScanningSubject) interface{}

	// Init is called before a scan begins. The fetcher can perform setup here.
	Init()

	// Cleanup is called after a scan completes.
	Cleanup()
}

// Registry manages available and selected fetchers.
type Registry struct {
	available []Fetcher
	selected  []Fetcher
}

// NewRegistry creates a new fetcher registry with the given available fetchers.
func NewRegistry(fetchers ...Fetcher) *Registry {
	return &Registry{
		available: fetchers,
		selected:  nil,
	}
}

// Available returns all registered fetchers.
func (r *Registry) Available() []Fetcher {
	return r.available
}

// Selected returns the currently selected fetchers.
func (r *Registry) Selected() []Fetcher {
	if r.selected == nil {
		return r.available
	}
	return r.selected
}

// SetSelected updates the selected fetcher list by IDs.
func (r *Registry) SetSelected(ids []string) {
	idSet := make(map[string]Fetcher, len(r.available))
	for _, f := range r.available {
		idSet[f.ID()] = f
	}
	r.selected = make([]Fetcher, 0, len(ids))
	for _, id := range ids {
		if f, ok := idSet[id]; ok {
			r.selected = append(r.selected, f)
		}
	}
}

// SelectedIDs returns the IDs of the selected fetchers.
func (r *Registry) SelectedIDs() []string {
	sel := r.Selected()
	ids := make([]string, len(sel))
	for i, f := range sel {
		ids[i] = f.ID()
	}
	return ids
}
