package fetcher

import (
	"bufio"
	"fmt"
	"net"
	"regexp"
	"time"

	scannerPkg "github.com/angryip/libipscan/scanner"
)

// WebDetectFetcher detects web server software via HTTP.
type WebDetectFetcher struct {
	portTimeout int // ms
}

func NewWebDetectFetcher(portTimeout int) *WebDetectFetcher {
	return &WebDetectFetcher{portTimeout: portTimeout}
}

func (f *WebDetectFetcher) ID() string   { return "fetcher.webDetect" }
func (f *WebDetectFetcher) Name() string { return "Web detect" }
func (f *WebDetectFetcher) Init()        {}
func (f *WebDetectFetcher) Cleanup()     {}

var serverHeaderRegex = regexp.MustCompile(`(?i)^server:\s+(.*)$`)

func (f *WebDetectFetcher) Scan(subject *scannerPkg.ScanningSubject) interface{} {
	timeout := time.Duration(f.portTimeout) * time.Millisecond
	addr := fmt.Sprintf("%s:80", subject.Address)

	conn, err := net.DialTimeout("tcp", addr, timeout)
	if err != nil {
		return nil
	}
	defer conn.Close()

	conn.SetDeadline(time.Now().Add(timeout * 2))
	_, err = conn.Write([]byte("HEAD /robots.txt HTTP/1.0\r\n\r\n"))
	if err != nil {
		return nil
	}

	sc := bufio.NewScanner(conn)
	for sc.Scan() {
		line := sc.Text()
		m := serverHeaderRegex.FindStringSubmatch(line)
		if len(m) > 1 {
			subject.UpgradeResultType(scannerPkg.ResultWithPorts)
			return m[1]
		}
	}
	return nil
}
