//go:build windows

package config

// On Windows, use the native ICMP pinger (IcmpSendEcho API) by default.
// This matches the original Java app's behavior — faster and more reliable
// than the combined TCP+UDP pinger on Windows networks.
func init() {
	defaultPingerID = "pinger.windows"
}
