extends SceneTree
const E = preload("res://core/game_engine.gd")
var checks = 0
var failures = 0
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok: failures+=1; printerr("FAIL: ",label)
func sync_fixture(s: Dictionary) -> void:
 s.hands_played_this_round=s.played_categories.size()
 for list in [s.modifiers,s.consumables]:
  for item in list:
   if not item.has("instance_id"): E._instance(s,item)

func act(s: Dictionary, a: Dictionary) -> Dictionary:
 sync_fixture(s)
 var before = JSON.stringify(s)
 var r = E.dispatch(s,a)
 check(r.error=="","action "+str(a)+" "+r.error)
 check(JSON.stringify(s)==before,"dispatch input purity")
 check(E.validate_save(r.state),"valid action result")
 var restored = JSON.parse_string(JSON.stringify(s))
 var rr = E.dispatch(restored,a)
 check(JSON.stringify(E._normalize(rr.state))==JSON.stringify(E._normalize(r.state)),"JSON replay parity")
 return r.state
func reject(s: Dictionary,a: Dictionary) -> void:
 sync_fixture(s)
 var before = JSON.stringify(s)
 var r = E.dispatch(s,a)
 check(r.error!="" and JSON.stringify(r.state)==before and JSON.stringify(s)==before,"transactional rejection "+str(a))
func fixture(ranks: Array, suits: Array=[]) -> Dictionary:
 var s = E.new_run(7)
 s.phase="playing"
 for i in range(8):
  var c = s.deck[i]
  c.rank=ranks[i] if i<ranks.size() else 2+i
  c.suit=suits[i] if i<suits.size() else i%4
  s.hand_ids.append(c.id)
  s.draw_ids.erase(c.id)
 return s
func score(s: Dictionary,n: int) -> Dictionary:
 sync_fixture(s)
 var before = JSON.stringify(s)
 var p = E.preview(s,s.hand_ids.slice(0,n))
 check(p.error=="","preview success")
 check(before==JSON.stringify(s),"preview pure")
 return p
func boss(s: Dictionary,id: String) -> void:
 s.round=2
 s.rounds_won=2
 s.history=[{"ante":1,"round":0,"score":150,"reward":3,"interest":0,"outcome":"won"},{"ante":1,"round":1,"score":225,"reward":4,"interest":0,"outcome":"won"}]
 s.boss={"id":id,"name":E.BOSSES[id][0],"description":E.BOSSES[id][1]}
 s.last_boss=id
 s.ante_blinds[2].boss=s.boss.duplicate(true)
