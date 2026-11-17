# Portrait UI v3 — persistent table

Entry: scenes/main.tscn → ui/main.gd; raster-backed ui/table_card.gd; device-local ui/profile_store.gd; ui/felt.gdshader.

Main menu: Play / contextual Resume / Settings / Statistics / Collections / Quit. Play opens mode and unchecked Seeded checkbox. Only checked exposes editable required seed. Randomized RNG starts; entered seed delegates unchanged to engine. Profile tracks only observed local actions, never fabricated historic totals. Collections retain encountered shop, pack and owned items. Settings persist independently of checkpoint.

One overlapping row, exposed rank/suit indices, reverse draw-order pointer hit test, selection lift, separate Rank/Suit controls and automatic post-draw sorting. Empty rails create no placeholders. Compact round tickets expose score; rules/reward behind details.

PLAY/DISCARD dispatch once and persist before visuals. Deep before/after snapshots drive existing card nodes on a persistent table: stage flight, source wiggle, only changed chips/mult tile tween, multiplication, score flight/count-up, used-pile sweep and staggered replacement draw. Selection/sort never rebuild. Skip/Back kill tweens and invalidate async token, reconcile committed hand without dispatch. Terminal screens appear only after presentation. Reduced motion reconciles synchronously and disables background drift. Initial deal is staggered and locked.

Raster contract: assets/v3/README.md. Uses background, card fronts/backs, logo, panel/button skins, item family/id paths. Original raster assets; indices are live text. Background uses two slowly drifting same-tone texture samples.

Verification: tests/ui/v3_motion.gd (actual engine motion, save-before-animation, single dispatch, stable table/card identity, tween displacement, snapshots, sorting, selection, seeds); v3_screens.gd (360×640 and 430×932 bounds/rendering); smoke.gd; redesign_transactions.gd (updated to finish initial deal). Logs and sequential motion frames: tests/ui/v3-*. Desktop proof is not Android proof.

Integration: no core/platform/project/assets changes, no commits. Parent must export/package assets and rerun Android lifecycle/performance acceptance. Separate profile/run files mean process death between saves can undercount local statistics; gameplay checkpoint remains authoritative. No solver/balance changes. UI-owned files released at final handoff.

Additional test: v3_event_tiles.gd verifies card-chip event pulses chips but not mult and confirms persistent reduced-motion settings. Automated initial tests: V3_MOTION failures=0, V3_SCREENS failures=0, V3_EVENT_TILES failures=0, UI_SMOKE failures=0, REDESIGN_TRANSACTIONS failures=0. Sequential raster frames were inspected at stage, multiplication, transfer and used-pile phases. Recording uses desktop OpenGL fallback (Intel); harmless NVIDIA driver probe warnings are in render logs. Video playback timing is a presentation of sampled frames, not a benchmark or Android FPS claim.

Known constraints: overlapping exposed card strips are ~38dp at eight cards/360px (full card height 100dp); this is intentional one-row tradeoff, tested via pointer-hit selection rather than claiming every visible strip is 48dp wide. Profile/checkpoint are individually atomic, not one joint transaction. Render export/device QA remains integrator-owned.

Final added checks: V3_DEAL_DISCARD failures=0 (actual initial movement, full discard sweep/refill, stable table, immutable committed state); REDESIGN_VISUAL_FIXTURES failures=0 (legacy capture now drives real PLAY instead of fake separate scoring screen). Final corrected motion media use v3-final-motion-{360,430}.mp4 and numbered PNG frames; earlier v3-motion files are intermediate proof, not final appearance.
