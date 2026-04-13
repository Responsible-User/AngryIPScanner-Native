# Angry IP Scanner (Native)

A fast and friendly network scanner, rewritten as a native macOS app with a cross-platform Go core. This shares no code with the original Angry IP Scanner.

This is a ground-up rewrite of [Angry IP Scanner](https://angryip.org/) — the Java/SWT codebase has been replaced with **Go** (scanning engine) and **Swift/SwiftUI** (macOS UI). No Java, no JVM.

There will be native Windows and Linux apps at a later date, as I work on making all the apps feature complete with the old Java version,

## Download

Grab the latest signed and notarized build from [Releases](../../releases).

**macOS 14 (Sonoma) or later required.** Apple Silicon and Intel supported.

## Features

- **Network scanning** — ping sweep with TCP, UDP, ICMP, or combined pingers
- **12 data fetchers** — IP, Ping, TTL, Hostname, Ports, Filtered Ports, MAC Address, MAC Vendor, Web detect, NetBIOS, Packet Loss, Comments
- **3 input modes** — IP range, CIDR (auto-detected from your network), file import
- **5 export formats** — CSV, TXT, XML, IP list, SQL
- **Native macOS UI** — SwiftUI with dark mode, Retina, proper menu bar, Preferences window
- **38,000+ MAC vendor database** embedded in the binary
- **CIDR auto-detection** — detects your local subnet and prefix length on launch
- **Result filtering** — show all, alive only, or hosts with open ports
- **Sortable columns** — click any column header
- **Code signed and notarized** by Apple

## Architecture

```
┌──────────────────────────────────────┐
│         SwiftUI (macOS UI)           │
│  MainWindow, ResultTable, Prefs...   │
└──────────────┬───────────────────────┘
               │ JSON over C FFI
┌──────────────┴───────────────────────┐
│          Go Core (libipscan)         │
│  Scanner engine, pingers, fetchers,  │
│  feeders, exporters, config          │
└──────────────────────────────────────┘
```

The Go core compiles to a `.dylib` shared library via `cgo`. The Swift UI calls it through C function pointers, with JSON strings crossing the FFI boundary. This architecture allows future Windows/Linux UIs to share the same Go core.

## Building

### Prerequisites

- **Go** 1.21+ (`brew install go`)
- **Xcode** 16+ with command line tools
- **xcodegen** (`brew install xcodegen`)

### Build

```bash
# Build Go shared library
cd libipscan
go build -buildmode=c-shared -o ../AngryIPScanner/Bridge/libipscan.dylib
install_name_tool -id "@rpath/libipscan.dylib" ../AngryIPScanner/Bridge/libipscan.dylib
cd ..

# Generate Xcode project and build
cd AngryIPScanner
xcodegen generate
xcodebuild -scheme AngryIPScanner -configuration Release build
```

Or use the Makefile:

```bash
make -f Makefile.native all
```

### Run tests

```bash
cd libipscan && go test ./...
```

## Project Structure

```
libipscan/           # Go core (cross-platform)
  ipnet/             #   IP arithmetic, port parsing
  scanner/           #   Scan engine, state machine, results
  pinger/            #   TCP, UDP, ICMP, combined pingers
  fetcher/           #   12 data fetchers
  feeder/            #   Range, random, file feeders
  exporter/          #   CSV, TXT, XML, IP list, SQL
  config/            #   JSON config persistence
  resources/         #   Embedded MAC vendor database
  main.go            #   C API exports (cgo)

AngryIPScanner/      # Swift/SwiftUI (macOS UI)
  App/               #   App entry point, menu commands
  Bridge/            #   C FFI wrapper, Codable models
  Views/             #   SwiftUI views and dialogs
  Resources/         #   Asset catalog (app icon)

legacy/              # Original Java/SWT source (reference only)
```

## License

This project is based on [Angry IP Scanner](https://github.com/angryip/ipscan) by Anton Keks, licensed under the **GNU General Public License v2 (GPLv2)**.

As a derivative work, this rewrite is also licensed under **GPLv2**. See [LICENSE](LICENSE) for the full text.

### Attribution

- Original Angry IP Scanner by [Anton Keks](https://github.com/angryip/ipscan) and contributors
- MAC vendor database (IEEE OUI) from the original project
- App icon from the original project

## Contributing

Pull requests welcome. The Go core is the best place to contribute cross-platform improvements. The Swift UI layer is macOS-specific.

For bugs, open an issue with your macOS version, network setup, and steps to reproduce.
