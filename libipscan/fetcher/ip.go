package fetcher

import "github.com/Responsible-User/GoNetworkScanner/libipscan/scanner"

// IPFetcher returns the IP address as a string.
type IPFetcher struct{}

func (f *IPFetcher) ID() string   { return "fetcher.ip" }
func (f *IPFetcher) Name() string { return "IP" }
func (f *IPFetcher) Init()        {}
func (f *IPFetcher) Cleanup()     {}

func (f *IPFetcher) Scan(subject *scanner.ScanningSubject) interface{} {
	return subject.Address.String()
}
