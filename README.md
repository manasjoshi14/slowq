# SlowQ

SlowQ is a modern macOS utility that prevents accidental quits by requiring users to **hold `Cmd+Q`** for a short delay before an app terminates.

## Acknowledgement

SlowQ is a modern rewrite of the original [SlowQuitApps](https://github.com/dteoh/SlowQuitApps) project by dteoh.

This rewrite was built collaboratively with OpenAI Codex.

## v1 Scope

- Menu bar app
- Global `Cmd+Q` interception via Quartz event tap
- Delay is user-adjustable (default `1000ms`, range `300ms` to `5000ms`)
- Overlay is always shown during hold
- Launch at login toggle
- No app include/exclude list
- No CLI (v1)

## Requirements

- macOS 13+
- Swift 6.2 toolchain
- Accessibility permission for keyboard interception

## Run Locally

```bash
swift run SlowQ
```

Then grant Accessibility access when prompted.

## Local Deploy (App Bundle)

Use the helper script to build and install a local app bundle:

```bash
./scripts/install-local.sh
```

This installs `/Applications/SlowQ.app` from the current source.

## Test

```bash
swift test
```

## Code Quality

Run formatting explicitly when needed:

```bash
./scripts/format.sh
```

Run the full local quality gate:

```bash
./scripts/check.sh
```

`scripts/check.sh` enforces:

- strict swift-format lint (`swift format lint --strict`)
- warnings-as-errors for build and tests
- coverage floor from `.quality/coverage_min.txt` (currently `50.0%`)

## Settings Keys

SlowQ stores settings in `UserDefaults` with namespaced keys:

- `io.github.manas.SlowQ.delayMs`
- `io.github.manas.SlowQ.isProtectionEnabled`
- `io.github.manas.SlowQ.launchAtLogin`

## Notes

- This rewrite starts with fresh settings (no auto-migration from SlowQuitApps).
- Current focus is local build/deploy support (release pipeline deferred).
