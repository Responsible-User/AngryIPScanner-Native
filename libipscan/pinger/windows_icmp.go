//go:build windows

// Windows native ICMP pinger using IcmpSendEcho from iphlpapi.dll.
// This is a direct port of the legacy Java WindowsPinger which used JNA
// to call the same API. It's faster and more reliable than shelling out
// to ping.exe, and works without elevated privileges.

package pinger

import (
	"encoding/binary"
	"net"
	"syscall"
	"time"
	"unsafe"
)

var (
	iphlpapi        = syscall.NewLazyDLL("iphlpapi.dll")
	icmpCreateFile  = iphlpapi.NewProc("IcmpCreateFile")
	icmpSendEcho    = iphlpapi.NewProc("IcmpSendEcho")
	icmpCloseHandle = iphlpapi.NewProc("IcmpCloseHandle")
)

// ICMP_ECHO_REPLY layout on 64-bit Windows (ARM64/x64):
//
//	Offset  0: Address          (IPAddr, 4 bytes)
//	Offset  4: Status           (ULONG, 4 bytes)
//	Offset  8: RoundTripTime    (ULONG, 4 bytes)
//	Offset 12: DataSize         (USHORT, 2 bytes)
//	Offset 14: Reserved         (USHORT, 2 bytes)
//	Offset 16: Data             (PVOID, 8 bytes on 64-bit)
//	Offset 24: Options.Ttl      (UCHAR, 1 byte)
//	Offset 25: Options.Tos      (UCHAR, 1 byte)
//	Offset 26: Options.Flags    (UCHAR, 1 byte)
//	Offset 27: Options.OptSize  (UCHAR, 1 byte)
//	Offset 28: padding          (4 bytes for pointer alignment)
//	Offset 32: Options.OptData  (PUCHAR, 8 bytes on 64-bit)
//	Total: 40 bytes
const icmpEchoReplySize = 40

// WindowsPinger uses the Windows ICMP API for native echo requests.
type WindowsPinger struct {
	timeout time.Duration
}

// NewWindowsPinger creates a new Windows native ICMP pinger.
func NewWindowsPinger(timeout time.Duration) *WindowsPinger {
	return &WindowsPinger{timeout: timeout}
}

func (p *WindowsPinger) ID() string { return "pinger.windows" }

func (p *WindowsPinger) Ping(address net.IP, count int, timeout time.Duration) (*PingResult, error) {
	if timeout == 0 {
		timeout = p.timeout
	}

	result := NewPingResult(address, count)

	ip4 := address.To4()
	if ip4 == nil {
		// IPv6 not yet supported via this pinger; fall through as no replies
		return result, nil
	}

	destAddr := binary.LittleEndian.Uint32(ip4)

	handle, _, _ := icmpCreateFile.Call()
	invalidHandle := ^uintptr(0) // INVALID_HANDLE_VALUE
	if handle == 0 || handle == invalidHandle {
		return result, nil
	}
	defer icmpCloseHandle.Call(handle)

	sendDataSize := 32
	replyBufSize := sendDataSize + icmpEchoReplySize + 8

	sendData := make([]byte, sendDataSize)
	replyBuf := make([]byte, replyBufSize)

	timeoutMs := int(timeout.Milliseconds())

	for i := 0; i < count; i++ {
		numReplies, _, _ := icmpSendEcho.Call(
			handle,
			uintptr(destAddr),
			uintptr(unsafe.Pointer(&sendData[0])),
			uintptr(sendDataSize),
			0, // no IP options
			uintptr(unsafe.Pointer(&replyBuf[0])),
			uintptr(replyBufSize),
			uintptr(timeoutMs),
		)

		if numReplies > 0 {
			status := binary.LittleEndian.Uint32(replyBuf[4:8])
			rtt := binary.LittleEndian.Uint32(replyBuf[8:12])

			if status == 0 { // IP_SUCCESS
				result.AddReply(int64(rtt))
				result.TTL = int(replyBuf[24]) // Options.Ttl
			}
		}
	}

	return result, nil
}

func (p *WindowsPinger) Close() error { return nil }
