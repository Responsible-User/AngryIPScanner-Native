package scanner

import (
	"net"
	"sync"
	"testing"
	"time"
)

// mockFeeder generates a fixed set of IPs.
type mockFeeder struct {
	ips   []net.IP
	index int
}

func (f *mockFeeder) HasNext() bool              { return f.index < len(f.ips) }
func (f *mockFeeder) PercentComplete() float64    { return float64(f.index) / float64(len(f.ips)) }
func (f *mockFeeder) Info() string                { return "mock" }
func (f *mockFeeder) IsLocalNetwork() bool        { return false }
func (f *mockFeeder) Next() *ScanningSubject {
	if f.index >= len(f.ips) {
		return nil
	}
	ip := f.ips[f.index]
	f.index++
	return NewScanningSubject(ip)
}

// mockFetcher returns the IP as a string value.
type mockFetcher struct {
	id   string
	name string
}

func (f *mockFetcher) ID() string                          { return f.id }
func (f *mockFetcher) Name() string                        { return f.name }
func (f *mockFetcher) Init()                               {}
func (f *mockFetcher) Cleanup()                            {}
func (f *mockFetcher) Scan(s *ScanningSubject) interface{} {
	s.ResultType = ResultAlive
	return s.Address.String()
}

func TestEngineScansAllIPs(t *testing.T) {
	sm := NewStateMachine()
	results := NewScanningResultList()
	engine := NewEngine(sm, results)

	feeder := &mockFeeder{
		ips: []net.IP{
			net.ParseIP("10.0.0.1").To4(),
			net.ParseIP("10.0.0.2").To4(),
			net.ParseIP("10.0.0.3").To4(),
		},
	}

	engine.SetFetchers([]Fetcher{&mockFetcher{id: "test.ip", name: "IP"}})

	var mu sync.Mutex
	var resultIPs []string
	engine.SetCallbacks(
		func(result *ScanningResult, complete bool) {
			if complete {
				mu.Lock()
				resultIPs = append(resultIPs, result.Address.String())
				mu.Unlock()
			}
		},
		nil,
	)

	engine.StartScan(feeder, EngineConfig{
		MaxThreads:  10,
		ThreadDelay: 0,
	})

	// Wait for scan to complete
	deadline := time.After(5 * time.Second)
	for {
		select {
		case <-deadline:
			t.Fatal("scan timed out")
		default:
			if sm.State() == StateIdle && results.Len() >= 3 {
				goto done
			}
			time.Sleep(50 * time.Millisecond)
		}
	}
done:

	mu.Lock()
	defer mu.Unlock()

	if len(resultIPs) != 3 {
		t.Fatalf("expected 3 results, got %d: %v", len(resultIPs), resultIPs)
	}

	total, alive, _ := results.Stats()
	if total != 3 {
		t.Errorf("expected total=3, got %d", total)
	}
	if alive != 3 {
		t.Errorf("expected alive=3, got %d", alive)
	}
}

func TestEngineStopScan(t *testing.T) {
	sm := NewStateMachine()
	results := NewScanningResultList()
	engine := NewEngine(sm, results)

	// Create a large feeder
	ips := make([]net.IP, 1000)
	for i := range ips {
		ips[i] = net.IPv4(10, 0, byte(i/256), byte(i%256)).To4()
	}
	feeder := &mockFeeder{ips: ips}

	engine.SetFetchers([]Fetcher{&mockFetcher{id: "test.ip", name: "IP"}})
	engine.SetCallbacks(nil, nil)

	engine.StartScan(feeder, EngineConfig{
		MaxThreads:  5,
		ThreadDelay: time.Millisecond,
	})

	// Let it run briefly
	time.Sleep(100 * time.Millisecond)

	// Stop it
	engine.StopScan()

	// Wait for idle
	deadline := time.After(5 * time.Second)
	for {
		select {
		case <-deadline:
			t.Fatal("stop timed out")
		default:
			if sm.State() == StateIdle {
				goto done
			}
			time.Sleep(50 * time.Millisecond)
		}
	}
done:

	// Should have scanned fewer than all 1000
	if results.Len() >= 1000 {
		t.Error("expected scan to be stopped early")
	}
}
