class_name GameEngine
extends RefCounted
## Pure dictionary engine. RNG uses bounded Park-Miller integers, exactly JSON safe.
const VERSION = 1
const HANDS = {
 "high_card":[5,1,10,1], "pair":[10,2,15,1], "two_pair":[20,2,20,1],
 "three_of_a_kind":[30,3,20,2], "straight":[30,4,30,3], "flush":[35,4,15,2],
 "full_house":[40,4,25,2], "four_of_a_kind":[60,7,30,3], "straight_flush":[100,8,40,4],
 "five_of_a_kind":[120,12,35,3], "flush_house":[140,14,40,4], "flush_five":[160,16,50,3]}
# Restricted-content difficulty curve, deliberately not the original game's curve.
const TARGETS = [150,250,400,600,850,1150,1500,2000]
const MODS = {
 "ember":["Ember Pin","+4 multiplier."], "ledger":["Brass Ledger","+35 chips."],
 "twins":["Twin Lanterns","Pair or Two Pair: +8 multiplier."], "trio":["Third Rail","Three, Four or Five of a Kind: +12 multiplier."],
 "ribbon":["River Ribbon","Straight or Straight Flush: +60 chips."], "prism":["Prism Badge","Flush categories: +10 multiplier."],
 "red":["Scarlet Thread","Scoring hearts and diamonds: +3 multiplier each."], "black":["Ink Thread","Scoring spades and clubs: +18 chips each."],
 "court":["Court Stamp","Scoring face cards: +5 multiplier each."], "ace":["North Star","Scoring aces: +30 chips each."],
 "even":["Even Gauge","Scoring 2/4/6/8/10: +16 chips each."], "odd":["Odd Spark","Scoring A/3/5/7/9: +3 multiplier each."],
 "reserve":["Reserve Dial","+12 chips per remaining discard."], "first":["Opening Bell","First hand: ×1.75 multiplier."],
 "last":["Last Beacon","Last available hand: ×2.5 multiplier."], "compact":["Pocket Engine","Play at most three cards: ×1.5 multiplier."],
 "bank":["Copper Vault","+2 multiplier per $5, capped at +12."], "growth":["Trail Marker","Adds stored chips; gains 3 after each scoring hand."],
 "wage":["Night Shift","+$3 on round victory."], "echo":["Quiet Observatory","Held aces: +2 multiplier each."]}
const ITEMS = {
 "study_pair":["Study Pair","Level up Pair."], "study_flush":["Study Flush","Level up Flush."], "study_straight":["Study Straight","Level up Straight."],
 "scarlet_dye":["Scarlet Dye","Change one card to hearts."], "ink_dye":["Ink Dye","Change one card to spades."],
 "rank_lift":["Rank Lift","Raise one rank; ace wraps to two."], "chip_etching":["Chip Etching","Set one card's permanent bonus to 20 chips."], "prune":["Prune","Remove one card; keep at least eight."]}
const BOSSES = {
 "narrow_gate":["Narrow Gate","Draw a seven-card hand."], "full_assembly":["Full Assembly","Only plays of exactly five cards score."],
 "dry_well":["Dry Well","No discards this round."], "changing_signal":["Changing Signal","A category can score only on its first play."],
 "single_frequency":["Single Frequency","Only the first played category scores."], "basalt_crown":["Basalt Crown","Triple the ante target."]}

static func modifier(id: String) -> Dictionary:
 if not MODS.has(id): return {}
 return {"id":id,"name":MODS[id][0],"description":MODS[id][1],"cost":4 if MODS.keys().find(id)<13 else 6,"stored":0}

static func consumable(id: String) -> Dictionary:
 if not ITEMS.has(id): return {}
 return {"id":id,"name":ITEMS[id][0],"description":ITEMS[id][1],"cost":3 if id.begins_with("study_") else 4}

static func _rand(s: Dictionary, n: int) -> int:
 s.rng_state = (int(s.rng_state)*48271)%2147483647
 return int(s.rng_state)%n

static func new_run(seed: int) -> Dictionary:
 var s = {"version":VERSION,"seed":seed%2147483647,"rng_state":posmod(seed,2147483646)+1,"phase":"blind_select","ante":1,"round":0,"money":4,"deck":[],"draw_ids":[],"hand_ids":[],"used_ids":[],"hands_left":4,"discards_left":3,"round_score":0,"target":TARGETS[0],"boss":{},"levels":{},"modifiers":[],"consumables":[],"shop":[],"reroll_cost":5,"history":[],"played_categories":[],"last_boss":"","rounds_won":0}
 for suit in range(4):
  for rank in range(2,15):
   s.deck.append({"id":"c%d_%d"%[suit,rank],"rank":rank,"suit":suit,"bonus_chips":0})
   s.draw_ids.append("c%d_%d"%[suit,rank])
 for k in HANDS: s.levels[k]=1
 return s

