package scanner

import (
	"context"
	"log"
	"sync"
	"sync/atomic"
	"time"
)

const uiUpdateInterval = 150 * time.Millisecond

// Feeder generates scanning subjects (duplicated here to avoid circular import).
type Feeder interface {
	Next() *ScanningSubject
	HasNext() bool
	PercentComplete() float64
	Info() string
	IsLocalNetwork() bool
}

// Fetcher gathers one type of information for a scanned host.
type Fetcher interface {
	ID() string
	Name() string
	Scan(subject *ScanningSubject) interface{}
	Init()
	Cleanup()
}

// AbortBypasser is an optional interface that lets a fetcher run even
// after subject.Aborted is set (e.g. the ports fetcher, which doubles
// as a reachability probe when the user configures explicit ports).
type AbortBypasser interface {
	RunOnAborted() bool
}

// ScanProgress holds progress information sent to the UI.
type ScanProgress struct {
	CurrentIP     string  `json:"current_ip"`
	Percent       float64 `json:"percent"`
	ActiveThreads int32   `json:"active_threads"`
	State         string  `json:"state"`
}

// ResultCallback is called for each scan result.
// Called twice per IP: once when scanning starts (type=unknown, empty values),
// and again when scanning completes (type=alive/dead/with_ports, filled values).
type ResultCallback func(result *ScanningResult, complete bool)

// ProgressCallback is called periodically with progress updates.
type ProgressCallback func(progress ScanProgress)

// EngineConfig holds settings for the scan engine.
type EngineConfig struct {
	MaxThreads           int
	ThreadDelay          time.Duration
	ScanDeadHosts        bool
	SkipBroadcastAddrs   bool
}

// Engine orchestrates the scanning process using a goroutine pool.
type Engine struct {
	mu            sync.Mutex
	stateMachine  *StateMachine
	results       *ScanningResultList
	fetchers      []Fetcher

	onResult   ResultCallback
	onProgress ProgressCallback

	cancelFunc context.CancelFunc
	activeThreads atomic.Int32
}

// NewEngine creates a new scan engine.
func NewEngine(sm *StateMachine, results *ScanningResultList) *Engine {
	return &Engine{
		stateMachine: sm,
		results:      results,
	}
}

// SetCallbacks configures the result and progress callbacks.
func (e *Engine) SetCallbacks(onResult ResultCallback, onProgress ProgressCallback) {
	e.mu.Lock()
	e.onResult = onResult
	e.onProgress = onProgress
	e.mu.Unlock()
}

// SetFetchers configures which fetchers to use during scanning.
func (e *Engine) SetFetchers(fetchers []Fetcher) {
	e.mu.Lock()
	e.fetchers = fetchers
	e.mu.Unlock()
}

// StartScan begins scanning using the provided feeder and config.
// This runs asynchronously — returns immediately.
func (e *Engine) StartScan(feeder Feeder, cfg EngineConfig) {
	ctx, cancel := context.WithCancel(context.Background())
	e.cancelFunc = cancel

	// Transition to starting
	e.stateMachine.TransitionTo(StateStarting)

	// Init fetchers
	for _, f := range e.fetchers {
		f.Init()
	}

	e.results.Clear()

	// Transition to scanning
	e.stateMachine.TransitionTo(StateScanning)

	go e.runScan(ctx, feeder, cfg)
}

// StopScan signals the engine to stop scanning gracefully.
func (e *Engine) StopScan() {
	if e.stateMachine.IsScanning() {
		e.stateMachine.TransitionTo(StateStopping)
	}
	if e.cancelFunc != nil {
		e.cancelFunc()
	}
}

// KillScan forces immediate termination.
func (e *Engine) KillScan() {
	e.stateMachine.TransitionTo(StateKilling)
	if e.cancelFunc != nil {
		e.cancelFunc()
	}
}

