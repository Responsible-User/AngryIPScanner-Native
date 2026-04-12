// Package exporter provides scan result export to various file formats.
package exporter

import (
	"io"

	"github.com/angryip/libipscan/scanner"
)

// Exporter writes scan results to an output stream in a specific format.
type Exporter interface {
	// ID returns a unique identifier (e.g. "csv", "txt", "xml").
	ID() string

	// FileExtension returns the file extension (e.g. ".csv").
	FileExtension() string

	// Start writes any header/preamble to the writer.
	Start(w io.Writer, feederInfo string) error

	// SetFetchers provides the column names.
	SetFetchers(names []string)

	// WriteResult writes one result row.
	WriteResult(w io.Writer, values []interface{}) error

	// End writes any footer/closing content.
	End(w io.Writer) error
}