static func _card(s: Dictionary, id: String) -> Dictionary:
 for c in s.deck:
  if c.id==id: return c
 return {}

static func _ids_ok(ids: Variant, allowed: Array, low: int, high: int) -> bool:
 if not ids is Array or ids.size()<low or ids.size()>high: return false
 var seen = {}
 for id in ids:
  if not id is String or not id in allowed or seen.has(id): return false
  seen[id]=true
 return true

static func _evaluate(cards: Array) -> Dictionary:
 var groups = {}
 var ranks = []
 for c in cards:
  if not groups.has(int(c.rank)): groups[int(c.rank)]=[]
  groups[int(c.rank)].append(c.id)
  if not int(c.rank) in ranks: ranks.append(int(c.rank))
 ranks.sort()
 var counts = []
 for r in groups: counts.append(groups[r].size())
 counts.sort()
 var flush = cards.size()==5
 for c in cards: flush = flush and c.suit==cards[0].suit
 var straight = ranks.size()==5 and (ranks[4]-ranks[0]==4 or ranks==[2,3,4,5,14])
 var top = counts[-1]
 var cat = "high_card"
 if top==5: cat="flush_five" if flush else "five_of_a_kind"
 elif counts==[2,3]: cat="flush_house" if flush else "full_house"
 elif straight and flush: cat="straight_flush"
 elif top==4: cat="four_of_a_kind"
 elif flush: cat="flush"
 elif straight: cat="straight"
 elif top==3: cat="three_of_a_kind"
 elif counts.count(2)==2: cat="two_pair"
 elif top==2: cat="pair"
 var scoring = []
 for c in cards:
  if cat in ["straight","flush","full_house","straight_flush","five_of_a_kind","flush_house","flush_five"] or (cat=="high_card" and int(c.rank)==ranks[-1]) or (cat=="two_pair" and groups[int(c.rank)].size()==2) or (cat in ["pair","three_of_a_kind","four_of_a_kind"] and groups[int(c.rank)].size()==top):
   scoring.append(c.id)
 return {"category":cat,"scoring_ids":scoring}

static func preview(s: Dictionary, card_ids: Array) -> Dictionary:
 var out = {"category":"","chips":0,"mult":0.0,"total":0,"scoring_ids":[],"error":""}
 if not validate_save(s): out.error="Invalid state"; return out
 if s.phase!="playing": out.error="Not playing"; return out
 if not _ids_ok(card_ids,s.hand_ids,1,5): out.error="Select one to five distinct held cards"; return out
 var cards = []
 for id in card_ids: cards.append(_card(s,id))
 var evaluated = _evaluate(cards)
 out.merge(evaluated,true)
 var cat = out.category
 var base = HANDS[cat]
 var level = int(s.levels[cat])-1
 var chips = base[0]+level*base[2]
 var mult = float(base[1]+level*base[3])
 for c in cards:
  if not c.id in out.scoring_ids: continue
  chips += (11 if c.rank==14 else mini(int(c.rank),10))+int(c.bonus_chips)
  for m in s.modifiers:
   match m.id:
    "red":
     if int(c.suit) in [1,2]: mult+=3
    "black":
     if int(c.suit) in [0,3]: chips+=18
    "court":
     if int(c.rank) in [11,12,13]: mult+=5
    "ace":
     if c.rank==14: chips+=30
    "even":
     if int(c.rank) in [2,4,6,8,10]: chips+=16
    "odd":
     if int(c.rank) in [14,3,5,7,9]: mult+=3
 for id in s.hand_ids:
  if id in card_ids: continue
  for m in s.modifiers:
   if m.id=="echo" and _card(s,id).rank==14: mult+=2
 for m in s.modifiers:
  match m.id:
   "ember": mult+=4
   "ledger": chips+=35
   "twins":
    if cat in ["pair","two_pair"]: mult+=8
   "trio":
    if cat in ["three_of_a_kind","four_of_a_kind","five_of_a_kind"]: mult+=12
   "ribbon":
    if cat in ["straight","straight_flush"]: chips+=60
   "prism":
    if cat in ["flush","straight_flush","flush_house","flush_five"]: mult+=10
   "reserve": chips+=12*int(s.discards_left)
   "first":
    if s.hands_left==4: mult*=1.75
   "last":
    if s.hands_left==1: mult*=2.5
   "compact":
    if card_ids.size()<=3: mult*=1.5
   "bank": mult+=mini(int(s.money)/5,6)*2
   "growth": chips+=int(m.stored)
 var blocked = false
 match s.boss.get("id",""):
  "full_assembly": blocked=card_ids.size()!=5
  "changing_signal": blocked=cat in s.played_categories
  "single_frequency": blocked=not s.played_categories.is_empty() and cat!=s.played_categories[0]
 out.chips=chips
 out.mult=mult
 out.total=0 if blocked else int(floor(chips*mult))
 out["blocked"]=blocked
 return out

