# Motion acceptance — 0.3.0-alpha

Status: integrated candidate passed fresh regression suites and isolated Android native checks; parent visual/publication gate remains pending. See docs/MOTION_VERIFICATION.md.

## Integration lock and regression gate
Only the coordinator may release sole integration ownership. Do not run Godot editor imports/export while UI/art/core writers are active. Preserve the existing v2 run schema and signer. Run tools/run-checks.sh under its isolated HOME after integration; preserve the 179-action Practice replay, 24 wins, seven fresh resumes, legal loss and disk-equals-engine assertions in tools/check_ui_run.gd. If UI animation is asynchronous, add bounded settling against its actual busy API, not sleeps that suppress state checks. Do not replace real replay with constructed winning fixtures.

## Required visual/native evidence
Capture at 360x640 and 430x932 logical sizes; native emulator at corresponding portrait sizes. Seed 531, Practice, ordinary legal actions. Keep a video and timestamped contact sheets, not only screenshots/test counts. Use tools/capture-motion.sh android (explicit isolated SERIAL/ADB) or desktop (verified game-only X11 region). Start recording before the triggering tap from a separate terminal, record 30–60 seconds, review the entire video. Synthetic filter selftest is not game evidence.

Record timestamp, action, observed result and pass/fail for:
- Home: five requested primary buttons, seed controls, no clipped labels; check each destination and Back. Do not infer old profile history.
- Deal: cards visibly travel from deck into one persistent table row, staggered, correct rank and suit. Table/chrome never replaced with a separate scoring screen.
- Selection: eight cards remain in one row; each exposed hit target selects only intended card; maximum five, deselect, ordering, raised selection and no clipping. Test narrow and tall screens with actual Android taps.
- Discard: selected cards leave; unselected nodes/cards remain visually anchored; replacement cards arrive from deck. Counter decreases once, no duplicate action under rapid taps.
- Play: selected cards move to play area; per-card wiggle/highlight tracks actual scoring IDs; chips and mult progress in causal order, multiplication then round score; cleanup and refill follow. No teleporting entire hand or abrupt full-screen rebuild. Winning/losing paths do not display invalid gameplay controls.
- Empty passive/consumable rails remain designed, visible and do not show fake owned items.
- Texture: background/art moves subtly over at least five seconds; text stays readable and drift does not move tap targets. Reduced motion suppresses motion while preserving values/state.
- Interrupt: Back, background and force-stop during deal/play/discard; resume latest committed result without double score, loss, stuck lock or spending twice.
- Settings/profile: change setting, force-stop/relaunch, verify persistence; old v2 run starts with truthful new-profile history, never fabricated past stats.

## Android upgrade gate
Use prior 0.2 APK as BASELINE_APK with tools/export-android-review.sh. Confirm package org.vietanhrs.velvetcircuit, versionCode3, 0.3.0-alpha, ARM64+x86_64, same SHA256 signing certificate, no Internet permission, no test/tool/signing/private material in APK. Never regenerate keystore. Install -r only on the explicitly isolated emulator; never uninstall/pm clear. Before upgrade capture run.save, backup and any existing profile/settings via run-as and hashes. Compare after install before launch; after launch/resume compare decoded v2 state and verify new settings defaults without resetting run. Use separate deliberate new run for motion capture only after retaining upgrade evidence.

Prior emulator is currently disconnected; no device results exist for this version. Physical ARM64/notches remain untested unless separately authorized.

## Initial core schema review (before worker changes)
core/game_engine.gd SELECT_BLIND emitted only action; DISCARD emitted only action; PLAY emitted scoring timeline, round_total, score, optional growth/receipt, action. No deal/discard/move/cleanup/refill IDs or snapshots were emitted. Core _refill also ran before win/loss transition. UI must snapshot pre-action hand/card metadata and diff the committed hand, or core must emit explicit ordered presentation events. Do not animate based only on final state or infer scored cards from all selected IDs. Scoring events already carry source metadata, target_id and before/after chips/mult; the legacy score event duplicates score_total semantically and must not double-apply totals. Animation sequencing is presentation, never a second dispatch/save.

## Publication
Private APK/video retention only. Parent must visually review evidence, regressions and limitations before any tag/release. Source push authority does not authorize release publication.
