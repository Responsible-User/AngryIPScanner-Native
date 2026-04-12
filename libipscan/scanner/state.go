package scanner

import "sync"

// ScanState represents the current state of the scanning process.
type ScanState int

const (
	StateIdle     ScanState = iota
	StateStarting
	StateScanning
	StateStopping
	StateKilling
)

// String returns the state name.
func (s ScanState) String() string {
	switch s {
	case StateIdle:
		return "idle"
	case StateStarting:
		return "starting"
	case StateScanning:
		return "scanning"
	case StateStopping:
		return "stopping"
	case StateKilling:
		return "killing"
	default:
		return "unknown"
	}
}

// StateMachine manages scan state transitions with thread-safe access.
type StateMachine struct {
	mu        sync.RWMutex
	state     ScanState
	listeners []StateTransitionListener
}

// StateTransitionListener is called when the scan state changes.
type StateTransitionListener func(oldState, newState ScanState)

// NewStateMachine creates a new state machine in the idle state.
func NewStateMachine() *StateMachine {
	return &StateMachine{state: StateIdle}
}

// State returns the current state.
func (sm *StateMachine) State() ScanState {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.state
}

// AddListener registers a state transition listener.
func (sm *StateMachine) AddListener(l StateTransitionListener) {
	sm.mu.Lock()
	sm.listeners = append(sm.listeners, l)
	sm.mu.Unlock()
}

// TransitionToNext advances the state machine to the next logical state.
// IDLE → STARTING → SCANNING → STOPPING → KILLING → IDLE
func (sm *StateMachine) TransitionToNext() ScanState {
	sm.mu.Lock()
	old := sm.state
	switch sm.state {
	case StateIdle:
		sm.state = StateStarting
	case StateStarting:
		sm.state = StateScanning
	case StateScanning:
		sm.state = StateStopping
	case StateStopping:
		sm.state = StateKilling
	case StateKilling:
		sm.state = StateIdle
	}
	newState := sm.state
	listeners := make([]StateTransitionListener, len(sm.listeners))
	copy(listeners, sm.listeners)
	sm.mu.Unlock()

	for _, l := range listeners {
		l(old, newState)
	}
	return newState
}

// TransitionTo forces a transition to a specific state.
func (sm *StateMachine) TransitionTo(state ScanState) {
	sm.mu.Lock()
	old := sm.state
	sm.state = state
	listeners := make([]StateTransitionListener, len(sm.listeners))
	copy(listeners, sm.listeners)
	sm.mu.Unlock()

	for _, l := range listeners {
		l(old, state)
	}
}

// IsScanning returns true if a scan is in progress.
func (sm *StateMachine) IsScanning() bool {
	s := sm.State()
	return s == StateScanning || s == StateStarting
}

// IsStopping returns true if the scan is stopping or killing.
func (sm *StateMachine) IsStopping() bool {
	s := sm.State()
	return s == StateStopping || s == StateKilling
}
