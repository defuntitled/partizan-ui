# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## State of the repo

No code yet — only the spec. `spec/partizan_android_spec.md` (in Russian) is the source of truth for the Android/Flutter client: architecture, FFI surface, split-tunneling rules, storage, screens, and the commit-by-commit plan A01–A11 with per-commit DoD and test cases. `spec/partizan-ui-concept.png` is the UI concept. Implement commits in plan order and check the relevant spec section before writing code.

The tunnel core lives in the sibling repo `../partizan` (Rust workspace: `proto`, `transport`, `client-core`, `socks5`, `server`, `client-openwrt`). Its `CLAUDE.md`, `spec/partizan_spec.md` (protocol, formats, constants) and `spec/partizan — decompozition.md` (plan C01–C26) still apply; the A-plan continues that numbering and inherits its conventions. The Rust parts of the A-plan live in that workspace: `tun` (A01–A02) is `../partizan/crates/tun`, and `client-ffi` goes next to it. Run the checks from `../partizan/CLAUDE.md` there; locally BoringSSL bindgen needs `BINDGEN_EXTRA_CLANG_ARGS=-I/usr/lib/gcc/x86_64-linux-gnu/15/include`.

## Architecture (from the spec)

```
Flutter UI (Dart)          screens, state (riverpod/bloc), profiles (drift + flutter_secure_storage)
  │ method channel
Kotlin: VpnService + bridge  VPN lifecycle, TUN fd, foreground notification, TileService, App Widget
  │ UniFFI
client-ffi (Rust, new)     start/stop/status/check_uri/set_diagnostics/stack_metrics, StatusListener
tun (Rust, new)            TUN fd → smoltcp userspace stack → TcpRequest/UdpPacket; split filter; metrics
client-core → transport → proto   unchanged, shared with server and router
```

- Nothing Android-specific goes into `client-core` or below. `tun` is a traffic source parallel to `socks5`; `socks5` is not used on Android.
- Own `smoltcp` stack, never a tun2socks — no local listening SOCKS5 port on the device (it unmasks the client to on-device scanners).
- Dart layer must stay platform-independent so it can be reused for desktop (Linux/Windows/macOS). Quick Settings tile and home widget are native Android, not Flutter.
- Single source of truth for state is `VpnState` from the core (`Idle → Connecting → Connected`, `Reconnecting`, `Revoked` with no reconnect, `Error`); app, notification, tile and widget all mirror it.
- Split tunneling is by IP/CIDR only, modes Include/Exclude, applied as `VpnService` routes (`addRoute`/`excludeRoute` on Android 13+, range splitting on older) plus a second-line filter in `tun`. DNS (53 UDP/TCP, 853) always goes into the tunnel regardless of mode. Per-domain and per-app splitting are out of scope entirely — don't add them to the data model.
- Loop prevention is mandatory: `addDisallowedApplication(self)` or `VpnService.protect(fd)`.
- Stack diagnostics (profiling, verbose stack log) are toggled at runtime via `client-ffi`; when off, counters are not computed at all (zero overhead).
- Only ABI: `arm64-v8a` (`aarch64-linux-android` via `cargo-ndk`); keep the build structure open to more ABIs. BoringSSL (`transport` feature `chrome`) needs cmake, a C/C++ compiler and libclang, same as on Linux.

## Conventions

- Conventional Commits; commit body names the plan number (`A07`) and spec sections implemented. Every commit builds and passes CI on its own.
- Test names embed the case ID: e.g. `a09_t6_...`. Manual cases («ручной») record their result in the commit message.
- If a commit changes behavior described in the spec, update the spec in the same commit.
- `#![forbid(unsafe_code)]` in new pure crates where applicable.

## Security rules

- Token / full `partizan://…` URI lives only in Android Keystore (`flutter_secure_storage`), never in SQLite, plain settings, or backups (`allowBackup=false`, secure storage excluded from auto-backup). It is read only at start and passed to the core inside the URI.
- Never log tokens; destination addresses only at `debug` level and only locally. Log/metrics exports must contain no tokens.
- `insecure=1` only in debug builds; SPKI pin is verified by the core.
