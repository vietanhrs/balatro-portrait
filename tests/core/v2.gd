extends "res://tests/core/run_core.gd"
func _initialize() -> void:
 v2()
 print("V2: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
func shop_fixture() -> Dictionary:
 var s=fixture([14])
 s.money=100
 s.target=16
 s=act(s,{"type":"PLAY","ids":[s.hand_ids[0]]})
 var before=s.money
 check(s.phase=="cashout" and s.money==before,"receipt pending")
 save_fixture("cashout",s)
 s=act(s,{"type":"CASH_OUT"})
 reject(s,{"type":"CASH_OUT"})
 return s
func save_fixture(label: String,s: Dictionary) -> void:
 var f=FileAccess.open("res://core/fixture_"+label+".json",FileAccess.WRITE)
 f.store_string(JSON.stringify(s,"  "))
func v2() -> void:
 check(E.new_run(1).mode=="practice","legacy default Practice")
 check(E.new_run(1,"standard").target==300,"explicit Standard")
 save_fixture("route",E.new_run(1,"standard"))
 for effect in ["cash","free_reroll","free_planet"]:
  var s=E.new_run(1)
  s.ante_blinds[0].tag=effect
  var cash=s.money
  var preview=s.ante_blinds[2].boss.duplicate(true)
  s=act(s,{"type":"SKIP_BLIND"})
  check(s.round==1 and s.history[0].outcome=="skipped" and s.rounds_won==0,"skip no victory")
  check(s.money==cash+(5 if effect=="cash" else 0),"skip no payout except tag")
  s=act(s,{"type":"SKIP_BLIND"})
  check(s.boss==preview,"boss sampled once")
  reject(s,{"type":"SKIP_BLIND"})
  s=act(s,{"type":"SELECT_BLIND"})
  for cat in s.levels: s.levels[cat]=100
  s=act(s,{"type":"PLAY","ids":s.hand_ids.slice(0,5)})
  s=act(s,{"type":"CASH_OUT"})
  for t in s.tags: check(t.status=="consumed","queued tags consumed on next shop")
  if effect=="free_reroll":
   check(s.reroll_cost==0,"tag free first reroll")
   s=act(s,{"type":"REROLL"})
   check(s.reroll_cost==5,"free reroll expires")
  if effect=="free_planet":
   var found=false
   for p in s.pack_offers: found=found or (p.family=="planet" and p.cost==0)
   check(found,"tag planet parcel")
 for id in E.VOUCHERS:
  var s=shop_fixture()
  s.voucher_offer={"id":id,"name":E.VOUCHERS[id][0],"description":E.VOUCHERS[id][1],"cost":10,"offer_id":E._uid(s),"purchased":false}
  s=act(s,{"type":"BUY_VOUCHER"})
  reject(s,{"type":"BUY_VOUCHER"})
  var offer=s.voucher_offer.duplicate(true)
  var packs=s.pack_offers.duplicate(true)
  s=act(s,{"type":"REROLL"})
  check(s.voucher_offer==offer and s.pack_offers==packs,"reroll only mixed shelf")
  s=act(s,{"type":"NEXT"})
  check(s.hands_left==(5 if id=="extra_hand" else 4),"voucher hands reset")
  check(s.discards_left==(4 if id=="extra_discard" else 3),"voucher discards reset")
  check(s.voucher_offer==offer,"ante voucher persists")
 for family in ["passive","planet","tarot","playing_card"]:
  var s=shop_fixture()
  s.pack_offers=[E._pack_offer(s,family)]
  var shelf=s.shop.duplicate(true)
  var money=s.money
  var count=s.deck.size()
  s=act(s,{"type":"OPEN_PACK","offer_id":s.pack_offers[0].offer_id})
  check(s.money==money-4,"pack charged once")
  save_fixture("pack_"+family,s)
  reject(s,{"type":"OPEN_PACK","offer_id":s.pack_state.offer_id})
  var original=s.duplicate(true)
  s=act(s,{"type":"CANCEL_TARGET"})
  check(s.pack_state==original.pack_state and s.money==original.money,"cancel preserves target return")
  var option=s.pack_state.options[0]
  var targets=s.pack_state.target_ids.slice(0,option.get("target_count",0))
  if family=="tarot": reject(s,{"type":"CHOOSE_PACK","option_id":option.option_id,"targets":[]})
  var action={"type":"CHOOSE_PACK","option_id":option.option_id,"targets":targets}
  var resumed=E.dispatch(JSON.parse_string(JSON.stringify(s)),action)
  s=act(s,action)
  check(JSON.stringify(s)==JSON.stringify(resumed.state),"pack force-stop resume parity")
  check(s.phase=="shop" and s.shop==shelf,"pack returns unchanged shop")
  check(s.deck.size()==count+(1 if family=="playing_card" else (-1 if option.id=="prune" else 0)),"deck conservation")
  if family=="playing_card": check(E.validate_save(s) and s.deck.size()==53,"expanded deck valid")
 var s=shop_fixture()
 for id in E.MODS.keys().slice(0,5): s.modifiers.append(E._instance(s,E.modifier(id)))
 s.pack_offers=[E._pack_offer(s,"passive")]
 s=act(s,{"type":"OPEN_PACK","offer_id":s.pack_offers[0].offer_id})
 reject(s,{"type":"CHOOSE_PACK","option_id":s.pack_state.options[0].option_id})
 s=act(s,{"type":"SELL","instance_id":s.modifiers[0].instance_id})
 s=act(s,{"type":"CHOOSE_PACK","option_id":s.pack_state.options[0].option_id})
 check(s.modifiers.size()==5,"sell within full-slot pack")
 s=fixture([12,14],[1,0])
 s.modifiers=[E._instance(s,E.modifier("compact")),E._instance(s,E.modifier("echo")),E._instance(s,E.modifier("court"))]
 var p=score(s,1)
 var stages=[]
 for event in p.timeline: stages.append(event.stage)
 check(stages==["base","card","on_score","held","independent","total"],"golden ordered score timeline")
 check(p.mult==12,"golden mult 1+5+2 then times1.5")
 save_fixture("playing",s)
 var f=FileAccess.open("res://core/fixture_timeline.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(p,"  "))
 var old=preload("res://core/legacy_v1.gd").new_run(55)
 var migrated=E.migrate_save(old)
 check(not migrated.is_empty() and migrated.mode=="practice" and E.validate_save(migrated),"safe v1 migration")
 old.money="bad"
 check(E.migrate_save(old).is_empty(),"malformed migration fails closed")
 s=shop_fixture()
 save_fixture("shop",s)
 for key in ["receipt","pack_state","tags","ante_blinds","voucher_offer"]:
  var bad=s.duplicate(true)
  bad[key]=false
  check(not E.validate_save(bad),"malformed v2 "+key)

 # Extra-hand first-hand condition uses played count rather than four remaining.
 s=fixture([4])
 s.purchased_vouchers=["extra_hand"]
 s.hands_per_round=5
 s.hands_left=5
 s.modifiers=[E._instance(s,E.modifier("first"))]
 check(score(s,1).mult==1.75,"first effect with five starting hands")
 s.hands_left=4
 s.hands_played_this_round=1
 s.played_categories=["high_card"]
 check(score(s,1).mult==1.0,"first effect not repeated at four hands")
 s=shop_fixture()
 var repeat=shop_fixture()
 check(s.shop==repeat.shop and s.rng_state==repeat.rng_state,"weighted shelf fixed seed")
 check(s.shop.size()==2,"two mixed offers")
 s.pack_offers=[E._pack_offer(s,"planet")]
 s=act(s,{"type":"OPEN_PACK","offer_id":s.pack_offers[0].offer_id})
 var balance=s.money
 s=act(s,{"type":"SKIP_PACK"})
 check(s.money==balance and s.pack_state.is_empty(),"pack skip no refund")
 s=fixture([14])
 s.target=16
 s=act(s,{"type":"PLAY","ids":[s.hand_ids[0]]})
 var corrupt=s.duplicate(true)
 corrupt.receipt.total+=1
 corrupt.receipt.money_after+=1
 corrupt.receipt.line_items[0].amount+=1
 check(not E.validate_save(corrupt),"reject internally balanced forged receipt")

 for id in E.ITEMS:
  if not id.begins_with("study_"): continue
  var level_state=fixture([4])
  level_state.consumables=[E._instance(level_state,E.consumable(id))]
  level_state=act(level_state,{"type":"USE","instance_id":level_state.consumables[0].instance_id,"targets":[]})
  check(level_state.levels[id.trim_prefix("study_")]==2,"natural study "+id)
 for id in ["diamond_dye","club_dye","rank_copy"]:
  var mutation=fixture([14,3])
  mutation.consumables=[E._instance(mutation,E.consumable(id))]
  var target=mutation.hand_ids[1]
  mutation=act(mutation,{"type":"USE","instance_id":mutation.consumables[0].instance_id,"targets":[mutation.hand_ids[0],target] if id=="rank_copy" else [target]})
  check(E._card(mutation,target).rank==14 if id=="rank_copy" else E._card(mutation,target).suit==(2 if id=="diamond_dye" else 3),"persistent new mutation "+id)
 var legacy=preload("res://core/legacy_v1.gd")
 var old_play=legacy.dispatch(legacy.new_run(7),{"type":"SELECT_BLIND"}).state
 var migrated_play=E.migrate_save(JSON.parse_string(JSON.stringify(old_play)))
 check(not migrated_play.is_empty() and migrated_play.hand_ids==old_play.hand_ids and migrated_play.money==old_play.money,"mid-play JSON migration preserves progress")
 var bad=shop_fixture()
 bad.modifiers=[E._instance(bad,E.modifier("ember")),E._instance(bad,E.modifier("ledger"))]
 bad.modifiers[1].instance_id=bad.modifiers[0].instance_id
 check(not E.validate_save(bad),"duplicate instance rejected")
 bad=shop_fixture()
 bad.pack_offers=[E._pack_offer(bad,"tarot")]
 bad=act(bad,{"type":"OPEN_PACK","offer_id":bad.pack_offers[0].offer_id})
 bad.pack_state.options[0].id="not_in_catalog"
 check(not E.validate_save(bad),"malformed persisted pack rejected")
