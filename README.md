# Go Network Scanner

[![CI](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)

A fast, native network scanner for macOS (and soon Windows/Linux). Written from the ground up in **Go** (scanning engine) and **Swift/SwiftUI** (macOS UI). No Java, no JVM.

Inspired by [Angry IP Scanner](https://angryip.org). This project shares no source code with the original — it's a fresh implementation with an independent design, MIT-licensed, and aiming for Mac App Store distribution.

## Download

Signed, notarized macOS builds: [Releases](../../releases).

**Requirements:** macOS 14 (Sonoma) or later. Apple Silicon and Intel.

## Features

### Scanning
- Ping sweep with **TCP, UDP, ICMP, or combined** pingers
- **12 fetchers** — IP, Ping, TTL, Hostname, Ports, Filtered Ports, MAC Address, MAC Vendor, Web detect, NetBIOS, Packet Loss, Comments
- **3 input modes** — IP Range, CIDR (auto-detected), File import
- **CIDR auto-detection** — reads your network adapter on launch
- **Real-time results** — IPs appear as scanning starts, update when complete

### UI
- **Native SwiftUI** — dark mode, Retina, menu bar, Settings scene
- **Independent tabs** — each window has its own scan engine (Cmd+N)
- **Sortable columns** with sort arrows
- **Find** (Cmd+F) with wrap-around search
- **Go To** next/previous alive host with auto-scroll
- **Double-click** to open details
- **Right-click menu** — Details, Copy, Open in Browser/SSH/Ping/Traceroute, Rescan, Delete
- **Favorites** — save and load scan presets
- **Per-IP comments** persisted to disk

### Export
- **5 formats** — CSV, TXT, XML, IP list, SQL
- Format picker in save dialog
- Respects display filter (All / Alive / With Ports)

### Distribution
- Code signed with Developer ID, notarized by Apple, stapled
- 2.3 MB download
- **MIT licensed** — suitable for Mac App Store submission

## Architecture

```
┌──────────────────────────────────────────┐
│           Native UI (per platform)       │
│  ┌──────────┐  ┌──────────┐             │
│  │ SwiftUI  │  │   WPF    │             │
│  │  (Mac)   │  │ (Windows)│             │
│  └────┬─────┘  └────┬─────┘             │
│       └──────┬───────┘                   │
│              │ JSON over C FFI           │
│       ┌──────┴───────┐                   │
│       │  Go Library  │                   │
│       │ (libipscan)  │                   │
│       └──────────────┘                   │
└──────────────────────────────────────────┘
```

The Go core compiles to a platform shared library (`.dylib` / `.dll` / `.so`) via `cgo`. Each native UI calls it through C function pointers with JSON strings crossing the FFI boundary. All scanning logic is shared across platforms.

## Building

### Prerequisites
- Go 1.22+ (`brew install go`)
- Xcode 26+ (for macOS)
- xcodegen (`brew install xcodegen`)

### macOS

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

### Windows

```powershell
# Requires Go + LLVM (ARM64) or TDM-GCC (x64)
cd libipscan
$env:CGO_ENABLED="1"
go build -buildmode=c-shared -o ..\WindowsApp\GoNetworkScanner\libipscan.dll

cd ..\WindowsApp
dotnet build GoNetworkScanner\GoNetworkScanner.csproj -c Release
```

### Tests

```bash
cd libipscan && go test ./... -v -race
```

44 tests across 7 packages covering IP math, port parsing, config persistence, all exporters, pingers, fetchers, and the scan engine.

## Project Structure

```
libipscan/           # Go core (cross-platform)
  ipnet/             #   IP arithmetic, port parsing
  scanner/           #   Scan engine, state machine
  pinger/            #   TCP, UDP, ICMP, combined
  fetcher/           #   12 data fetchers
  feeder/            #   Range, random, file feeders
  exporter/          #   CSV, TXT, XML, IP list, SQL
  config/            #   JSON config with platform paths
  resources/         #   Embedded 38K-entry MAC vendor DB
  main.go            #   C API exports (cgo)

MacApp/              # Swift/SwiftUI macOS UI
WindowsApp/          # WPF/.NET Windows UI (in progress)

.github/workflows/   # CI: Go tests + app build on macOS/Linux/Windows
```

### Config Storage
- **macOS:** `~/Library/Application Support/GoNetworkScanner/config.json`
- **Windows:** `%APPDATA%\GoNetworkScanner\config.json`
- **Linux:** `~/.config/GoNetworkScanner/config.json`

## License

**MIT License.** See [LICENSE](LICENSE).

Inspired by Angry IP Scanner by Anton Keks (GPLv2). No code is shared between the two projects — Go Network Scanner is a clean-room implementation.

## Contributing

Pull requests welcome. The Go core (`libipscan/`) is the best place to contribute cross-platform improvements. Platform UIs live in `MacApp/` and `WindowsApp/`.

For bugs, open an issue with your OS version, network setup, and repro steps.
