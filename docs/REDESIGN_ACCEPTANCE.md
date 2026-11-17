# v0.2.0-alpha acceptance checklist

Parent visual review accepted the redesign on 2026-11-17 and approved source publication. New verification is recorded in VERIFICATION.md; APK prerelease publication remains separate. v0.1 evidence must not be attributed to this version.

## Required evidence before publication
- Rendered route, idle/selected hand, intermediate scoring, receipt, shop detail, pack and targeting at 360×640 and 430×932. Inspect every image; measure critical hit areas ≥48×48 logical pixels, no clipped selection or table scrolling, readable text and distinct score surfaces. Parent visual review is mandatory.
- Core timeline order/+ versus ×, preview purity, exact-target final-hand win, exactly-once cashout, skip/boss rules, tag/voucher persistence, reroll invariants, targeted cancellation, unique deck IDs, full inventory pack handling, cashout/pack save boundaries.
- Separate fixed-seed Practice and Standard simulations with sample sizes and honest balance limits.
- Legacy save migrates to Practice without changing cards, money or RNG; original v1 archive retained. Failed migration must present recovery/reset confirmation, never silently start over. Backup restoration and corruption refusal tested in isolated user directories.
- Actual new APK, same development signer as v0.1, incremented version code, ARM64/x86_64, portrait, no Internet permission. Upgrade using adb install -r without clearing app data. No physical device installs.
- Isolated emulator touch select/play/discard, visible scoring, receipt/cashout, shop, pack choice, targeting/cancel, Android Back, offline, background and force-stop/resume. Hash save before/after restart; compare pack options and no duplicate payout. Inspect logcat for crashes/script errors.

`tools/export-android-review.sh` requires the existing approved TOOLING, an external OUT directory and BASELINE_APK. It reuses isolated signing configuration, verifies certificate continuity and does not install or publish. Do not regenerate the debug keystore.

No commit, push, tag, release upload or publication until the parent approves rendered evidence and integration findings.
