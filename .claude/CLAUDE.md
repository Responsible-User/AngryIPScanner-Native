# CLAUDE.md — Go Network Scanner

Project-specific guidance for Claude. Keep this file current: when you
land a non-obvious change (new architectural decision, tricky gotcha,
changed default, new command, branch workflow shift), add a short entry
to the relevant section in the same commit.

---

## What this project is

Go Network Scanner — a native desktop network scanner inspired by Angry
IP Scanner. MIT-licensed, independent project (not a fork of the Java
codebase it draws ideas from). Bundle ID `toys.eat.gonetscanner`.
Developer ID team `LXEJ8DA986`. First public release was `v1.0.0`.

The Java legacy sits under `/legacy` (gitignored) for reference only —
do not modify it.

## Architecture

```
libipscan (Go)  →  C-compatible shared library via cgo
    ├── darwin  →  libipscan.dylib  →  SwiftUI app (MacApp/)
    ├── windows →  libipscan.dll    →  WPF app (WindowsApp/)
    └── linux   →  libipscan.so     →  (planned) LinuxApp/
```

The Go core owns scanning, pingers, fetchers, feeders, config, and
exporters. Each native UI is a thin client that marshals JSON across
the FFI boundary.

### Data crosses the FFI as JSON strings
Chosen for debuggability and schema flexibility over raw performance.
At ~65K result rows with ~200 bytes of JSON each, total cost is trivial
compared to network I/O.

### Callback threading
Go callbacks fire from arbitrary goroutines. Swift uses a
`CallbackRouter` + `DispatchQueue.main.async` + `MainActor.assumeIsolated`
to land on the main actor. C# uses `Dispatcher.BeginInvoke`. **Never**
update observable/UI state directly from the callback thread.

### Per-window bridges, shared config on disk
Each window creates its own `IPScanBridge` (own Go handle, own
scan state). Preferences are global — the Go core loads config from
disk on `ipscan_new`, saves on every `ipscan_set_config`, and reloads
on every `ipscan_start_scan` so changes made in a Preferences window
are visible to the main-window bridge. Don't try to share bridges
between windows; share state via the config file.

## Branch layout

| Branch          | Purpose                                       |
|-----------------|-----------------------------------------------|
| `master`        | Integration branch. Releases tagged from here. |
| `mac-native`    | Mac-focused work. Merge to master for release. |
| `windows-native`| Windows WPF app work.                          |
| `linux-native`  | (Placeholder) Linux UI work.                   |

Flow: work on the platform branch, merge `--no-ff` to master, then
merge master back to the sibling platform branches to keep them in
sync. See commit history for the convention.

## CI (`.github/workflows/ci.yml`)

- **Go tests + vet** run on every branch across macOS/Ubuntu/Windows.
  The Go core is shared — regressions must be caught regardless of
  which branch is being pushed.
- **UI builds gate by branch**: `mac-build` on `master` + `mac-native`,
  `windows-build` on `master` + `windows-native`, `linux-build` on
  `master` + `linux-native`. Pull requests to master run all three.
- **Never put platform-specific syscalls in core Go files**. If you
  need `syscall.Dup2` / `SetStdHandle` / etc., put them in
  `*_darwin.go` / `*_windows.go` with build tags, or just drop the
  feature. `syscall.Dup2` in particular does not exist on Windows or
  `linux/arm64`.

## Build / test commands

```sh
# Go: build the shared library for macOS (also builds the header)
make -f Makefile.native go

# Go: run all tests (must pass before committing)
make -f Makefile.native test
# or: cd libipscan && go test ./... -race -count=1

# Full Mac Debug build
make -f Makefile.native swift

# Windows build (run on Windows)
make -f Makefile.native windows

# Regenerate Xcode project from project.yml (requires xcodegen)
make -f Makefile.native xcode
```

## Release flow (macOS, current)

1. Land changes on `mac-native`, merge to `master`.
2. `make -f Makefile.native go` then Release build via xcodebuild.
3. **Re-sign with clean entitlements** before notarizing — Xcode
   injects `get-task-allow` even with `CODE_SIGN_INJECT_BASE_ENTITLEMENTS:
   NO`. Use `codesign --force --deep --options runtime --timestamp
   --entitlements GoNetworkScanner.entitlements --sign "Developer ID
   Application: ..."`.
4. `ditto -c -k --keepParent` into a zip, `xcrun notarytool submit
   --keychain-profile GoNetScanner --wait`.
