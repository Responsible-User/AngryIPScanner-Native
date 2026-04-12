package fetcher

import (
	"fmt"
	"log"
	"time"

	"github.com/angryip/libipscan/pinger"
	"github.com/angryip/libipscan/scanner"
)

const paramPingResult = "pinger"

// PingFetcher pings the target and returns average RTT.
// Sets result type to ALIVE or DEAD based on ping result.
type PingFetcher struct {
	pingerID      string
	pingTimeout   time.Duration
	pingCount     int
	scanDeadHosts bool
	p             pinger.Pinger
}

// NewPingFetcher creates a new ping fetcher.
func NewPingFetcher(pingerID string, pingTimeout time.Duration, pingCount int, scanDeadHosts bool) *PingFetcher {
	return &PingFetcher{
		pingerID:      pingerID,
		pingTimeout:   pingTimeout,
		pingCount:     pingCount,
		scanDeadHosts: scanDeadHosts,
	}
}

func (f *PingFetcher) ID() string   { return "fetcher.ping" }
func (f *PingFetcher) Name() string { return "Ping" }

func (f *PingFetcher) Init() {
	f.p = pinger.NewPinger(f.pingerID, f.pingTimeout)
}

func (f *PingFetcher) Cleanup() {
	if f.p != nil {
		f.p.Close()
		f.p = nil
	}
}

// ExecutePing runs the ping and caches the result in the subject's parameters.
func (f *PingFetcher) ExecutePing(subject *scanner.ScanningSubject) *pinger.PingResult {
	if cached, ok := subject.GetParameter(paramPingResult); ok {
		if pr, ok := cached.(*pinger.PingResult); ok {
			return pr
		}
	}

	result, err := f.p.Ping(subject.Address, f.pingCount, f.pingTimeout)
	if err != nil {
		log.Printf("ping %s failed: %v", subject.Address, err)
		result = pinger.NewPingResult(subject.Address, 0)
	}

	subject.SetParameter(paramPingResult, result)
	return result
}

func (f *PingFetcher) Scan(subject *scanner.ScanningSubject) interface{} {
	result := f.ExecutePing(subject)

	if result.IsAlive() {
		subject.ResultType = scanner.ResultAlive
	} else {
		subject.ResultType = scanner.ResultDead
	}

	if !result.IsAlive() && !f.scanDeadHosts {
		subject.Aborted = true
	}

	if result.IsAlive() {
		return fmt.Sprintf("%d ms", result.AverageTime())
	}
	return nil
}
