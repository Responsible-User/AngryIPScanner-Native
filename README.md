# Angry IP Scanner (Native)

[![CI](../../actions/workflows/ci.yml/badge.svg)](../../actions/workflows/ci.yml)

A fast and friendly network scanner, rewritten as a native app with a cross-platform Go core. This shares no code with the original Angry IP Scanner.

The Java/SWT codebase has been replaced with **Go** (scanning engine) and **Swift/SwiftUI** (macOS UI). No Java, no JVM. A native Windows version (WPF/.NET) is also in progress.

## Download

Grab the latest signed and notarized build from [Releases](../../releases).

**macOS 14 (Sonoma) or later required.** Apple Silicon and Intel supported.  
**2.3 MB** total (vs ~50 MB for the Java version with bundled JRE).

## Features

### Scanning
- **Ping sweep** with TCP, UDP, ICMP, or combined pingers
- **12 data fetchers** — IP, Ping, TTL, Hostname, Ports, Filtered Ports, MAC Address, MAC Vendor, Web detect, NetBIOS, Packet Loss, Comments
- **3 input modes** — IP range, CIDR (auto-detected), file import
- **CIDR auto-detection** — reads your network adapter's IP and prefix length on launch
- **Real-time results** — IPs appear immediately as scanning starts, update when complete
- **IPv6 compatible** — address formatting uses `net.JoinHostPort` throughout

### User Interface
- **Native macOS UI** — SwiftUI with dark mode, Retina, proper menu bar
- **Independent tabs** — each window/tab has its own scan engine (Cmd+N for new tab)
- **Tab titles** show the scan range and progress percentage
- **9 sortable columns** — click any column header for sort arrows
- **Result filtering** — All / Alive Only / With Ports Only (status bar + View menu)
- **Find** (Cmd+F) — search across all result values with wrap-around
- **Go To** next/previous alive host (Cmd+Opt+Down/Up) with auto-scroll
- **Double-click** any row to open details
- **Right-click context menu** — Show Details, Copy IP, Copy All, Open in Browser/SSH/Ping/Traceroute, Rescan, Delete
- **Preferences** — Scanning (threads, pinger, timeouts), Ports (common port presets + custom), Display
- **Favorites** — save and load scan presets
- **Per-IP comments** — editable in details window, persisted to disk

### Export
- **5 formats** — CSV, TXT, XML, IP list, SQL
- **Format picker** in save dialog with live filename extension update
- **Filtered export** — exports only what's visible (respects All/Alive/With Ports filter)

### Distribution
- **Code signed** with Developer ID certificate
- **Notarized** by Apple with stapled ticket
- **Gatekeeper approved** — no security warnings on download
- **38,000+ MAC vendor database** embedded in the binary

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
│  Scanning │ Pingers │ Fetchers │ Export  │
└──────────────────────────────────────────┘
```

The Go core compiles to a platform-specific shared library (`.dylib` / `.dll` / `.so`) via `cgo`. Each native UI calls it through C function pointers with JSON strings crossing the FFI boundary. The scanning engine, all fetchers, pingers, exporters, and configuration are shared across platforms.

## Building

### Prerequisites

- **Go** 1.22+ (`brew install go`)
- **Xcode** 26+ with command line tools
- **xcodegen** (`brew install xcodegen`)

### macOS

```bash
# Build Go shared library (targeting macOS 14+)
cd libipscan
CGO_LDFLAGS="-mmacosx-version-min=14.0" CGO_CFLAGS="-mmacosx-version-min=14.0" \
  go build -buildmode=c-shared -o ../MacApp/Bridge/libipscan.dylib
install_name_tool -id "@rpath/libipscan.dylib" ../MacApp/Bridge/libipscan.dylib
cd ..

# Generate Xcode project and build
cd MacApp
xcodegen generate
xcodebuild -scheme AngryIPScanner -configuration Release build
```

Or use the Makefile:

```bash
make -f Makefile.native all    # Build Go + Swift
make -f Makefile.native test   # Run Go tests
```

### Windows

```powershell
# Requires Go + GCC (LLVM/Clang for ARM64, TDM-GCC for x64)
cd libipscan
$env:CGO_ENABLED="1"
go build -buildmode=c-shared -o ..\WindowsApp\AngryIPScanner\libipscan.dll

# Build WPF app
cd ..\WindowsApp
dotnet build AngryIPScanner\AngryIPScanner.csproj -c Release
```

### Run tests

```bash
cd libipscan && go test ./... -v -race
```

44 tests across 7 packages covering IP math, port parsing, config persistence, all exporters, pingers, fetchers, and the scan engine.

## Project Structure

```
libipscan/           # Go core (cross-platform, ~4,000 LOC)
  ipnet/             #   IP arithmetic, port parsing
  scanner/           #   Scan engine, state machine, results
  pinger/            #   TCP, UDP, ICMP, combined pingers
  fetcher/           #   12 data fetchers + MAC vendor lookup
  feeder/            #   Range, random, file feeders
  exporter/          #   CSV, TXT, XML, IP list, SQL
  config/            #   JSON config with platform-specific paths
  resources/         #   Embedded MAC vendor database (38K entries)
  main.go            #   C API exports (cgo)

MacApp/              # Swift/SwiftUI macOS UI (~1,500 LOC)
  App/               #   App entry point, menu commands
  Bridge/            #   C FFI wrapper, Codable models
  Views/             #   SwiftUI views and dialogs
  Resources/         #   Asset catalog (app icon from SVG)

WindowsApp/          # WPF/.NET Windows UI (in progress)

.github/workflows/   # CI: Go tests on macOS/Ubuntu/Windows + app build
```

### Config Storage

- **macOS:** `~/Library/Application Support/AngryIPScanner/config.json`
- **Windows:** `%APPDATA%\AngryIPScanner\config.json`
- **Linux:** `~/.config/AngryIPScanner/config.json`

## License

This project is inspired by [Angry IP Scanner](https://github.com/angryip/ipscan) by Anton Keks. Licensed under the **GNU General Public License v2 (GPLv2)**. See [LICENSE](LICENSE) for the full text.

### Attribution

- Original concept from [Angry IP Scanner](https://angryip.org/) by Anton Keks and contributors
- MAC vendor database (IEEE OUI)
- App icon design from the original project

## Contributing

Pull requests welcome. The Go core (`libipscan/`) is the best place to contribute cross-platform improvements. Platform UIs are in `MacApp/` and `WindowsApp/`.

For bugs, open an issue with your OS version, network setup, and steps to reproduce.
