# Verification — 2026-11-15

Godot 4.7.2 stable, Compatibility renderer, Linux desktop.

- Core: 1453 assertions, zero failures. Coverage and fixtures documented in `tests/core/README.md`.
- Save: nine checks passed (versioned roundtrip, deterministic continuation, invalid rejection, backup corruption recovery and clearing).
- UI smoke: zero failures at 360×640 and 430×932; card layout, stable selection, controls, overlay/back and presentation fixtures.
- Full UI run: seed 1, 151 legal replay actions, 24 round victories, six fresh UI instances resumed from real disk checkpoints. Every action matched engine output and its autosave. Separate legal low-scoring play reached loss. No injected money/levels/cards/targets.
- Rendered playing/shop/blind screens inspected: readable original card faces, eight-card grid, fixed primary controls, vertically scrolling shop.
- Repository scan found no local machine paths, signing files, SDK/JDK binaries or credential patterns in staged source. This is a bounded hygiene check, not a security certification.

The full-run test calls UI handlers; it does not simulate a human touchscreen session. Layout fixtures do not prove every interactive path. No human playthrough or broad balance/accessibility certification is claimed.

Android debug APK exported and verified with APK Signature v2/v3, portrait manifest, package org.vietanhrs.velvetcircuit, ARM64 and x86_64 libraries, min API24 / target API36. AOSP API35 x86_64 emulator (720×1280, KVM, host Intel graphics) installed and launched the APK. Injected touch selected cards, discarded, played a flush to score 284 against 150, and bought North Star ($10 → $6). Back closes help, then opens menu after fixing SceneTree.quit_on_go_back. Background/foreground and force-stop/relaunch preserved the exact save checksum; Resume restored shop and owned modifier. Wi-Fi/mobile data disabled; APK has no Internet permission. Final runtime log had no Godot script errors or AndroidRuntime crash.

Initial software SwiftShader failed shader uniform limits; host graphics resolved rendering without gameplay changes. This is one emulator smoke, not physical ARM64 certification or a full Android 24-round run. Full 24-round replay remains desktop automated coverage. Debug signing is developmental, not a production signing identity.