5. `xcrun stapler staple` the `.app`, re-zip for distribution.
6. `git tag -a vX.Y.Z`, push tag, `gh release create --repo
   Responsible-User/GoNetworkScanner` (the local `gh` CLI defaults to
   the legacy upstream — always pass `--repo`).

## Non-obvious gotchas

### Go core

- **Config persistence**: `ipscan_new` loads from disk if no JSON passed;
  `ipscan_set_config` writes to disk on every change;
  `ipscan_start_scan` reloads from disk to pick up changes from sibling
  bridges. Don't regress this — every scan before this was quietly
  using hard-coded defaults.
- **`configMu sync.RWMutex`** guards all access to `inst.config`. Scan
  workers never touch the shared struct — `ipscan_start_scan` takes a
  snapshot (including a copy of the comments map) under RLock and
  passes that to the engine.
- **Adaptive port timeout**: hard-coded 500 ms floor inside
  `getAdaptedTimeout` overrides the user's `minPortTimeout`. Users who
  set `minPortTimeout=100` (from old configs) still get reasonable
  behavior. Multiplier is `ping × 10`, not `× 3` — slower services
  like xrdp were missing the window.
- **Port scan doubles as a reachability probe**: `PortsFetcher` and
  `FilteredPortsFetcher` implement `scanner.AbortBypasser` so they run
  even when the pinger classifies a host as dead. A host that only
  exposes (say) RDP gets upgraded from dead → `with_ports`.
- **TCP probe ports** include 3389, 445, 8080 in addition to
  80/443/22/139/7. Ordered by hit rate.
- **File feeder regex** extracts IPv4, IPv6, hostnames, and `IP:port`
  annotations from arbitrary text. `useRequestedPorts=true` merges
  those `:port` annotations into the per-host scan list.
- **Crash-log stderr redirection is intentionally absent**. It would
  need `syscall.Dup2` (Unix) / `SetStdHandle` (Windows) / `Dup3` (linux
  arm64) — not worth the platform surface. If a panic case appears
  again, add the feature *per-platform* with build tags.

### macOS / Swift

- **Live Activities are iOS-only** in the macOS 26 SDK. `ActivityKit`
  imports but `ActivityAttributes` is marked unavailable. Use a menu
  bar `NSStatusItem` if you want "visible while app is hidden" UI.
- **SwiftUI `Table` row double-click** doesn't have a native API on
  macOS 14. `NSTableViewDoubleClickInstaller` walks the view hierarchy
  and installs a `doubleAction` on the underlying `NSTableView`. Same
  trick (`scrollRowToVisible`) for programmatic scrolling.
- **Settings scene uses its own bridge instance**. That's why config
  persistence to disk matters — the Preferences bridge and the main
  window bridge are different Go instances.
- **Each `WindowGroup` window gets its own `@State var bridge =
  IPScanBridge()`** via `IndependentScanWindow`. Don't hoist the
  bridge to app level.
- **`ExportFormatHelper` must be `@MainActor @objc`** — Xcode 16.4's
  strict concurrency flags it otherwise.
- **`CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO` is not enough** — Xcode
  still injects `get-task-allow` into Release binaries. Re-sign
  post-build with the clean entitlements file.

### Windows / C#

- **JSON key for selected fetchers is `selectedFetchers`**, matching
  Go's `json:"selectedFetchers,omitempty"`. The old `selectedFetcherIDs`
  silently dropped every round-trip.
- **Config dir via `ipscan_set_config_dir(%AppData%\GoNetworkScanner)`**
  must be called before `ipscan_new`. See `IPScanBridge` ctor.
- **WPF `DataGridTextColumn` doesn't have a `ToolTip` property** —
  attach tooltips via `ElementStyle` on cells. Header tooltips require
  a `HeaderStyle` targeting `DataGridColumnHeader`.
- **P/Invoke strings are ANSI, Cdecl**. See `NativeMethods.cs` for the
  pattern; don't mix UTF-16 in.

## Memory system

I have a persistent memory directory at
`~/.claude/projects/-Users-jacobbraun-ipscan-native/memory/`. Save
project/user/feedback entries there, not in this file. This file is
for anyone (human or Claude) reading the repo cold; the memory dir
is for continuity across sessions.

## Maintenance contract

When you make a change that affects anything in the "Non-obvious
gotchas" section — or introduces a new gotcha, build step, or branch
convention — update this file in the same commit. Treat stale entries
as bugs: if a gotcha no longer applies, delete it rather than leaving
it to mislead future-you.
