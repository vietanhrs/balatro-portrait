extends SceneTree
const E=preload("res://core/game_engine.gd")
var failed=false
var trace=[]
func step(s: Dictionary,a: Dictionary) -> Dictionary:
 var r=E.dispatch(s,a)
 if r.error!="" or not E.validate_save(r.state):
  printerr("Simulation error: ",r.error," ",a); failed=true
 trace.append(a)
 return r.state
func best(s: Dictionary) -> Dictionary:
 var out={"total":-1,"ids":[]}
 for mask in range(1,1<<s.hand_ids.size()):
  var ids=[]
  for i in range(s.hand_ids.size()):
   if mask&(1<<i): ids.append(s.hand_ids[i])
  if ids.size()>5: continue
  var p=E.preview(s,ids)
  if p.total>out.total: out={"total":p.total,"ids":ids}
 return out
func weight(id: String) -> int:
 return {"court":100,"red":95,"black":80,"reserve":85,"bank":90,"compact":75,"first":55,"ember":65,"ledger":70,"growth":60,"odd":70,"even":65,"twins":50,"trio":30,"ribbon":10,"prism":35,"ace":40,"last":45,"wage":20,"echo":25}.get(id,0)
func run_seed(seed_value: int) -> Dictionary:
 trace=[]
 var s=E.new_run(seed_value)
 var actions=0
 while not s.phase in ["won","lost"] and actions<1000 and not failed:
  actions+=1
  match s.phase:
   "blind_select": s=step(s,{"type":"SELECT_BLIND"})
   "playing":
    var p=best(s)
    if s.discards_left>0 and p.total<(s.target-s.round_score)/s.hands_left:
     var discard=[]
     for id in s.hand_ids:
      if not id in p.ids and discard.size()<5: discard.append(id)
     if discard.is_empty(): discard=s.hand_ids.slice(0,3)
     s=step(s,{"type":"DISCARD","ids":discard})
    else: s=step(s,{"type":"PLAY","ids":p.ids})
   "shop":
    var rerolls=0
    while true:
     var bought=false
     for slot in range(s.shop.size()):
      var offer=s.shop[slot]
      if offer.kind!="modifier" or offer.cost>s.money: continue
      if s.modifiers.size()==5:
       var worst=0
       for j in range(1,5):
        if weight(s.modifiers[j].id)<weight(s.modifiers[worst].id): worst=j
       if weight(offer.id)<=weight(s.modifiers[worst].id): continue
       s=step(s,{"type":"SELL","index":worst})
      s=step(s,{"type":"BUY","slot":slot}); bought=true; break
     if bought: continue
     for slot in range(s.shop.size()):
      if s.shop[slot].kind=="consumable" and s.shop[slot].id=="study_pair" and s.money>=s.shop[slot].cost:
       s=step(s,{"type":"BUY","slot":slot})
       s=step(s,{"type":"USE","index":0,"targets":[]}); break
     if rerolls<2 and s.money>=s.reroll_cost+12:
      s=step(s,{"type":"REROLL"}); rerolls+=1
     else: break
    var ids=[]
    for m in s.modifiers:
     if not m.id in ["first","last","compact"]: ids.append(m.id)
    for m in s.modifiers:
     if m.id in ["first","last","compact"]: ids.append(m.id)
    s=step(s,{"type":"REORDER","ids":ids})
    s=step(s,{"type":"NEXT"})
 return s
func _initialize() -> void:
 var wins=0
 var args=OS.get_cmdline_user_args()
 var count=int(args[0]) if not args.is_empty() else 10
 for seed_value in range(1,count+1):
  var s=run_seed(seed_value)
  print("SIM seed=%d phase=%s rounds=%d money=%d"%[seed_value,s.phase,s.rounds_won,s.money])
  if s.phase=="won":
   wins+=1
   if wins==1:
    var f=FileAccess.open("res://tests/core/winning_replay.json",FileAccess.WRITE)
    f.store_string(JSON.stringify({"seed":seed_value,"actions":trace,"final_state":s},"  "))
 print("SIM SUMMARY wins=%d/%d; public actions only, no hidden draws inspected"%[wins,count])
 quit(1 if failed or wins==0 else 0)
