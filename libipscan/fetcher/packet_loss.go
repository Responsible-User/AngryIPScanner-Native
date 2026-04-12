package fetcher

import (
	"fmt"

	"github.com/angryip/libipscan/pinger"
	"github.com/angryip/libipscan/scanner"
)

// PacketLossFetcher returns packet loss statistics from ping results.
type PacketLossFetcher struct {
	pingFetcher *PingFetcher
}

func NewPacketLossFetcher(pingFetcher *PingFetcher) *PacketLossFetcher {
	return &PacketLossFetcher{pingFetcher: pingFetcher}
}

func (f *PacketLossFetcher) ID() string   { return "fetcher.packetloss" }
func (f *PacketLossFetcher) Name() string { return "Packet Loss" }
func (f *PacketLossFetcher) Init()        {}
func (f *PacketLossFetcher) Cleanup()     {}

func (f *PacketLossFetcher) Scan(subject *scanner.ScanningSubject) interface{} {
	result := f.pingFetcher.ExecutePing(subject)
	if result.IsAlive() {
		subject.UpgradeResultType(scanner.ResultAlive)
	} else {
		subject.UpgradeResultType(scanner.ResultDead)
	}
	return formatPacketLoss(result)
}

func formatPacketLoss(r *pinger.PingResult) string {
	return fmt.Sprintf("%d/%d (%d%%)", r.PacketLoss(), r.PacketCount, r.PacketLossPercent())
}
