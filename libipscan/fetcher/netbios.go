package fetcher

import (
	"fmt"
	"net"
	"strings"
	"time"

	"github.com/Responsible-User/GoNetworkScanner/libipscan/scanner"
)

const netbiosUDPPort = 137

// NetBIOS name query request data
var netbiosRequestData = []byte{
	0xA2, 0x48, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x20, 0x43, 0x4b, 0x41,
	0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
	0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
	0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
	0x41, 0x41, 0x41, 0x41, 0x41, 0x00, 0x00, 0x21,
	0x00, 0x01,
}

const (
	responseTypePos      = 47
	responseTypeNBSTAT   = 33
	responseBaseLen      = 57
	responseNameLen      = 15
	responseNameBlockLen = 18
	groupNameFlag        = 128
	nameTypeDomain       = 0x00
	nameTypeMessenger    = 0x03
)

// NetBIOSInfoFetcher gathers NetBIOS information about Windows machines.
type NetBIOSInfoFetcher struct {
	timeout int // ms
}

func NewNetBIOSInfoFetcher(timeout int) *NetBIOSInfoFetcher {
	return &NetBIOSInfoFetcher{timeout: timeout}
}

func (f *NetBIOSInfoFetcher) ID() string   { return "fetcher.netbios" }
func (f *NetBIOSInfoFetcher) Name() string { return "NetBIOS Info" }
func (f *NetBIOSInfoFetcher) Init()        {}
func (f *NetBIOSInfoFetcher) Cleanup()     {}

func (f *NetBIOSInfoFetcher) Scan(subject *scanner.ScanningSubject) interface{} {
	timeout := time.Duration(f.timeout) * time.Millisecond

	conn, err := net.DialTimeout("udp", net.JoinHostPort(subject.Address.String(), fmt.Sprintf("%d", netbiosUDPPort)), timeout)
	if err != nil {
		return nil
	}
	defer conn.Close()

	conn.SetDeadline(time.Now().Add(timeout))
	_, err = conn.Write(netbiosRequestData)
	if err != nil {
		return nil
	}

	response := make([]byte, 1024)
	n, err := conn.Read(response)
	if err != nil || n < responseBaseLen {
		return nil
	}

	if response[responseTypePos] != responseTypeNBSTAT {
		return nil
	}

	nameCount := int(response[responseBaseLen-1])
	if n < responseBaseLen+responseNameBlockLen*nameCount {
		return nil
	}

	return extractNetBIOSNames(response, nameCount)
}

func extractNetBIOSNames(response []byte, nameCount int) string {
	var computerName string
	if nameCount > 0 {
		computerName = netbiosName(response, 0)
	}

	var groupName string
	for i := 1; i < nameCount; i++ {
		if netbiosNameType(response, i) == nameTypeDomain && (netbiosNameFlag(response, i)&groupNameFlag) > 0 {
			groupName = netbiosName(response, i)
			break
		}
	}

	var userName string
	for i := nameCount - 1; i > 0; i-- {
		if netbiosNameType(response, i) == nameTypeMessenger {
			userName = netbiosName(response, i)
			break
		}
	}

	macAddr := fmt.Sprintf("%02X-%02X-%02X-%02X-%02X-%02X",
		netbiosNameByte(response, nameCount, 0),
		netbiosNameByte(response, nameCount, 1),
		netbiosNameByte(response, nameCount, 2),
		netbiosNameByte(response, nameCount, 3),
		netbiosNameByte(response, nameCount, 4),
		netbiosNameByte(response, nameCount, 5),
	)

	var parts []string
	if groupName != "" {
		parts = append(parts, groupName+"\\")
	}
	if userName != "" {
		parts = append(parts, userName+"@")
	}
	if computerName != "" {
		parts = append(parts, computerName+" ")
	}
	parts = append(parts, "["+macAddr+"]")

	return strings.Join(parts, "")
}

func netbiosName(response []byte, i int) string {
	offset := responseBaseLen + responseNameBlockLen*i
	name := string(response[offset : offset+responseNameLen])
	return strings.TrimSpace(name)
}

func netbiosNameByte(response []byte, i, n int) byte {
	return response[responseBaseLen+responseNameBlockLen*i+n]
}

func netbiosNameFlag(response []byte, i int) int {
	offset := responseBaseLen + responseNameBlockLen*i + responseNameLen + 1
	return int(response[offset]) + int(response[offset+1])*0xFF
}

func netbiosNameType(response []byte, i int) int {
	return int(response[responseBaseLen+responseNameBlockLen*i+responseNameLen])
}
