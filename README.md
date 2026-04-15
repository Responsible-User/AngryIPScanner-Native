# Go Network Scanner

[![CI](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)

A fast, native network scanner for **macOS** and **Windows**. Written from the ground up in **Go** (scanning engine), **Swift/SwiftUI** (macOS UI), and **C# + WPF** (Windows UI). No Java, no JVM.

Inspired by [Angry IP Scanner](https://angryip.org). This project shares no source code with the original — it's a fresh implementation with an independent design, MIT-licensed.

## Download

[Latest releases](../../releases)

### macOS

Signed, notarized builds of `GoNetworkScanner.app` available from the Releases page.

**Requirements:** macOS 14 (Sonoma) or later. Apple Silicon and Intel.

### Windows

Two flavors per architecture. Get either one from the Releases page:

| Architecture | Installer (recommended) | Portable zip |
|--------------|------------------------|--------------|
| Intel / AMD 64-bit | `GoNetworkScanner-Setup-*-win-x64.exe` | `GoNetworkScanner-*-win-x64.zip` |
| ARM64 | `GoNetworkScanner-Setup-*-win-arm64.exe` | `GoNetworkScanner-*-win-arm64.zip` |

**Requirements:** Windows 10 (1809) or Windows 11, plus the [.NET 10 Desktop Runtime](https://dotnet.microsoft.com/download/dotnet/10.0). The installer offers to download .NET for you if it's missing; the portable zip assumes you already have it.

Builds aren't code-signed yet, so Windows SmartScreen will warn on first launch — click **More info** → **Run anyway**.

> **Note:** the current Windows release is tagged `*-win-alpha` and hasn't been broadly tested. Expect rough edges, please file issues.

### Linux

Not available yet, and no timeline. The Go core already builds for Linux, but no Linux UI has been written. Contributions welcome — see the architecture section below.

## Features

### Scanning
- Ping sweep with **TCP, UDP, ICMP, or combined** pingers (Windows also ships a native `IcmpSendEcho`-based pinger as the default)
- **12 fetchers** — IP, Ping, TTL, Hostname, Ports, Filtered Ports, MAC Address, MAC Vendor, Web detect, NetBIOS, Packet Loss, Comments
- **3 input modes** — IP Range, CIDR (auto-detected), File import
- **CIDR auto-detection** — reads your network adapter on launch
- **Real-time results** — IPs appear as scanning starts, update when complete

### UI (both platforms)
- Sortable columns with live filtering (All / Alive / With Ports)
- **Find** with wrap-around search
- **Go To** next/previous alive host with auto-scroll
- **Double-click** to open details with per-IP comment field
- **Right-click menu** — Details, Copy, Open in Browser/SSH/Ping/Traceroute, Rescan, Delete
- **Favorites** — save and load scan presets
- **Per-IP comments** persisted to disk
- **Multi-window** support — each window has its own scan engine (Cmd+N / Ctrl+N)

### Export
- **5 formats** — CSV, TXT, XML, IP list, SQL
- Respects display filter (All / Alive / With Ports)
- Separate "Export Selection" for selected rows only

### Distribution
- **macOS:** Developer ID signed, notarized by Apple, stapled. ~2 MB download.
- **Windows:** Inno Setup installer + framework-dependent portable zip. ~3–5 MB download. Code signing pending.

## Architecture

```
┌─────────────────────────────────────────────┐
│            Native UI (per platform)         │
│  ┌─────────────┐         ┌─────────────┐    │
│  │  SwiftUI    │         │     WPF     │    │
│  │  (macOS)    │         │  (Windows)  │    │
│  └──────┬──────┘         └──────┬──────┘    │
│         └──────────┬─────────────┘           │
│                    │ JSON over C FFI         │
│             ┌──────┴──────┐                  │
│             │ Go Library  │                  │
│             │ (libipscan) │                  │
│             └─────────────┘                  │
└─────────────────────────────────────────────┘
```

The Go core compiles to a platform shared library (`.dylib` / `.dll`) via `cgo`. Each native UI calls it through C function pointers with JSON strings crossing the FFI boundary. All scanning logic is shared across platforms.

## Building

### Prerequisites

- Go 1.26+ (see `libipscan/go.mod`)
- **macOS:** Xcode 26+, `xcodegen` (`brew install xcodegen`)
- **Windows:** .NET 10 SDK, LLVM-MinGW (`winget install MartinStorsjo.LLVM-MinGW.UCRT`), Inno Setup if producing installers (`winget install JRSoftware.InnoSetup`)

### Building on macOS

```bash
make -f Makefile.native all
```

Or manually:

```bash
cd libipscan
CGO_LDFLAGS="-mmacosx-version-min=14.0" CGO_CFLAGS="-mmacosx-version-min=14.0" \
  go build -buildmode=c-shared -o ../MacApp/Bridge/libipscan.dylib
install_name_tool -id "@rpath/libipscan.dylib" ../MacApp/Bridge/libipscan.dylib
cd ../MacApp
xcodegen generate
xcodebuild -scheme GoNetworkScanner -configuration Release build
```

### Building on Windows

Debug build for the current CPU:

```powershell
cd WindowsApp
.\build.ps1                       # debug, matches host arch
.\build.ps1 -Arch x64 -Config Release
.\build.ps1 -Arch arm64 -Config Release
```

Release packages (portable zips + installers, both architectures):

```powershell
cd WindowsApp
.\release.ps1
```

Output lands in `WindowsApp\release\`.

### Tests

```bash
cd libipscan && go test ./... -v -race
```

The Go core has unit tests across IP math, port parsing, config persistence, all exporters, pingers, fetchers, and the scan engine.

## Project Structure

```
libipscan/           # Go core (cross-platform)
  ipnet/             #   IP arithmetic, port parsing
  scanner/           #   Scan engine, state machine
  pinger/            #   TCP, UDP, ICMP, combined, + Windows IcmpSendEcho
  fetcher/           #   12 data fetchers
  feeder/            #   Range, random, file feeders
  exporter/          #   CSV, TXT, XML, IP list, SQL
  config/            #   JSON config with platform paths
  resources/         #   Embedded 38K-entry MAC vendor DB
  main.go            #   C API exports (cgo)

MacApp/              # Swift/SwiftUI macOS UI
WindowsApp/          # WPF/.NET Windows UI

.github/workflows/   # CI: Go tests + app build on macOS and Windows
```

### Config Storage
- **macOS:** `~/Library/Application Support/GoNetworkScanner/config.json`
- **Windows:** `%APPDATA%\GoNetworkScanner\config.json`

## License

**MIT License.** See [LICENSE](LICENSE).

Inspired by Angry IP Scanner by Anton Keks (GPLv2). No code is shared between the two projects — Go Network Scanner is a clean-room implementation.

## Contributing

Pull requests welcome. The Go core (`libipscan/`) is the best place to contribute cross-platform improvements. Platform UIs live in `MacApp/` and `WindowsApp/`.

For bugs, open an issue with your OS version, network setup, and repro steps.

If you want to build a Linux UI (GTK, Qt, Tauri, whatever), the Go core already compiles for Linux — open an issue first to coordinate on approach.