static func _refill(s: Dictionary) -> void:
 var size = 7 if s.boss.get("id","")=="narrow_gate" else 8
 while s.hand_ids.size()<size and not s.draw_ids.is_empty(): s.hand_ids.append(s.draw_ids.pop_back())

static func _shop(s: Dictionary) -> void:
 s.shop=[]
 var available = MODS.keys()
 for m in s.modifiers: available.erase(m.id)
 for i in range(2):
  if available.is_empty(): break
  var id = available.pop_at(_rand(s,available.size()))
  var item = modifier(id)
  item["kind"]="modifier"
  s.shop.append(item)
 var item = consumable(ITEMS.keys()[_rand(s,ITEMS.size())])
 item["kind"]="consumable"
 s.shop.append(item)

static func _prepare(s: Dictionary) -> void:
 s.boss={}
 if s.round==2:
  var id = "basalt_crown"
  if s.ante<8:
   var choices = BOSSES.keys().slice(0,5)
   choices.erase(s.last_boss)
   id=choices[_rand(s,choices.size())]
  s.boss={"id":id,"name":BOSSES[id][0],"description":BOSSES[id][1]}
  s.last_boss=id
 s.target=int(TARGETS[int(s.ante)-1]*(1.0 if s.round==0 else (1.5 if s.round==1 else (3.0 if s.ante==8 else 2.0))))
 s.hands_left=4
 s.discards_left=0 if s.boss.get("id","")=="dry_well" else 3
 s.round_score=0
 s.played_categories=[]
 s.hand_ids=[]
 s.used_ids=[]
 s.draw_ids=[]
 for c in s.deck: s.draw_ids.append(c.id)

static func dispatch(state: Dictionary, action: Dictionary) -> Dictionary:
 var fail = {"state":state,"events":[],"error":"Invalid state"}
 if not validate_save(state): return fail
 fail.error="Invalid action"
 if not action.get("type") is String: return fail
 if state.phase in ["won","lost"]: fail.error="Run is finished"; return fail
 var s = _normalize(state)
 var events = []
 var error = _apply(s,action,events)
 if error!="": fail.error=error; return fail
 return {"state":s,"events":events,"error":""}

