package fetcher

import (
	"fmt"
	"regexp"
	"strings"

	"github.com/angryip/libipscan/scanner"
)

const paramMAC = "fetcher.mac"

var macAddrRegex = regexp.MustCompile(`([a-fA-F0-9]{1,2}[-:]){5}[a-fA-F0-9]{1,2}`)
var leadingZeroRegex = regexp.MustCompile(`(?:^|[-:])([A-F0-9])(?:[-:]|$)`)

// MACFetcher resolves MAC addresses via the system arp command.
type MACFetcher struct {
	separator string
}

func NewMACFetcher() *MACFetcher {
	return &MACFetcher{separator: ":"}
}

func (f *MACFetcher) ID() string   { return "fetcher.mac" }
func (f *MACFetcher) Name() string { return "MAC Address" }
func (f *MACFetcher) Init()        {}
func (f *MACFetcher) Cleanup()     {}

func (f *MACFetcher) Scan(subject *scanner.ScanningSubject) interface{} {
	// Check cache
	if cached, ok := subject.GetParameter(paramMAC); ok {
		if mac, ok := cached.(string); ok {
			return f.replaceSeparator(mac)
		}
	}

	mac := f.resolveMAC(subject)
	if mac != "" {
		subject.SetParameter(paramMAC, mac)
	}
	return f.replaceSeparator(mac)
}

func (f *MACFetcher) resolveMAC(subject *scanner.ScanningSubject) string {
	return resolveARPAddress(subject.Address.String())
}

func extractMAC(line string) string {
	m := macAddrRegex.FindString(line)
	if m == "" {
		return ""
	}
	return addLeadingZeroes(strings.ToUpper(m))
}

func addLeadingZeroes(mac string) string {
	parts := strings.FieldsFunc(mac, func(r rune) bool { return r == ':' || r == '-' })
	for i, p := range parts {
		if len(p) == 1 {
			parts[i] = "0" + p
		}
	}
	return strings.Join(parts, ":")
}

func (f *MACFetcher) replaceSeparator(mac string) interface{} {
	if mac == "" {
		return nil
	}
	if f.separator != ":" {
		mac = strings.ReplaceAll(mac, ":", f.separator)
	}
	return mac
}

// MACVendorFetcher looks up the vendor name from a MAC address OUI prefix.
type MACVendorFetcher struct {
	macFetcher *MACFetcher
	vendors    map[string]string
}

func NewMACVendorFetcher(macFetcher *MACFetcher) *MACVendorFetcher {
	return &MACVendorFetcher{
		macFetcher: macFetcher,
		vendors:    make(map[string]string),
	}
}

func (f *MACVendorFetcher) ID() string   { return "fetcher.mac.vendor" }
func (f *MACVendorFetcher) Name() string { return "MAC Vendor" }

func (f *MACVendorFetcher) Init() {
	f.vendors = LoadMACVendors()
}

func (f *MACVendorFetcher) Cleanup() {}

func (f *MACVendorFetcher) Scan(subject *scanner.ScanningSubject) interface{} {
	// Get MAC from cache or resolve it
	var mac string
	if cached, ok := subject.GetParameter(paramMAC); ok {
		mac, _ = cached.(string)
	}
	if mac == "" {
		f.macFetcher.Scan(subject)
		if cached, ok := subject.GetParameter(paramMAC); ok {
			mac, _ = cached.(string)
		}
	}
	if mac == "" {
		return nil
	}

	return f.findVendor(mac)
}

func (f *MACVendorFetcher) findVendor(mac string) interface{} {
	// Extract OUI (first 6 hex chars without separators)
	oui := strings.ReplaceAll(mac, ":", "")
	oui = strings.ReplaceAll(oui, "-", "")
	if len(oui) < 6 {
		return nil
	}
	oui = oui[:6]

	if vendor, ok := f.vendors[oui]; ok {
		return vendor
	}
	return nil
}

// LoadMACVendors loads the mac-vendors.txt database.
// Format: first 6 chars = OUI, rest = vendor name
func LoadMACVendors() map[string]string {
	vendors := make(map[string]string, 40000)
	data := GetEmbeddedMACVendors()
	lines := strings.Split(data, "\n")
	for _, line := range lines {
		if len(line) < 7 {
			continue
		}
		oui := line[:6]
		vendor := line[6:]
		vendors[oui] = vendor
	}
	return vendors
}

// GetEmbeddedMACVendors returns the embedded mac-vendors.txt content.
// This is set by the resources package via go:embed.
var GetEmbeddedMACVendors = func() string {
	return "" // overridden by resources init
}

// FormatMAC formats 6 bytes as a MAC address string.
func FormatMAC(bytes []byte) string {
	if len(bytes) < 6 {
		return ""
	}
	return fmt.Sprintf("%02X:%02X:%02X:%02X:%02X:%02X",
		bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5])
}
