// Package resources provides embedded data files.
package resources

import (
	_ "embed"

	"github.com/Responsible-User/GoNetworkScanner/libipscan/fetcher"
)

//go:embed mac-vendors.txt
var macVendorsData string

func init() {
	fetcher.GetEmbeddedMACVendors = func() string {
		return macVendorsData
	}
}
