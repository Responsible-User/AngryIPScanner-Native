package feeder

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"regexp"
	"strconv"

	"github.com/Responsible-User/GoNetworkScanner/libipscan/scanner"
)

// Matches IPv4, IPv6, and hostnames (like the Java HOSTNAME_REGEX).
// Also matches hostnames like "example.com" and "router.local".
var addressRegex = regexp.MustCompile(
	// IPv4
	`\b(?:(?:25[0-5]|(?:2[0-4]|1?[0-9])?[0-9])\.){3}(?:25[0-5]|(?:2[0-4]|1?[0-9])?[0-9])\b` +
		// OR IPv6 (simple patterns, covers most common forms)
		`|(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}` +
		`|(?:[0-9a-fA-F]{1,4}:){1,7}:` +
		`|::(?:[0-9a-fA-F]{1,4}:){0,6}[0-9a-fA-F]{0,4}` +
		`|(?:[0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}` +
		// OR hostname
		`|\b(?:[a-zA-Z][a-zA-Z0-9-]*\.)+[a-zA-Z]{2,}\b`,
)

// Matches a port number immediately after a colon (e.g. "192.168.1.1:8080")
var portSuffixRegex = regexp.MustCompile(`^:(\d{1,5})\b`)

// FileFeeder reads IP addresses from a text file.
// Accepts any text file; regex extracts IPs, IPv6 addresses, and hostnames.
// Supports "IP:port" notation to specify a requested port.
//
// Example file contents:
//
//	192.168.1.1
//	192.168.1.2:22
//	example.com
//	fe80::1
//	router.local:443
//	# comments and other text are ignored — only matching addresses are extracted
type FileFeeder struct {
	subjects []*scanner.ScanningSubject
	index    int
	path     string
}

// NewFileFeeder creates a feeder from a file containing addresses.
func NewFileFeeder(filename string) (*FileFeeder, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("cannot open file: %w", err)
	}
	defer file.Close()

	seen := make(map[string]int) // addr -> index in subjects (for adding requested ports)
	var subjects []*scanner.ScanningSubject

	sc := bufio.NewScanner(file)
	for sc.Scan() {
		line := sc.Text()
		matches := addressRegex.FindAllStringIndex(line, -1)
		for _, loc := range matches {
			addrStr := line[loc[0]:loc[1]]

			// Resolve to IP — net.ParseIP handles v4/v6, net.LookupHost handles names
			ip := net.ParseIP(addrStr)
			if ip == nil {
				// Attempt DNS resolution for hostnames
				resolved, lookupErr := net.LookupIP(addrStr)
				if lookupErr != nil || len(resolved) == 0 {
					continue
				}
				ip = resolved[0]
			}
			if ip4 := ip.To4(); ip4 != nil {
				ip = ip4
			}

			key := ip.String()
			subjectIdx, exists := seen[key]
			var subject *scanner.ScanningSubject
			if exists {
				subject = subjects[subjectIdx]
			} else {
				subject = scanner.NewScanningSubject(ip)
				seen[key] = len(subjects)
				subjects = append(subjects, subject)
			}

			// Check for ":port" suffix immediately after the address
			afterAddr := line[loc[1]:]
			if portMatch := portSuffixRegex.FindStringSubmatch(afterAddr); len(portMatch) == 2 {
				if port, err := strconv.Atoi(portMatch[1]); err == nil && port > 0 && port < 65536 {
					subject.RequestedPorts = append(subject.RequestedPorts, port)
				}
			}
		}
	}

	if len(subjects) == 0 {
		return nil, fmt.Errorf("no IP addresses, hostnames, or IPv6 addresses found in file")
	}

	return &FileFeeder{subjects: subjects, path: filename}, nil
}

func (f *FileFeeder) HasNext() bool { return f.index < len(f.subjects) }

func (f *FileFeeder) Next() *scanner.ScanningSubject {
	if f.index >= len(f.subjects) {
		return nil
	}
	s := f.subjects[f.index]
	f.index++
	return s
}

func (f *FileFeeder) PercentComplete() float64 {
	if len(f.subjects) == 0 {
		return 1.0
	}
	return float64(f.index) / float64(len(f.subjects))
}

func (f *FileFeeder) Info() string {
	return fmt.Sprintf("%d addresses from %s", len(f.subjects), f.path)
}

func (f *FileFeeder) IsLocalNetwork() bool { return false }
