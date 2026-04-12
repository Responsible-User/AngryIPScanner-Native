package feeder

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"regexp"

	"github.com/angryip/libipscan/scanner"
)

var ipv4Regex = regexp.MustCompile(`\b(?:(?:25[0-5]|(?:2[0-4]|1?[0-9])?[0-9])\.){3}(?:25[0-5]|(?:2[0-4]|1?[0-9])?[0-9])\b`)

// FileFeeder reads IP addresses from a text file.
type FileFeeder struct {
	subjects []*scanner.ScanningSubject
	index    int
}

// NewFileFeeder creates a feeder from a file containing IP addresses.
func NewFileFeeder(filename string) (*FileFeeder, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("cannot open file: %w", err)
	}
	defer file.Close()

	seen := make(map[string]bool)
	var subjects []*scanner.ScanningSubject

	sc := bufio.NewScanner(file)
	for sc.Scan() {
		line := sc.Text()
		matches := ipv4Regex.FindAllString(line, -1)
		for _, m := range matches {
			if seen[m] {
				continue
			}
			ip := net.ParseIP(m)
			if ip == nil {
				continue
			}
			if ip4 := ip.To4(); ip4 != nil {
				ip = ip4
			}
			seen[m] = true
			subjects = append(subjects, scanner.NewScanningSubject(ip))
		}
	}

	if len(subjects) == 0 {
		return nil, fmt.Errorf("no IP addresses found in file")
	}

	return &FileFeeder{subjects: subjects}, nil
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
	return fmt.Sprintf("%d addresses", len(f.subjects))
}

func (f *FileFeeder) IsLocalNetwork() bool { return false }
