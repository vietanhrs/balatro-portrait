extends SceneTree
const E = preload("res://core/game_engine.gd")
const Old = preload("res://core/legacy_v1.gd")
var failures = 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func _initialize() -> void:
	var replay = JSON.parse_string(FileAccess.get_file_as_string("res://tests/core/winning_replay.json"))
	var old = Old.new_run(int(replay.seed))
	for action in replay.actions:
		old = Old.dispatch(old, action).state
		if old.phase == "shop": break
	check(Old.validate_save(old) and old.shop.size() == 3, "real legal v1 three-offer shop")
	var migrated = E.migrate_save(old)
	check(not migrated.is_empty(), "three-offer migration succeeds")
	if migrated.is_empty(): quit(1); return
	check(migrated.shop.size() == 3 and migrated.money == old.money and migrated.rng_state == old.rng_state, "preserve offers money RNG")
	for i in range(3): check(migrated.shop[i].id == old.shop[i].id and migrated.shop[i].cost == old.shop[i].cost, "preserve legacy offer " + str(i))
	var next = E.dispatch(migrated, {"type":"NEXT"})
	check(next.error == "" and not next.state.has("legacy_shop"), "next removes compatibility shelf")
	var reroll = E.dispatch(migrated, {"type":"REROLL"})
	check(reroll.error == "" and reroll.state.shop.size() == 2 and not reroll.state.has("legacy_shop"), "reroll returns standard two slots")
	var buy = E.dispatch(migrated, {"type":"BUY", "offer_id":migrated.shop[2].offer_id})
	check(buy.error == "" and buy.state.shop.size() == 2, "third offer purchasable by durable ID")
	var invalid = migrated.duplicate(true)
	invalid.erase("legacy_shop")
	check(not E.validate_save(invalid), "ordinary three-offer state rejected")
	invalid = migrated.duplicate(true)
	invalid.shop.append(invalid.shop[0].duplicate(true))
	check(not E.validate_save(invalid), "four legacy offers rejected")
	quit(1 if failures else 0)