static func _apply(s: Dictionary, a: Dictionary, events: Array) -> String:
 match a.type:
  "SELECT_BLIND":
   if s.phase!="blind_select": return "Not selecting a blind"
   for i in range(s.draw_ids.size()-1,0,-1):
    var j = _rand(s,i+1)
    var tmp = s.draw_ids[i]
    s.draw_ids[i]=s.draw_ids[j]
    s.draw_ids[j]=tmp
   s.phase="playing"
   _refill(s)
  "PLAY", "DISCARD":
   if s.phase!="playing": return "Not playing"
   if not _ids_ok(a.get("ids"),s.hand_ids,1,5): return "Select one to five distinct held cards"
   if a.type=="DISCARD" and s.discards_left<=0: return "No discards left"
   if a.type=="PLAY":
    var score = preview(s,a.ids)
    if score.error!="": return score.error
    s.round_score+=score.total
    s.hands_left-=1
    s.played_categories.append(score.category)
    events.append({"type":"score","category":score.category,"chips":score.chips,"mult":score.mult,"total":score.total,"blocked":score.blocked})
    if not score.blocked:
     for m in s.modifiers:
      if m.id=="growth": m.stored+=3
   else: s.discards_left-=1
   for id in a.ids:
    s.hand_ids.erase(id)
    s.used_ids.append(id)
   _refill(s)
   if a.type=="PLAY":
    if s.round_score>=s.target:
     var interest = mini(int(s.money)/5,5)
     var reward = (8 if s.ante==8 and s.round==2 else 3+int(s.round))+int(s.hands_left)+interest
     for m in s.modifiers:
      if m.id=="wage": reward+=3
     s.money+=reward
     s.rounds_won+=1
     s.history.append({"ante":s.ante,"round":s.round,"score":s.round_score,"reward":reward,"interest":interest})
     events.append({"type":"reward","money":reward,"interest":interest})
     s.phase="won" if s.ante==8 and s.round==2 else "shop"
     s.reroll_cost=5
     if s.phase=="shop": _shop(s)
    elif s.hands_left==0 or s.hand_ids.is_empty(): s.phase="lost"
  "NEXT":
   if s.phase!="shop": return "Not in shop"
   s.round+=1
   if s.round==3: s.round=0; s.ante+=1
   s.phase="blind_select"
   s.shop=[]
   _prepare(s)
  "BUY":
   if s.phase!="shop": return "Not in shop"
   if not _integer(a.get("slot"),0,s.shop.size()-1): return "Invalid shop slot"
   var item = s.shop[int(a.slot)]
   var inventory = s.modifiers if item.kind=="modifier" else s.consumables
   if inventory.size()>=(5 if item.kind=="modifier" else 2): return "Inventory full"
   if s.money<item.cost: return "Not enough money"
   if item.kind=="modifier":
    for m in s.modifiers:
     if m.id==item.id: return "Already owned"
   s.money-=int(item.cost)
   var bought = item.duplicate(true)
   bought.erase("kind")
   inventory.append(bought)
   s.shop.remove_at(int(a.slot))
  "SELL":
   if s.phase!="shop": return "Sell in the shop"
   if not _integer(a.get("index"),0,s.modifiers.size()-1): return "Invalid modifier index"
   s.money+=maxi(1,int(s.modifiers[int(a.index)].cost)/2)
   s.modifiers.remove_at(int(a.index))
  "REROLL":
   if s.phase!="shop": return "Not in shop"
   if s.money<s.reroll_cost: return "Not enough money"
   s.money-=int(s.reroll_cost)
   s.reroll_cost+=1
   _shop(s)
  "REORDER":
   var ids = []
   for m in s.modifiers: ids.append(m.id)
   if not _ids_ok(a.get("ids"),ids,ids.size(),ids.size()): return "Provide each owned modifier once"
   var ordered = []
   for id in a.ids:
    for m in s.modifiers:
     if m.id==id: ordered.append(m)
   s.modifiers=ordered
  "USE":
   if not s.phase in ["playing","shop"]: return "Use items during play or shop"
   if not _integer(a.get("index"),0,s.consumables.size()-1): return "Invalid consumable index"
   var id = s.consumables[int(a.index)].id
   if id.begins_with("study_"):
    if not a.get("targets",[]) is Array or not a.get("targets",[]).is_empty(): return "Study needs no targets"
    s.levels[id.trim_prefix("study_")]+=1
   else:
    var allowed = s.hand_ids.duplicate()
    if s.phase=="shop":
     allowed=[]
     for c in s.deck: allowed.append(c.id)
    if not _ids_ok(a.get("targets"),allowed,1,1): return "Choose one valid card"
    var c = _card(s,a.targets[0])
    match id:
     "scarlet_dye": c.suit=1
     "ink_dye": c.suit=0
     "rank_lift": c.rank=2 if c.rank==14 else int(c.rank)+1
     "chip_etching": c.bonus_chips=20
     "prune":
      if s.deck.size()<=8: return "Keep at least eight cards"
      s.deck.erase(c)
      s.hand_ids.erase(c.id)
      s.draw_ids.erase(c.id)
      s.used_ids.erase(c.id)
      if s.phase=="playing": _refill(s)
   s.consumables.remove_at(int(a.index))
  _: return "Unknown action"
 events.append({"type":"action","action":a.type})
 return ""

static func _normalize(v: Variant) -> Variant:
 if v is float: return int(v)
 if v is Array:
  var out = []
  for item in v: out.append(_normalize(item))
  return out
 if v is Dictionary:
  var out = {}
  for key in v: out[key]=_normalize(v[key])
  return out
 return v

static func _integer(v: Variant, lo: int, hi: int) -> bool:
 return (v is int or v is float) and is_finite(float(v)) and float(v)==floor(float(v)) and v>=lo and v<=hi

