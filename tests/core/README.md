# Core V2 verification

Run Godot 4.7.2 headless from repository root:

```sh
godot --headless --path . --script tests/core/run_core.gd
godot --headless --path . --script tests/core/v2.gd
godot --headless --path . --script tests/core/simulate.gd -- 5 practice
godot --headless --path . --script tests/core/simulate.gd -- 3 standard
```

run_core retains all 12 evaluator categories, 20 passive numeric behaviors, ordered addition/multiplication, mutation, boss, economy, validation and transition tests. Its helper allocates IDs and played counters for explicit structural fixtures. It never patches production action results. Cashout is a separate tested transaction. v2 covers skips/tags, four vouchers/packs, capacities, persisted options/target return, timeline order, strict receipt validation and migration. Existing v1 winning_replay.json remains historical; winning_replay_practice.json is the new public-action replay.

Simulation enumerates only currently held card subsets, uses public preview/dispatch, and never patches state, reads future draws, or guarantees builds. It is a modest greedy policy, not optimal play. Terminal losses count as valid test outcomes; Standard is not advertised balanced. Separate simulation logs record seeds and results. Fixture cash and level overrides are clearly limited to structural tests, never balance evidence.
