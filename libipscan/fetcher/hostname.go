package fetcher

import (
	"context"
	"net"
	"time"

	"github.com/angryip/libipscan/scanner"
)

// HostnameFetcher resolves hostnames via reverse DNS lookup.
type HostnameFetcher struct{}

func (f *HostnameFetcher) ID() string   { return "fetcher.hostname" }
func (f *HostnameFetcher) Name() string { return "Hostname" }
func (f *HostnameFetcher) Init()        {}
func (f *HostnameFetcher) Cleanup()     {}

func (f *HostnameFetcher) Scan(subject *scanner.ScanningSubject) interface{} {
	// Reverse DNS lookup with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	resolver := net.DefaultResolver
	names, err := resolver.LookupAddr(ctx, subject.Address.String())
	if err != nil || len(names) == 0 {
		return nil
	}

	name := names[0]
	// Remove trailing dot from FQDN
	if len(name) > 0 && name[len(name)-1] == '.' {
		name = name[:len(name)-1]
	}

	// Don't return the IP as hostname (that's what happens when there's no PTR record)
	if name == subject.Address.String() {
		return nil
	}

	return name
}
