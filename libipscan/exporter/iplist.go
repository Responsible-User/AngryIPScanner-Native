package exporter

import (
	"fmt"
	"io"
)

type IPListExporter struct {
	ipIndex int
}

func (e *IPListExporter) ID() string            { return "iplist" }
func (e *IPListExporter) FileExtension() string  { return ".lst" }
func (e *IPListExporter) SetFetchers(names []string) {
	e.ipIndex = 0
	for i, n := range names {
		if n == "IP" {
			e.ipIndex = i
			break
		}
	}
}

func (e *IPListExporter) Start(w io.Writer, feederInfo string) error { return nil }

func (e *IPListExporter) WriteResult(w io.Writer, values []interface{}) error {
	if e.ipIndex < len(values) {
		fmt.Fprintln(w, valStr(values[e.ipIndex]))
	}
	return nil
}

func (e *IPListExporter) End(w io.Writer) error { return nil }
