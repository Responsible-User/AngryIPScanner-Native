package exporter

import (
	"io"
	"strings"
)

type CSVExporter struct {
	fetcherNames []string
}

func (e *CSVExporter) ID() string            { return "csv" }
func (e *CSVExporter) FileExtension() string  { return ".csv" }
func (e *CSVExporter) SetFetchers(names []string) { e.fetcherNames = names }

func (e *CSVExporter) Start(w io.Writer, feederInfo string) error {
	// Write header row
	for i, name := range e.fetcherNames {
		if i > 0 {
			w.Write([]byte(","))
		}
		w.Write([]byte(csvSafe(name)))
	}
	w.Write([]byte("\n"))
	return nil
}

func (e *CSVExporter) WriteResult(w io.Writer, values []interface{}) error {
	for i, v := range values {
		if i > 0 {
			w.Write([]byte(","))
		}
		w.Write([]byte(csvSafe(valStr(v))))
	}
	w.Write([]byte("\n"))
	return nil
}

func (e *CSVExporter) End(w io.Writer) error { return nil }

func csvSafe(s string) string {
	if strings.ContainsAny(s, ",\"\n") {
		return "\"" + strings.ReplaceAll(s, "\"", "\"\"") + "\""
	}
	return s
}
