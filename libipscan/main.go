// Package main provides the C-compatible shared library API for libipscan.
// Build with: go build -buildmode=c-shared -o libipscan.dylib
package main

/*
#include <stdlib.h>

typedef void (*ResultCallback)(const char* result_json, void* context);
typedef void (*ProgressCallback)(const char* progress_json, void* context);

static inline void call_result_cb(ResultCallback cb, const char* json, void* ctx) {
	if (cb) cb(json, ctx);
}
static inline void call_progress_cb(ProgressCallback cb, const char* json, void* ctx) {
	if (cb) cb(json, ctx);
}
*/
import "C"
import (
	"encoding/json"
	"sync"
	"time"
	"unsafe"

	"github.com/angryip/libipscan/config"
	"github.com/angryip/libipscan/feeder"
	"github.com/angryip/libipscan/fetcher"
	"github.com/angryip/libipscan/scanner"
)

// Instance holds the state for one scanner session.
type Instance struct {
	config       *config.AppConfig
	stateMachine *scanner.StateMachine
	results      *scanner.ScanningResultList
	engine       *scanner.Engine

	resultCb   C.ResultCallback
	resultCtx  unsafe.Pointer
	progressCb C.ProgressCallback
	progressCtx unsafe.Pointer
}

var (
	instances  = make(map[int]*Instance)
	instanceMu sync.Mutex
	nextID     = 1
)

//export ipscan_new
func ipscan_new(configJSON *C.char) C.int {
	var cfg *config.AppConfig
	if configJSON != nil {
		s := C.GoString(configJSON)
		cfg = config.DefaultAppConfig()
		if len(s) > 0 {
			json.Unmarshal([]byte(s), cfg)
		}
	} else {
		cfg = config.DefaultAppConfig()
	}

	sm := scanner.NewStateMachine()
	results := scanner.NewScanningResultList()
	eng := scanner.NewEngine(sm, results)

	inst := &Instance{
		config:       cfg,
		stateMachine: sm,
		results:      results,
		engine:       eng,
	}

	instanceMu.Lock()
	id := nextID
	nextID++
	instances[id] = inst
	instanceMu.Unlock()

	return C.int(id)
}

//export ipscan_free
func ipscan_free(handle C.int) {
	instanceMu.Lock()
	delete(instances, int(handle))
	instanceMu.Unlock()
}

//export ipscan_get_state
func ipscan_get_state(handle C.int) *C.char {
	inst := getInstance(int(handle))
	if inst == nil {
		return C.CString(`{"state":"unknown"}`)
	}
	state := inst.stateMachine.State()
	j, _ := json.Marshal(map[string]interface{}{
		"state": state.String(),
	})
	return C.CString(string(j))
}

//export ipscan_get_config
func ipscan_get_config(handle C.int) *C.char {
	inst := getInstance(int(handle))
	if inst == nil {
		return C.CString("{}")
	}
	j, _ := json.Marshal(inst.config)
	return C.CString(string(j))
}

//export ipscan_set_config
func ipscan_set_config(handle C.int, configJSON *C.char) C.int {
	inst := getInstance(int(handle))
	if inst == nil {
		return -1
	}
	s := C.GoString(configJSON)
	if err := json.Unmarshal([]byte(s), inst.config); err != nil {
		return -1
	}
	return 0
}

//export ipscan_set_result_callback
func ipscan_set_result_callback(handle C.int, cb C.ResultCallback, ctx unsafe.Pointer) {
	inst := getInstance(int(handle))
	if inst == nil {
		return
	}
	inst.resultCb = cb
	inst.resultCtx = ctx
}

//export ipscan_set_progress_callback
func ipscan_set_progress_callback(handle C.int, cb C.ProgressCallback, ctx unsafe.Pointer) {
	inst := getInstance(int(handle))
	if inst == nil {
		return
	}
	inst.progressCb = cb
	inst.progressCtx = ctx
}

// FeederConfig describes which feeder to use and its parameters.
type FeederConfig struct {
	Type    string `json:"type"`
	StartIP string `json:"startIP,omitempty"`
	EndIP   string `json:"endIP,omitempty"`
}

