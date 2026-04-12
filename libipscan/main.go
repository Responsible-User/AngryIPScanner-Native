// Package main provides the C-compatible shared library API for libipscan.
// Build with: go build -buildmode=c-shared -o libipscan.dylib
package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"encoding/json"
	"sync"
	"unsafe"

	"github.com/angryip/libipscan/config"
	"github.com/angryip/libipscan/scanner"
)

// Instance holds the state for one scanner session.
type Instance struct {
	config       *config.AppConfig
	stateMachine *scanner.StateMachine
	results      *scanner.ScanningResultList

	resultCallback   uintptr
	resultContext     unsafe.Pointer
	progressCallback uintptr
	progressContext  unsafe.Pointer
}

var (
	instances   = make(map[int]*Instance)
	instanceMu  sync.Mutex
	nextID      = 1
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

	inst := &Instance{
		config:       cfg,
		stateMachine: scanner.NewStateMachine(),
		results:      scanner.NewScanningResultList(),
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

// ipscan_free_string frees a C string allocated by this library.
//
//export ipscan_free_string
func ipscan_free_string(s *C.char) {
	C.free(unsafe.Pointer(s))
}

func getInstance(id int) *Instance {
	instanceMu.Lock()
	defer instanceMu.Unlock()
	return instances[id]
}

func main() {}
