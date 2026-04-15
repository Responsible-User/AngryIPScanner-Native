## Windows alpha release

**This is an alpha build. It has not been tested on real user hardware beyond the machine it was compiled on.** The Go core has unit tests and the Mac build of the same release is known to work, but the Windows UI and WPF ↔ Go P/Invoke layer have only been smoke-tested. Expect bugs. Please file issues.

### Downloads

| Architecture | Installer (recommended) | Portable zip |
|--------------|------------------------|--------------|
| **Intel / AMD 64-bit** | [GoNetworkScanner-Setup-1.0.0-win-x64.exe](./releases/download/v1.0.0-win-alpha/GoNetworkScanner-Setup-1.0.0-win-x64.exe) (4.6 MB) | [GoNetworkScanner-1.0.0-win-x64.zip](./releases/download/v1.0.0-win-alpha/GoNetworkScanner-1.0.0-win-x64.zip) (3.3 MB) |
| **ARM64** | [GoNetworkScanner-Setup-1.0.0-win-arm64.exe](./releases/download/v1.0.0-win-alpha/GoNetworkScanner-Setup-1.0.0-win-arm64.exe) (4.3 MB) | [GoNetworkScanner-1.0.0-win-arm64.zip](./releases/download/v1.0.0-win-alpha/GoNetworkScanner-1.0.0-win-arm64.zip) (3.1 MB) |

Not sure which CPU you have? **System Settings → System → About → System type** will tell you. "x64" = Intel/AMD, "ARM" = Snapdragon / Surface Pro X / Copilot+ PC.

### Requirements

- Windows 10 (1809) / Windows 11
- [.NET 10 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/10.0)

The installer checks for .NET 10 and will direct you to Microsoft's download page if it's missing. The portable zip assumes you already have it.

### First-launch note

These builds are not code-signed, so Windows SmartScreen will warn "Windows protected your PC" on first launch. Click **More info** → **Run anyway**. Code signing is on the roadmap.

### What should work

- Range and CIDR scanning with auto-detected local subnet
- Five pingers: Windows native ICMP (default, uses `IcmpSendEcho` API), TCP, UDP, combined TCP+UDP, and `ping.exe`
- MAC address + vendor lookup via Windows `SendARP` API
- Hostname (reverse DNS), open port scan, filtered-port detection, NetBIOS info, web service detection, packet loss
- Statistics, per-IP details dialog with persistent comments
- Favorites (save and load named scans)
- Find in results (Ctrl+F), Go To Next/Previous Alive Host, Select Alive/Dead/With Ports/Invert
- Openers: launch browser / SSH / ping / tracert against a selected IP
- Export filtered results to CSV, TXT, XML, IP list, or SQL
- Multi-window scanning (Ctrl+N) with shared on-disk config
- File feeder (scan an IP list from a text file)

### Known unknowns

- Performance on large scans (e.g. /16 ranges) hasn't been profiled on Windows
- Behavior with Windows Defender Firewall in its stricter modes
- Interaction with third-party security products that may block the raw ICMP API or ARP resolution
- All high-DPI / multi-monitor cases
- Anything involving IPv6 — only IPv4 is tested

If any of these turn out to be broken, please open an issue with your Windows version, CPU type, and what you tried to scan.
