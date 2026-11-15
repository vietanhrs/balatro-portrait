# Verification — 2026-11-15

Godot 4.7.2 stable, Compatibility renderer, Linux desktop.

- Core: 1453 assertions, zero failures. Coverage and fixtures documented in `tests/core/README.md`.
- Save: nine checks passed (versioned roundtrip, deterministic continuation, invalid rejection, backup corruption recovery and clearing).
- UI smoke: zero failures at 360×640 and 430×932; card layout, stable selection, controls, overlay/back and presentation fixtures.
- Full UI run: seed 1, 151 legal replay actions, 24 round victories, six fresh UI instances resumed from real disk checkpoints. Every action matched engine output and its autosave. Separate legal low-scoring play reached loss. No injected money/levels/cards/targets.
- Rendered playing/shop/blind screens inspected: readable original card faces, eight-card grid, fixed primary controls, vertically scrolling shop.
- Repository scan found no local machine paths, signing files, SDK/JDK binaries or credential patterns in staged source. This is a bounded hygiene check, not a security certification.

The full-run test calls UI handlers; it does not simulate a human touchscreen session. Layout fixtures do not prove every interactive path. No human playthrough or broad balance/accessibility certification is claimed.

Android SDK license approval is pending. No project APK has been built, signed, installed, or verified on an emulator. Android back/notch/lifecycle/offline runtime gates remain open. Source publication is not Android completion.
