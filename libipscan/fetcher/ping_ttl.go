package fetcher

import (
	"github.com/Responsible-User/GoNetworkScanner/libipscan/scanner"
)

// PingTTLFetcher shares ping results with PingFetcher and returns the TTL.
type PingTTLFetcher struct {
	pingFetcher *PingFetcher
}

// NewPingTTLFetcher creates a TTL fetcher that delegates to the given PingFetcher.
func NewPingTTLFetcher(pingFetcher *PingFetcher) *PingTTLFetcher {
	return &PingTTLFetcher{pingFetcher: pingFetcher}
}

func (f *PingTTLFetcher) ID() string   { return "fetcher.ping.ttl" }
func (f *PingTTLFetcher) Name() string { return "TTL" }
func (f *PingTTLFetcher) Init()        {}
func (f *PingTTLFetcher) Cleanup()     {}

func (f *PingTTLFetcher) Scan(subject *scanner.ScanningSubject) interface{} {
	result := f.pingFetcher.ExecutePing(subject)

	if result.IsAlive() {
		subject.UpgradeResultType(scanner.ResultAlive)
	} else {
		subject.UpgradeResultType(scanner.ResultDead)
	}

	if result.IsAlive() && result.TTL > 0 {
		return result.TTL
	}
	return nil
}
