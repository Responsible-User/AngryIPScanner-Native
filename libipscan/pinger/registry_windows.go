//go:build windows

package pinger

import "time"

func init() {
	platformPingers["pinger.windows"] = func(t time.Duration) Pinger {
		return NewWindowsPinger(t)
	}
}