func _initialize() -> void:
 categories()
 effects()
 items()
 economy()
 bosses()
 saves()
 transitions()
 edges()
 replay()
 print("CORE: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
func categories() -> void:
 var cases = [
 ["high_card",[2,5,8,11,14],[],1], ["pair",[4,4,7,9,14],[],2],
 ["two_pair",[4,4,7,7,14],[],4], ["three_of_a_kind",[4,4,4,9,14],[],3],
 ["straight",[2,3,4,5,14],[],5], ["flush",[2,5,8,11,14],[1,1,1,1,1],5],
 ["full_house",[4,4,4,9,9],[],5], ["four_of_a_kind",[4,4,4,4,14],[],4],
 ["straight_flush",[10,11,12,13,14],[0,0,0,0,0],5], ["five_of_a_kind",[4,4,4,4,4],[],5],
 ["flush_house",[4,4,4,9,9],[2,2,2,2,2],5], ["flush_five",[4,4,4,4,4],[3,3,3,3,3],5]]
 for c in cases:
  var s = fixture(c[1],c[2])
  var p = score(s,5)
  check(p.category==c[0] and p.scoring_ids.size()==c[3],"category "+c[0])
  var base = E.HANDS[c[0]]
  s.levels[c[0]]=2
  var q = score(s,5)
  check(q.chips==p.chips+base[2] and q.mult==p.mult+base[3],"level "+c[0])
 check(score(fixture([13,14,2,3,4]),5).category=="high_card","no ace wrap")
 check(score(fixture([14]),1).chips==16,"ace chips")
 check(score(fixture([11]),1).chips==15,"face chips")
 var s = fixture([4,4,14])
 check(score(s,3).chips==18,"kicker excluded")
 reject(s,{"type":"PLAY","ids":[]})
 reject(s,{"type":"PLAY","ids":s.hand_ids.slice(0,6)})
 reject(s,{"type":"PLAY","ids":[s.hand_ids[0],s.hand_ids[0]]})
func effects() -> void:
 var cases = [
 ["ember",[4],1,0,4], ["ledger",[4],1,35,0], ["twins",[4,4],2,0,8],
 ["trio",[4,4,4],3,0,12], ["ribbon",[2,3,4,5,6],5,60,0],
 ["prism",[2,4,6,8,10],5,0,10], ["red",[4],1,0,3], ["black",[4],1,18,0],
 ["court",[12],1,0,5], ["ace",[14],1,30,0], ["even",[4],1,16,0],
 ["odd",[3],1,0,3], ["reserve",[4],1,36,0], ["bank",[4],1,0,12],
 ["growth",[4],1,9,0], ["wage",[4],1,0,0], ["echo",[4,14],1,0,2]]
 for c in cases:
  var s = fixture(c[1])
  if c[0]=="prism":
   for i in range(5): s.deck[i].suit=1
  if c[0]=="red": s.deck[0].suit=1
  s.money=35
  var p = score(s,c[2])
  s.modifiers=[E.modifier(c[0])]
  if c[0]=="growth": s.modifiers[0].stored=9
  var q = score(s,c[2])
  check(q.chips==p.chips+c[3] and q.mult==p.mult+c[4],"effect "+c[0])
 for id in ["first","last","compact"]:
  var s = fixture([4])
  if id=="last": s.hands_left=1; s.played_categories=["pair","pair","pair"]
  var p = score(s,1)
  s.modifiers=[E.modifier(id)]
  check(score(s,1).mult==p.mult*({"first":1.75,"last":2.5,"compact":1.5}[id]),"multiply "+id)
 var s = fixture([4])
 s.modifiers=[E.modifier("ember"),E.modifier("compact")]
 check(score(s,1).mult==7.5,"add before multiply")
 s=act(s,{"type":"REORDER","ids":["compact","ember"]})
 check(score(s,1).mult==5.5,"multiply before add")
 reject(s,{"type":"REORDER","ids":["ember","ember"]})
 s=fixture([12,14],[1,0])
 s.modifiers=[E.modifier("compact"),E.modifier("echo"),E.modifier("court")]
 check(score(s,1).mult==12,"on-score then held then independent")
 s=fixture([4]); s.modifiers=[E.modifier("growth")]
 s=act(s,{"type":"PLAY","ids":[s.hand_ids[0]]})
 check(s.modifiers[0].stored==3,"growth after hand")
 for id in ["twins","trio","ribbon","prism","court","ace","odd","red","last"]:
  s=fixture([2]); s.deck[0].suit=0
  var p=score(s,1)
  s.modifiers=[E.modifier(id)]
  check(score(s,1).total==p.total,"inactive "+id)
 s=fixture([3]); s.deck[0].suit=1
 for id in ["black","even","echo","bank"]:
  s.modifiers=[E.modifier(id)]
  check(score(s,1).total==8,"inactive "+id)
func items() -> void:
 for id in E.ITEMS:
  var s = fixture([14])
  s.consumables=[E.consumable(id)]
  var target=s.hand_ids[0]
  var targets=[] if id.begins_with("study_") else ([s.hand_ids[1],target] if id=="rank_copy" else [target])
  reject(s,{"type":"USE","index":0,"targets":["missing"]})
  s=act(s,{"type":"USE","index":0,"targets":targets})
  check(s.consumables.is_empty(),"consumed "+id)
  match id:
   "study_pair","study_flush","study_straight": check(s.levels[id.trim_prefix("study_")]==2,"study level")
   "scarlet_dye": check(E._card(s,target).suit==1,"hearts")
   "ink_dye": check(E._card(s,target).suit==0,"spades")
   "rank_lift": check(E._card(s,target).rank==2,"ace wraps")
   "chip_etching": check(E._card(s,target).bonus_chips==20,"etch")
   "prune": check(s.deck.size()==51 and E._card(s,target).is_empty(),"prune all zones")
 var s=fixture([2])
 s.deck=s.deck.slice(0,8); s.draw_ids=[]
 s.consumables=[E.consumable("prune")]
 reject(s,{"type":"USE","index":0,"targets":[s.hand_ids[0]]})
 s=act(s,{"type":"DISCARD","ids":s.hand_ids.slice(0,5)})
 check(s.hand_ids.size()==3,"empty pile never recycled")
func economy() -> void:
 for cash in [0,4,5,24,25,30]:
  var s=fixture([14]); s.money=cash; s.target=16
  s.modifiers=[E.modifier("wage")]
  s=act(s,{"type":"PLAY","ids":[s.hand_ids[0]]})
  check(s.phase=="cashout" and s.money==cash,"pending receipt no payment")
  s=act(s,{"type":"CASH_OUT"})
  check(s.phase=="shop" and s.money==cash+9+mini(cash/5,5),"interest snapshot "+str(cash))
  reject(s,{"type":"PLAY","ids":[s.hand_ids[0]]})
 var s=fixture([14]); s.target=16; s.money=50
 s=act(s,{"type":"PLAY","ids":[s.hand_ids[0]]})
 s=act(s,{"type":"CASH_OUT"})
 var cash=s.money
 s=act(s,{"type":"REROLL"})
 check(s.money==cash-5 and s.reroll_cost==6,"reroll five")
 s=act(s,{"type":"REROLL"})
 check(s.money==cash-11 and s.reroll_cost==7,"reroll six")
 s.shop[0]=E._instance(s,E.modifier("ember")); s.shop[0]["kind"]="modifier"; s.shop[0]["offer_id"]=s.shop[0].instance_id
 var cost=s.shop[0].cost
 cash=s.money
 s=act(s,{"type":"BUY","slot":0})
 check(s.money==cash-cost and s.modifiers.size()==1,"buy")
 s=act(s,{"type":"SELL","index":0})
 check(s.money==cash-cost+cost/2,"sell")
 s.money=0
 reject(s,{"type":"BUY","slot":0})
 reject(s,{"type":"REROLL"})
 s.money=50
 s.shop[0]=E._instance(s,E.modifier("last")); s.shop[0]["kind"]="modifier"; s.shop[0]["offer_id"]=s.shop[0].instance_id
 for id in E.MODS.keys().slice(0,5): s.modifiers.append(E.modifier(id))
 reject(s,{"type":"BUY","slot":0})
 s=act(s,{"type":"NEXT"})
 check(s.hands_left==4 and s.discards_left==3 and s.round==1,"next reset")
func bosses() -> void:
 var s=fixture([4,4,5,7,9]); boss(s,"full_assembly")
 check(score(s,2).total==0 and score(s,5).total>0,"assembly constraint")
 s=act(s,{"type":"PLAY","ids":s.hand_ids.slice(0,2)})
 check(s.hands_left==3 and s.round_score==0,"blocked consumes hand")
 s=fixture([4]); boss(s,"dry_well"); s.discards_left=0
 reject(s,{"type":"DISCARD","ids":[s.hand_ids[0]]})
 s=fixture([4,4]); boss(s,"changing_signal"); s.hands_left=3; s.played_categories=["pair"]
 check(score(s,2).total==0 and score(s,1).total>0,"changing signal")
 boss(s,"single_frequency")
 check(score(s,2).total>0 and score(s,1).total==0,"single frequency")
 s=E.new_run(9); s.round=2; E._prepare(s)
 boss(s,"narrow_gate")
 s=act(s,{"type":"SELECT_BLIND"})
 check(s.hand_ids.size()==7,"narrow seven")
 s=E.new_run(9); s.ante=8; s.round=2; E._route(s); E._prepare(s)
 check(s.boss.id=="basalt_crown" and s.target==E.TARGETS[7]*3,"final boss target")
func saves() -> void:
 var s=E.new_run(-9223372036854775807)
 check(E.validate_save(s),"large negative seed")
 s=act(s,{"type":"SELECT_BLIND"})
 check(E.validate_save(JSON.parse_string(JSON.stringify(s))),"JSON float integers valid")
 for key in s:
  var bad=s.duplicate(true); bad.erase(key)
  check(not E.validate_save(bad),"missing "+key)
 for key in ["money","rng_state","ante","hands_left"]:
  var bad=s.duplicate(true); bad[key]=1.5
  check(not E.validate_save(bad),"fraction rejected "+key)
 var bad=s.duplicate(true); bad.draw_ids.append(s.hand_ids[0])
 check(not E.validate_save(bad),"duplicate zone rejected")
 bad=s.duplicate(true); bad.deck[0].rank="ace"
 check(not E.validate_save(bad),"bad card type")
 bad=s.duplicate(true); bad.modifiers=[{"id":"unknown"}]
 check(not E.validate_save(bad),"unknown modifier")
 var same=E.dispatch(E.new_run(123),{"type":"SELECT_BLIND"}).state
 check(same==E.dispatch(E.new_run(123),{"type":"SELECT_BLIND"}).state,"seed replay")
func transitions() -> void:
 # Structural fixture exercises the entire state machine; honest simulation is separate.
 var s=E.new_run(77)
 var previous_boss=""
 for n in range(24):
  check(s.ante==n/3+1 and s.round==n%3,"round index "+str(n))
  if s.round==2:
   check(s.boss.id!=previous_boss,"no consecutive boss")
   previous_boss=s.boss.id
  s=act(s,{"type":"SELECT_BLIND"})
  # Boost levels only in this explicit structural fixture, never in simulation/core.
  for k in s.levels: s.levels[k]=100
  var ids=s.hand_ids.slice(0,5)
  s=act(s,{"type":"PLAY","ids":ids})
  check(s.phase=="cashout","explicit receipt gate")
  s=act(s,{"type":"CASH_OUT"})
  check(s.phase==("won" if n==23 else "shop"),"round victory "+str(n))
  if n<23: s=act(s,{"type":"NEXT"})
 check(s.history.size()==24,"24 rewards once")
 reject(s,{"type":"NEXT"})
 reject(s,{"type":"REORDER","ids":[]})
 s=fixture([14]); s.hands_left=1; s.played_categories=["pair","pair","pair"]; s.target=16
 s=act(s,{"type":"PLAY","ids":[s.hand_ids[0]]})
 check(s.phase=="cashout","last hand exact target wins before loss")
 s=fixture([2]); s.hands_left=1; s.played_categories=["pair","pair","pair"]
 s=act(s,{"type":"PLAY","ids":[s.hand_ids[0]]})
 check(s.phase=="lost","last hand loss")
 reject(s,{"type":"SELECT_BLIND"})

func edges() -> void:
 var s=fixture([2,3,4,5,6])
 s.modifiers=[E.modifier("compact")]
 check(score(s,5).mult==4,"compact inactive on five")
 s.modifiers=[E.modifier("first")]; s.hands_left=3; s.played_categories=["pair"]
 check(score(s,5).mult==4,"first inactive after play")
 s.modifiers=[E.modifier("reserve")]; s.discards_left=0
 check(score(s,5).chips==50,"reserve zero discards")
 s=fixture([14]); s.consumables=[E.consumable("chip_etching")]
 s.deck[0].bonus_chips=20
 s=act(s,{"type":"USE","index":0,"targets":[s.hand_ids[0]]})
 check(s.deck[0].bonus_chips==20,"etch replaces not stacks")
 s=fixture([14]); s.target=16; s.money=30
 s=act(s,{"type":"PLAY","ids":[s.hand_ids[0]]})
 s=act(s,{"type":"CASH_OUT"})
 s.consumables=[E.consumable("rank_lift")]
 var target=s.draw_ids[0]
 var rank=E._card(s,target).rank
 s=act(s,{"type":"USE","index":0,"targets":[target]})
 check(E._card(s,target).rank==(2 if rank==14 else rank+1),"shop deck picker")
 s.consumables=[E.consumable("study_pair"),E.consumable("study_flush")]
 var slot=-1
 for i in range(s.shop.size()):
  if s.shop[i].kind=="consumable": slot=i
 reject(s,{"type":"BUY","slot":slot})
 for value in [null,true,"oops",[],{}]:
  var bad=s.duplicate(true); bad.money=value
  check(not E.validate_save(bad),"reject malformed money")
  bad=s.duplicate(true); bad.shop=[value]
  check(not E.validate_save(bad),"reject malformed shop")
func replay() -> void:
 if not FileAccess.file_exists("res://tests/core/winning_replay_practice.json"):
  check(false,"winning replay exists"); return
 var record=JSON.parse_string(FileAccess.get_file_as_string("res://tests/core/winning_replay_practice.json"))
 var s=E.new_run(int(record.seed),record.get("mode","practice"))
 for action in record.actions:
  s=act(s,action)
 check(s.phase=="won" and s.rounds_won==24,"honest winning replay")
 check(JSON.stringify(E._normalize(s))==JSON.stringify(E._normalize(record.final_state)),"winning replay exact final state")
