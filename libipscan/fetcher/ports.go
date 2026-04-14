package fetcher

import (
	"fmt"
	"net"
	"sort"
	"strings"
	"time"

	"github.com/Responsible-User/GoNetworkScanner/libipscan/ipnet"
	"github.com/Responsible-User/GoNetworkScanner/libipscan/pinger"
	"github.com/Responsible-User/GoNetworkScanner/libipscan/scanner"
)

const (
	paramOpenPorts     = "openPorts"
	paramFilteredPorts = "filteredPorts"
)

// PortsFetcher scans TCP ports and returns open ports.
type PortsFetcher struct {
	portString        string
	portTimeout       int // ms
	adaptPortTimeout  bool
	minPortTimeout    int // ms
	useRequestedPorts bool
	portIterator      *ipnet.PortIterator
}

// NewPortsFetcher creates a new ports fetcher.
func NewPortsFetcher(portString string, portTimeout int, adaptPortTimeout bool, minPortTimeout int, useRequestedPorts bool) *PortsFetcher {
	return &PortsFetcher{
		portString:        portString,
		portTimeout:       portTimeout,
		adaptPortTimeout:  adaptPortTimeout,
		minPortTimeout:    minPortTimeout,
		useRequestedPorts: useRequestedPorts,
	}
}

func (f *PortsFetcher) ID() string   { return "fetcher.ports" }
func (f *PortsFetcher) Name() string { return "Ports" }

// RunOnAborted lets the ports fetcher probe a "dead" host. This makes
// the port scan itself a reachability check — useful for hosts (e.g.
// Windows with RDP only) that don't respond to the generic pinger.
func (f *PortsFetcher) RunOnAborted() bool { return true }

func (f *PortsFetcher) Init() {
	pi, err := ipnet.ParsePorts(f.portString)
	if err == nil {
		f.portIterator = pi
	}
}

func (f *PortsFetcher) Cleanup() {}

func (f *PortsFetcher) Scan(subject *scanner.ScanningSubject) interface{} {
	openPorts, filteredPorts := f.scanPorts(subject)
	if openPorts == nil {
		return nil
	}

	if len(openPorts) > 0 {
		subject.UpgradeResultType(scanner.ResultWithPorts)
		return formatPorts(openPorts)
	}
	_ = filteredPorts
	return nil
}

func (f *PortsFetcher) scanPorts(subject *scanner.ScanningSubject) (open []int, filtered []int) {
	// Check if already scanned (cached by another fetcher)
	if cached, ok := subject.GetParameter(paramOpenPorts); ok {
		open, _ = cached.([]int)
		if cf, ok := subject.GetParameter(paramFilteredPorts); ok {
			filtered, _ = cf.([]int)
		}
		return
	}

	if f.portIterator == nil {
		return nil, nil
	}

	ports := f.buildPortList(subject)
	if len(ports) == 0 {
		return nil, nil
	}

	open = make([]int, 0)
	filtered = make([]int, 0)
	timeout := time.Duration(f.getAdaptedTimeout(subject)) * time.Millisecond

	for _, port := range ports {
		addr := net.JoinHostPort(subject.Address.String(), fmt.Sprintf("%d", port))

		conn, err := net.DialTimeout("tcp", addr, timeout)
		if conn != nil {
			conn.Close()
			open = append(open, port)
		} else if err != nil {
			if isTimeout(err) {
				filtered = append(filtered, port)
			}
			// Connection refused = port closed, not filtered
		}
	}

	sort.Ints(open)
	sort.Ints(filtered)
	subject.SetParameter(paramOpenPorts, open)
	subject.SetParameter(paramFilteredPorts, filtered)
	return
}

// buildPortList returns the ports to scan for this subject.
// Always includes the configured port list; adds subject.RequestedPorts
// (from file feeder ":port" annotations) if useRequestedPorts is enabled.
func (f *PortsFetcher) buildPortList(subject *scanner.ScanningSubject) []int {
	seen := make(map[int]struct{})
	var ports []int

	if f.portIterator != nil {
		pi := f.portIterator.Copy()
		for pi.HasNext() {
			p := pi.Next()
			if _, dup := seen[p]; dup {
				continue
			}
			seen[p] = struct{}{}
			ports = append(ports, p)
		}
	}

	if f.useRequestedPorts {
		for _, p := range subject.RequestedPorts {
			if p <= 0 || p >= 65536 {
				continue
			}
			if _, dup := seen[p]; dup {
				continue
			}
			seen[p] = struct{}{}
			ports = append(ports, p)
		}
	}

	return ports
}

func (f *PortsFetcher) getAdaptedTimeout(subject *scanner.ScanningSubject) int {
	if !f.adaptPortTimeout {
		return f.portTimeout
	}
	if cached, ok := subject.GetParameter(paramPingResult); ok {
		if pr, ok := cached.(*pinger.PingResult); ok && pr.LongestTime > 0 {
			adapted := int(pr.LongestTime) * 3
			if adapted < f.minPortTimeout {
				adapted = f.minPortTimeout
			}
			if adapted > f.portTimeout {
				adapted = f.portTimeout
			}
			return adapted
		}
	}
	return f.portTimeout
}

func isTimeout(err error) bool {
	if err == nil {
		return false
	}
	if ne, ok := err.(net.Error); ok {
		return ne.Timeout()
	}
	return false
}

func formatPorts(ports []int) string {
	if len(ports) == 0 {
		return ""
	}
	// Format as ranges where possible: 80,443,8080-8090
	var parts []string
	i := 0
	for i < len(ports) {
		start := ports[i]
		end := start
		for i+1 < len(ports) && ports[i+1] == end+1 {
			end = ports[i+1]
			i++
		}
		if start == end {
			parts = append(parts, fmt.Sprintf("%d", start))
		} else {
			parts = append(parts, fmt.Sprintf("%d-%d", start, end))
		}
		i++
	}
	return strings.Join(parts, ",")
}

// FilteredPortsFetcher returns filtered (timed-out) ports.
type FilteredPortsFetcher struct {
	portsFetcher *PortsFetcher
}

func NewFilteredPortsFetcher(pf *PortsFetcher) *FilteredPortsFetcher {
	return &FilteredPortsFetcher{portsFetcher: pf}
}

func (f *FilteredPortsFetcher) ID() string         { return "fetcher.ports.filtered" }
func (f *FilteredPortsFetcher) Name() string       { return "Filtered Ports" }
func (f *FilteredPortsFetcher) Init()              {}
func (f *FilteredPortsFetcher) Cleanup()           {}
func (f *FilteredPortsFetcher) RunOnAborted() bool { return true }

func (f *FilteredPortsFetcher) Scan(subject *scanner.ScanningSubject) interface{} {
	f.portsFetcher.scanPorts(subject)
	if cached, ok := subject.GetParameter(paramFilteredPorts); ok {
		if filtered, ok := cached.([]int); ok && len(filtered) > 0 {
			return formatPorts(filtered)
		}
	}
	return nil
}