func (e *Engine) runScan(ctx context.Context, feeder Feeder, cfg EngineConfig) {
	defer func() {
		// Cleanup fetchers
		for _, f := range e.fetchers {
			f.Cleanup()
		}
		e.stateMachine.TransitionTo(StateIdle)
	}()

	sem := make(chan struct{}, cfg.MaxThreads)
	var wg sync.WaitGroup

	lastNotify := time.Now()
	var lastIP string

	for feeder.HasNext() {
		// Check if we should stop
		if ctx.Err() != nil || e.stateMachine.IsStopping() {
			break
		}

		// Thread delay
		if cfg.ThreadDelay > 0 {
			time.Sleep(cfg.ThreadDelay)
		}

		subject := feeder.Next()
		if subject == nil {
			continue
		}

		lastIP = subject.Address.String()

		// Skip broadcast addresses if configured
		if cfg.SkipBroadcastAddrs && e.isLikelyBroadcast(subject) {
			continue
		}

		// Acquire semaphore slot
		select {
		case sem <- struct{}{}:
		case <-ctx.Done():
			continue
		}

		result := NewScanningResult(subject.Address, len(e.fetchers))

		// Send result immediately so UI shows the row (type=unknown)
		if e.onResult != nil {
			e.onResult(result, false)
		}

		wg.Add(1)

		go func(subj *ScanningSubject, res *ScanningResult) {
			defer func() {
				<-sem
				e.activeThreads.Add(-1)
				wg.Done()
			}()
			e.activeThreads.Add(1)

			e.scanSubject(subj, res)

			e.results.Add(res)
			if e.onResult != nil {
				e.onResult(res, true)
			}
		}(subject, result)

		// Progress notification (throttled)
		now := time.Now()
		if now.Sub(lastNotify) >= uiUpdateInterval {
			lastNotify = now
			if e.onProgress != nil {
				e.onProgress(ScanProgress{
					CurrentIP:     lastIP,
					Percent:       feeder.PercentComplete() * 100,
					ActiveThreads: e.activeThreads.Load(),
					State:         e.stateMachine.State().String(),
				})
			}
		}
	}

	// Signal stopping
	e.stateMachine.TransitionTo(StateStopping)

	// Wait for all goroutines to finish
	done := make(chan struct{})
	go func() {
		wg.Wait()
		close(done)
	}()

	// Keep sending progress while waiting
	ticker := time.NewTicker(uiUpdateInterval)
	defer ticker.Stop()
	for {
		select {
		case <-done:
			// Final progress
			if e.onProgress != nil {
				e.onProgress(ScanProgress{
					CurrentIP:     "",
					Percent:       100,
					ActiveThreads: 0,
					State:         "idle",
				})
			}
			return
		case <-ticker.C:
			if e.onProgress != nil {
				e.onProgress(ScanProgress{
					CurrentIP:     lastIP,
					Percent:       100,
					ActiveThreads: e.activeThreads.Load(),
					State:         e.stateMachine.State().String(),
				})
			}
		}
	}
}

func (e *Engine) scanSubject(subject *ScanningSubject, result *ScanningResult) {
	for i, fetcher := range e.fetchers {
		if subject.Aborted {
			if bp, ok := fetcher.(AbortBypasser); !ok || !bp.RunOnAborted() {
				continue
			}
		}

		var value interface{}
		func() {
			defer func() {
				if r := recover(); r != nil {
					log.Printf("fetcher %s panicked: %v", fetcher.ID(), r)
					value = nil
				}
			}()
			value = fetcher.Scan(subject)
		}()

		result.Values[i] = value
	}

	result.Type = subject.ResultType
}

func (e *Engine) isLikelyBroadcast(subject *ScanningSubject) bool {
	addr := subject.Address.To4()
	if addr == nil {
		return false
	}
	last := addr[3]

	if subject.BroadcastAddr != nil {
		if subject.Address.Equal(subject.BroadcastAddr) {
			return true
		}
		// Network address check (last byte 0, same prefix)
		if last == 0 && subject.InterfaceAddr != nil {
			ifAddr := subject.InterfaceAddr.To4()
			if ifAddr != nil {
				for i := 0; i < 3; i++ {
					if addr[i] != ifAddr[i] {
						return false
					}
				}
				return true
			}
		}
		return false
	}
	return last == 0 || last == 0xFF
}