//export ipscan_start_scan
func ipscan_start_scan(handle C.int, feederJSON *C.char) C.int {
	inst := getInstance(int(handle))
	if inst == nil {
		return -1
	}

	// Parse feeder config
	var fc FeederConfig
	if feederJSON != nil {
		s := C.GoString(feederJSON)
		if err := json.Unmarshal([]byte(s), &fc); err != nil {
			return -2
		}
	}

	// Create feeder
	var f scanner.Feeder
	switch fc.Type {
	case "range", "":
		rf, err := feeder.NewRangeFeeder(fc.StartIP, fc.EndIP)
		if err != nil {
			return -3
		}
		f = rf
	default:
		return -4
	}

	// Create fetchers
	cfg := inst.config.Scanner
	pingTimeout := time.Duration(cfg.PingTimeout) * time.Millisecond
	pingFetcher := fetcher.NewPingFetcher(cfg.SelectedPinger, pingTimeout, cfg.PingCount, cfg.ScanDeadHosts)

	fetchers := []scanner.Fetcher{
		&fetcher.IPFetcher{},
		pingFetcher,
		fetcher.NewPingTTLFetcher(pingFetcher),
		&fetcher.HostnameFetcher{},
	}

	// Apply selected fetcher filter if configured
	if len(cfg.SelectedFetcherIDs) > 0 {
		fetcherMap := make(map[string]scanner.Fetcher)
		for _, ft := range fetchers {
			fetcherMap[ft.ID()] = ft
		}
		var selected []scanner.Fetcher
		for _, id := range cfg.SelectedFetcherIDs {
			if ft, ok := fetcherMap[id]; ok {
				selected = append(selected, ft)
			}
		}
		if len(selected) > 0 {
			fetchers = selected
		}
	}

	inst.engine.SetFetchers(fetchers)

	// Set up callbacks
	inst.engine.SetCallbacks(
		func(result *scanner.ScanningResult) {
			if inst.resultCb != nil {
				j, _ := json.Marshal(map[string]interface{}{
					"ip":     result.Address.String(),
					"type":   resultTypeString(result.Type),
					"values": result.Values,
					"mac":    result.MAC,
				})
				cstr := C.CString(string(j))
				C.call_result_cb(inst.resultCb, cstr, inst.resultCtx)
				C.free(unsafe.Pointer(cstr))
			}
		},
		func(progress scanner.ScanProgress) {
			if inst.progressCb != nil {
				j, _ := json.Marshal(progress)
				cstr := C.CString(string(j))
				C.call_progress_cb(inst.progressCb, cstr, inst.progressCtx)
				C.free(unsafe.Pointer(cstr))
			}
		},
	)

	// Start scanning
	engineCfg := scanner.EngineConfig{
		MaxThreads:         cfg.MaxThreads,
		ThreadDelay:        time.Duration(cfg.ThreadDelay) * time.Millisecond,
		ScanDeadHosts:      cfg.ScanDeadHosts,
		SkipBroadcastAddrs: cfg.SkipBroadcastAddrs,
	}

	inst.engine.StartScan(f, engineCfg)
	return 0
}

//export ipscan_stop_scan
func ipscan_stop_scan(handle C.int) C.int {
	inst := getInstance(int(handle))
	if inst == nil {
		return -1
	}
	inst.engine.StopScan()
	return 0
}

//export ipscan_get_results_count
func ipscan_get_results_count(handle C.int) C.int {
	inst := getInstance(int(handle))
	if inst == nil {
		return 0
	}
	return C.int(inst.results.Len())
}

//export ipscan_get_stats
func ipscan_get_stats(handle C.int) *C.char {
	inst := getInstance(int(handle))
	if inst == nil {
		return C.CString("{}")
	}
	total, alive, withPorts := inst.results.Stats()
	j, _ := json.Marshal(map[string]interface{}{
		"total":     total,
		"alive":     alive,
		"withPorts": withPorts,
	})
	return C.CString(string(j))
}

//export ipscan_get_result
func ipscan_get_result(handle C.int, index C.int) *C.char {
	inst := getInstance(int(handle))
	if inst == nil {
		return C.CString("{}")
	}
	result := inst.results.Get(int(index))
	if result == nil {
		return C.CString("{}")
	}
	j, _ := json.Marshal(map[string]interface{}{
		"ip":     result.Address.String(),
		"type":   resultTypeString(result.Type),
		"values": result.Values,
		"mac":    result.MAC,
	})
	return C.CString(string(j))
}

//export ipscan_get_available_fetchers
func ipscan_get_available_fetchers(handle C.int) *C.char {
	fetchers := []map[string]string{
		{"id": "fetcher.ip", "name": "IP"},
		{"id": "fetcher.ping", "name": "Ping"},
		{"id": "fetcher.ping.ttl", "name": "TTL"},
		{"id": "fetcher.hostname", "name": "Hostname"},
	}
	j, _ := json.Marshal(fetchers)
	return C.CString(string(j))
}

//export ipscan_free_string
func ipscan_free_string(s *C.char) {
	C.free(unsafe.Pointer(s))
}

func getInstance(id int) *Instance {
	instanceMu.Lock()
	defer instanceMu.Unlock()
	return instances[id]
}

func resultTypeString(rt scanner.ResultType) string {
	switch rt {
	case scanner.ResultAlive:
		return "alive"
	case scanner.ResultDead:
		return "dead"
	case scanner.ResultWithPorts:
		return "with_ports"
	default:
		return "unknown"
	}
}

func main() {}