static func validate_save(s: Dictionary) -> bool:
 for k in ["version","seed","rng_state","phase","ante","round","money","deck","draw_ids","hand_ids","used_ids","hands_left","discards_left","round_score","target","boss","levels","modifiers","consumables","shop","reroll_cost","history","played_categories","last_boss","rounds_won"]:
  if not s.has(k): return false
 if not _integer(s.version,1,1) or not _integer(s.seed,-2147483646,2147483646) or not _integer(s.rng_state,1,2147483646): return false
 if not s.phase is String or not s.phase in ["blind_select","playing","shop","won","lost"]: return false
 for spec in [["ante",1,8],["round",0,2],["money",0,1000000000],["hands_left",0,4],["discards_left",0,3],["round_score",0,1000000000000],["target",1,1000000000],["reroll_cost",5,1000000],["rounds_won",0,24]]:
  if not _integer(s[spec[0]],spec[1],spec[2]): return false
 for k in ["deck","draw_ids","hand_ids","used_ids","modifiers","consumables","shop","history","played_categories"]:
  if not s[k] is Array: return false
 if not s.boss is Dictionary or not s.levels is Dictionary or not s.last_boss is String: return false
 if s.last_boss!="" and not BOSSES.has(s.last_boss): return false
 if s.deck.size()<8 or s.deck.size()>52 or s.hand_ids.size()>8 or s.modifiers.size()>5 or s.consumables.size()>2 or s.shop.size()>3: return false
 var ids = []
 for c in s.deck:
  if not c is Dictionary or not c.get("id") is String or c.id.is_empty() or c.id in ids: return false
  if not _integer(c.get("rank"),2,14) or not _integer(c.get("suit"),0,3) or not _integer(c.get("bonus_chips"),0,20): return false
  if not int(c.bonus_chips) in [0,20]: return false
  ids.append(c.id)
 var zones = s.draw_ids+s.hand_ids+s.used_ids
 if not _ids_ok(zones,ids,ids.size(),ids.size()): return false
 if s.levels.size()!=HANDS.size(): return false
 for k in HANDS:
  if not _integer(s.levels.get(k),1,1000000): return false
 var owned = []
 for m in s.modifiers:
  if not _valid_item(m,true) or m.id in owned or not _integer(m.get("stored"),0,1000000): return false
  owned.append(m.id)
 for c in s.consumables:
  if not _valid_item(c,false): return false
 var offers = []
 for c in s.shop:
  if not c is Dictionary or not c.get("kind") in ["modifier","consumable"]: return false
  if not _valid_item(c,c.kind=="modifier"): return false
  if c.kind=="modifier" and not _integer(c.get("stored"),0,1000000): return false
  if c.id in offers: return false
  offers.append(c.id)
 for cat in s.played_categories:
  if not cat is String or not HANDS.has(cat): return false
 if s.played_categories.size()!=4-int(s.hands_left): return false
 if s.boss.is_empty():
  if s.round==2: return false
 else:
  if s.round!=2 or not s.boss.get("id") is String or not BOSSES.has(s.boss.id): return false
  if s.boss.get("name")!=BOSSES[s.boss.id][0] or s.boss.get("description")!=BOSSES[s.boss.id][1]: return false
  if (s.ante==8)!=(s.boss.id=="basalt_crown"): return false
 if s.history.size()!=s.rounds_won: return false
 for i in range(s.history.size()):
  var h = s.history[i]
  if not h is Dictionary or h.get("ante")!=i/3+1 or h.get("round")!=i%3: return false
  for k in ["score","reward","interest"]:
   if not _integer(h.get(k),0,1000000000000): return false
 var index = (int(s.ante)-1)*3+int(s.round)
 if int(s.rounds_won)!=index+(1 if s.phase in ["shop","won"] else 0): return false
 if s.boss.get("id","")=="dry_well" and s.discards_left!=0: return false
 if s.boss.get("id","")=="narrow_gate" and s.hand_ids.size()>7: return false
 if not s.phase in ["shop","won"] and not s.shop.is_empty(): return false
 if s.phase=="won" and (s.ante!=8 or s.round!=2 or s.round_score<s.target): return false
 if s.phase=="shop" and s.round_score<s.target: return false
 if s.phase=="playing" and (s.hands_left==0 or s.round_score>=s.target or s.hand_ids.is_empty()): return false
 if s.phase=="blind_select" and (not s.hand_ids.is_empty() or not s.used_ids.is_empty() or s.hands_left!=4 or s.round_score!=0): return false
 if s.phase=="lost" and (s.round_score>=s.target or (s.hands_left!=0 and not s.hand_ids.is_empty())): return false
 return true

static func _valid_item(v: Variant, is_modifier: bool) -> bool:
 if not v is Dictionary or not v.get("id") is String: return false
 var catalog = MODS if is_modifier else ITEMS
 if not catalog.has(v.id): return false
 var expected = modifier(v.id) if is_modifier else consumable(v.id)
 return v.get("name")==expected.name and v.get("description")==expected.description and _integer(v.get("cost"),expected.cost,expected.cost)
