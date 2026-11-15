# Core API and verification

Engine: `res://core/game_engine.gd` (preload it as E, or use GameEngine).
Pure dictionary API; no filesystem, Nodes, global random state, or UI dependencies.

```gdscript
var state = E.new_run(1)
var result = E.dispatch(state, {"type":"SELECT_BLIND"})
if result.error == "": state = result.state
var selected = [state.hand_ids[0], state.hand_ids[1]]
var predicted = E.preview(state, selected)
result = E.dispatch(state, {"type":"PLAY", "ids":selected})
if result.error == "": state = result.state
```

Both successful and rejected dispatches leave the input untouched. Errors return {state: original, events: [], error: nonempty string}. Success returns a separate state, events, and error "". Preview is pure, including RNG and growth. It returns category/chips/mult/total/scoring_ids/error and, on success, blocked. A boss-blocked legal selection is NOT an error: total is zero and PLAY consumes the cards and one hand.

## Action payloads
- SELECT_BLIND: starts a blind_select state. Boss/target already visible before entry.
- PLAY / DISCARD: ids array of 1–5 distinct stable held card IDs. Order defines played scoring order.
- BUY: slot, zero-based current shop array index (successful purchase removes that offer).
- SELL: index, zero-based modifier inventory index; shop only.
- REROLL: shop only, all remaining offers refreshed, cost 5 then 6 etc.; resets each new shop.
- USE: index, zero-based consumable index; targets [] for studies, exactly one stable card ID otherwise. During playing target current hand; during shop target any deck card.
- REORDER: ids containing every owned modifier ID exactly once, including [] if none.
- NEXT: shop -> next blind_select. No skip. RESTART is E.new_run(seed).
Terminal won/lost reject every action.

Suit numbers: 0 spades, 1 hearts, 2 diamonds, 3 clubs. Ace rank 14.
Category IDs: high_card, pair, two_pair, three_of_a_kind, straight, flush, full_house, four_of_a_kind, straight_flush, five_of_a_kind, flush_house, flush_five.
Consumable IDs: study_pair, study_flush, study_straight, scarlet_dye, ink_dye, rank_lift, chip_etching, prune.
Boss IDs and original modifier metadata are in E.BOSSES / E.MODS; E.modifier(id) and E.consumable(id) return new metadata dictionaries for help/testing, not acquisition actions.

State additionally requires played_categories, last_boss, rounds_won. Do not manufacture partial state: preserve the complete returned dictionary when saving. history contains ante/round/score/reward/interest entries. modifiers have stored (growth chips). Internal helpers starting with underscore are not UI APIs.

Events: score {category,chips,mult,total,blocked}; reward {money,interest}; action {action}. Events are display-only aggregates, not a second scoring engine; core commits state first.

## Saves and determinism
Use JSON.stringify(state), JSON.parse_string, check parsed value is Dictionary, then E.validate_save(parsed). Validation accepts integral JSON floats, rejects fractions/nonfinite/wrong types/missing fields/unknown content/duplicate IDs/broken deck zones/counter-history/phase contradictions. Successful dispatch normalizes restored numbers back to integers. Bounded Park–Miller RNG state is exactly representable in JSON. Seed is reduced to a bounded integer; seeds separated by the RNG modulus can collide by design. Validation is structural, not cryptographic anti-cheat or a proof of reachability; trusted local saves still need integrator checksum/atomic-write protection.

Scoring floors the final chips × floating multiplier once. Stages: selected scoring cards in supplied order, held cards in hand order, independent modifiers in inventory order, then growth after a nonblocked scored play. All selected cards leave the hand, including kickers. No draw-pile recycling during a round. Round victory is checked before exhausted-hands loss. Interest snapshots pre-reward cash; victory payout occurs once, including the final win.

## Explicit balance adjustment
The narrow original-content catalog cannot support the reference game's late exponential targets reliably. This edition uses fixed small-blind targets [150,250,400,600,850,1150,1500,2000], big ×1.5, regular boss ×2, final Basalt Crown ×3 (6000). These are global published values, never seed/player/result-adaptive. All modifier, hand-level, starting money, payout, and consumable effects retain the specified proposal values.

Godot 4.7.2 headless checks (2026-11-15):
- run_core.gd: **1453 checks, zero failures**, exit 0. Includes all 12 categories/level increments, ace rules/kickers, every modifier, ordered stages, all eight items, six bosses, economy, deck conservation, terminal rules, 24 structural rounds, malformed saves and numeric JSON parity after every successful test action.
- simulate.gd -- 10: **9 wins / 10 seeds (1–10)** using only public new_run/preview/dispatch for gameplay. Seed 9 lost after two rounds. The policy exhaustively scores visible subsets, uses simple discard/shop heuristics, and never inspects hidden draw order or changes state. This is a small, strong-bot sample, not a human fairness claim.
- winning_replay.json: seed 1, full action trace and final state. Replayed by the regression suite with JSON round-trip parity on every action. Unlike the clearly labeled structural transition fixture (levels boosted in tests only), this winning replay has no injected money/cards/levels/targets.

Run from project root:

    godot --headless --path . --script tests/core/run_core.gd
    godot --headless --path . --script tests/core/simulate.gd -- 10

Tests exit nonzero on failure. Simulation rewrites the first winning replay in tests/core/. No git operations, UI edits, publication, APK or device tests were performed in this lane. Manual human play/balance and Android integration remain integrator gates.
