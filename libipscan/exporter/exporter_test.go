package exporter

import (
	"bytes"
	"strings"
	"testing"
)

func TestCSVExporter(t *testing.T) {
	e := &CSVExporter{}
	e.SetFetchers([]string{"IP", "Ping", "Hostname"})

	var buf bytes.Buffer
	e.Start(&buf, "test")
	e.WriteResult(&buf, []interface{}{"192.168.1.1", "5 ms", "router.local"})
	e.WriteResult(&buf, []interface{}{"192.168.1.2", nil, "desktop"})
	e.End(&buf)

	out := buf.String()
	lines := strings.Split(strings.TrimSpace(out), "\n")
	if len(lines) != 3 {
		t.Fatalf("expected 3 lines, got %d: %q", len(lines), out)
	}
	if lines[0] != "IP,Ping,Hostname" {
		t.Errorf("header = %q", lines[0])
	}
	if lines[1] != "192.168.1.1,5 ms,router.local" {
		t.Errorf("row1 = %q", lines[1])
	}
	if lines[2] != "192.168.1.2,,desktop" {
		t.Errorf("row2 = %q", lines[2])
	}
}

func TestCSVExporterEscaping(t *testing.T) {
	e := &CSVExporter{}
	e.SetFetchers([]string{"Name"})

	var buf bytes.Buffer
	e.Start(&buf, "")
	e.WriteResult(&buf, []interface{}{"hello, world"})
	e.End(&buf)

	lines := strings.Split(strings.TrimSpace(buf.String()), "\n")
	if lines[1] != `"hello, world"` {
		t.Errorf("escaped = %q, want %q", lines[1], `"hello, world"`)
	}
}

func TestTXTExporter(t *testing.T) {
	e := &TXTExporter{}
	e.SetFetchers([]string{"IP", "Status"})

	var buf bytes.Buffer
	e.Start(&buf, "10.0.0.1 - 10.0.0.255")
	e.WriteResult(&buf, []interface{}{"10.0.0.1", "alive"})
	e.End(&buf)

	out := buf.String()
	if !strings.Contains(out, "Angry IP Scanner") {
		t.Error("TXT output should contain app name")
	}
	if !strings.Contains(out, "10.0.0.1") {
		t.Error("TXT output should contain IP")
	}
}

func TestXMLExporter(t *testing.T) {
	e := &XMLExporter{}
	e.SetFetchers([]string{"IP", "Ping"})

	var buf bytes.Buffer
	e.Start(&buf, "test scan")
	e.WriteResult(&buf, []interface{}{"10.0.0.1", "5 ms"})
	e.End(&buf)

	out := buf.String()
	if !strings.Contains(out, `<?xml version="1.0"`) {
		t.Error("XML should have declaration")
	}
	if !strings.Contains(out, `<host address="10.0.0.1">`) {
		t.Error("XML should have host element")
	}
	if !strings.Contains(out, "</scanning_report>") {
		t.Error("XML should have closing tag")
	}
}

func TestIPListExporter(t *testing.T) {
	e := &IPListExporter{}
	e.SetFetchers([]string{"IP", "Ping"})

	var buf bytes.Buffer
	e.Start(&buf, "")
	e.WriteResult(&buf, []interface{}{"10.0.0.1", "alive"})
	e.WriteResult(&buf, []interface{}{"10.0.0.2", "dead"})
	e.End(&buf)

	lines := strings.Split(strings.TrimSpace(buf.String()), "\n")
	if len(lines) != 2 {
		t.Fatalf("expected 2 lines, got %d", len(lines))
	}
	if lines[0] != "10.0.0.1" {
		t.Errorf("line[0] = %q", lines[0])
	}
}

func TestSQLExporter(t *testing.T) {
	e := &SQLExporter{}
	e.SetFetchers([]string{"IP", "Ping"})

	var buf bytes.Buffer
	e.Start(&buf, "")
	e.WriteResult(&buf, []interface{}{"10.0.0.1", "5 ms"})
	e.End(&buf)

	out := buf.String()
	if !strings.Contains(out, "CREATE TABLE") {
		t.Error("SQL should have CREATE TABLE")
	}
	if !strings.Contains(out, "INSERT INTO") {
		t.Error("SQL should have INSERT")
	}
	if !strings.Contains(out, "'10.0.0.1'") {
		t.Error("SQL should have IP value")
	}
}

func TestSQLExporterEscaping(t *testing.T) {
	e := &SQLExporter{}
	e.SetFetchers([]string{"Name"})

	var buf bytes.Buffer
	e.Start(&buf, "")
	e.WriteResult(&buf, []interface{}{"it's a test"})
	e.End(&buf)

	if !strings.Contains(buf.String(), "it''s a test") {
		t.Error("SQL should escape single quotes")
	}
}
