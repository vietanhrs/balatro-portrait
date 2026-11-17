# V2 core results — 2026-11-17

Godot 4.7.2 stable ed1daf0bf, headless.

- run_core.gd: **1793 checks, zero failures**. All original evaluator categories/passive effects retained; assertions updated for IDs, explicit receipt gate and new deterministic replay.
- v2.gd: **483 checks, zero failures**. JSON replay/purity on successful actions; atomic failures; route/tag/voucher/pack coverage; timeline goldens; safe migration; malformed saves.
- Honest Practice simulation seeds 1–5: **4 wins / 5** (seed 3 loses after 2 victories). Winning seeds 1,2,4,5 finish all 24 blinds.
- Honest Standard simulation seeds 1–3: **0 wins / 3**; losses after 8,11,2 victories. No target/cash/level patches, no hidden-draw inspection. This is a weak greedy policy and tiny sample, not proof that Standard is impossible. **Standard balance not established; recommend Practice.**
- New winning replay: tests/core/winning_replay_practice.json; old winning_replay.json retained as v1 historical evidence.
- Logs: regression.log, v2.log, simulation-practice.log, simulation-standard.log.

Core ownership only: core/** and tests/core/**. No UI/platform/root edits, no git commands/commit, no publication. Git status inspection deferred to exclusive integrator per no-git ownership instruction. Actual Android/UI/manual human-play testing not performed in this lane.

Known bounded deviations: no altered-category study unlocks; three tag effects coalesce duplicate free-reroll rewards; free-planet bonus uses third pack slot; normal packs only; v1 three-offer shops reject migration without destructive fallback (platform must preserve backup and ask). 20 original passives, not full reference pool.
