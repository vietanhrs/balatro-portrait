class_name GameEngine
extends RefCounted
## Pure dictionary engine. RNG uses bounded Park-Miller integers, exactly JSON safe.
const VERSION = 2
const STANDARD_TARGETS = [300,800,2000,5000,11000,20000,35000,50000]
const VOUCHERS = {"extra_hand":["Long Shift","+1 hand each round."],"extra_discard":["Fresh Draft","+1 discard each round."],"extra_pocket":["Side Pocket","+1 consumable capacity."],"thrift":["Lean Market","Reroll base costs $2 less."]}
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
 "study_high_card":["Study High Card","Level up High Card."], "study_two_pair":["Study Two Pair","Level up Two Pair."], "study_three_of_a_kind":["Study Three","Level up Three of a Kind."], "study_full_house":["Study House","Level up Full House."], "study_four_of_a_kind":["Study Four","Level up Four of a Kind."], "study_straight_flush":["Study River Light","Level up Straight Flush."],
 "diamond_dye":["Amber Dye","Change one card to diamonds."], "club_dye":["Clover Dye","Change one card to clubs."], "rank_copy":["Rank Mirror","Copy source rank onto target; choose source then target."],
 "study_pair":["Study Pair","Level up Pair."], "study_flush":["Study Flush","Level up Flush."], "study_straight":["Study Straight","Level up Straight."],
 "scarlet_dye":["Scarlet Dye","Change one card to hearts."], "ink_dye":["Ink Dye","Change one card to spades."],
 "rank_lift":["Rank Lift","Raise one rank; ace wraps to two."], "chip_etching":["Chip Etching","Set one card's permanent bonus to 20 chips."], "prune":["Prune","Remove one card; keep at least eight."]}
const BOSSES = {
 "narrow_gate":["Narrow Gate","Draw a seven-card hand."], "full_assembly":["Full Assembly","Only plays of exactly five cards score."],
 "dry_well":["Dry Well","No discards this round."], "changing_signal":["Changing Signal","A category can score only on its first play."],
 "single_frequency":["Single Frequency","Only the first played category scores."], "basalt_crown":["Basalt Crown","Triple the ante target."]}

static func modifier(id: String) -> Dictionary:
 if not MODS.has(id): return {}
 return {"id":id,"name":MODS[id][0],"description":MODS[id][1],"cost":4 if MODS.keys().find(id)<13 else 6,"stored":0,"family":"passive","rarity":"common" if MODS.keys().find(id)<13 else "uncommon","stage":"on_score" if id in ["red","black","court","ace","even","odd"] else ("held" if id=="echo" else ("economy" if id=="wage" else "independent"))}

static func consumable(id: String) -> Dictionary:
 if not ITEMS.has(id): return {}
 return {"id":id,"name":ITEMS[id][0],"description":ITEMS[id][1],"cost":3 if id.begins_with("study_") else 4,"family":"planet" if id.begins_with("study_") else "tarot","target_count":0 if id.begins_with("study_") else (2 if id=="rank_copy" else 1)}

static func _rand(s: Dictionary, n: int) -> int:
 s.rng_state = (int(s.rng_state)*48271)%2147483647
 return int(s.rng_state)%n

static func new_run(seed: int, mode: String="practice") -> Dictionary:
 var s = {"version":VERSION,"seed":seed%2147483647,"rng_state":posmod(seed,2147483646)+1,"phase":"blind_select","ante":1,"round":0,"money":4,"deck":[],"draw_ids":[],"hand_ids":[],"used_ids":[],"hands_left":4,"discards_left":3,"round_score":0,"target":TARGETS[0],"boss":{},"levels":{},"modifiers":[],"consumables":[],"shop":[],"reroll_cost":5,"history":[],"played_categories":[],"last_boss":"","rounds_won":0}
 if not mode in ["practice","standard"]: return {}
 s.merge({"mode":mode,"ante_blinds":[],"tags":[],"hands_per_round":4,"discards_per_round":3,"hand_size":8,"passive_capacity":5,"consumable_capacity":2,"hands_played_this_round":0,"receipt":{},"voucher_offer":{},"purchased_vouchers":[],"pack_offers":[],"pack_state":{},"next_instance_id":1,"action_seq":0})
 for suit in range(4):
  for rank in range(2,15):
   s.deck.append({"id":"c%d_%d"%[suit,rank],"rank":rank,"suit":suit,"bonus_chips":0})
   s.draw_ids.append("c%d_%d"%[suit,rank])
 for k in HANDS: s.levels[k]=1
 _route(s)
 _prepare(s)
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
 s=_normalize(s)
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
 var timeline=[]
 _score_event(timeline,"score_base","base",cat,"","set",0,0,chips,mult,{"category":cat,"level":level+1})
 for c in cards:
  if not c.id in out.scoring_ids: continue
  var prior_chips=chips
  var prior_mult=mult
  chips += (11 if c.rank==14 else mini(int(c.rank),10))+int(c.bonus_chips)
  _score_event(timeline,"card_chips","card",c.id,c.id,"add",prior_chips,prior_mult,chips,mult,c)
  for m in s.modifiers:
   prior_chips=chips
   prior_mult=mult
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
   if chips!=prior_chips or mult!=prior_mult: _score_event(timeline,"passive_score","on_score",m.get("instance_id",m.id),c.id,"add",prior_chips,prior_mult,chips,mult,m)
 for id in s.hand_ids:
  if id in card_ids: continue
  for m in s.modifiers:
   if m.id=="echo" and _card(s,id).rank==14:
    _score_event(timeline,"held_mult","held",m.get("instance_id",m.id),id,"add",chips,mult,chips,mult+2,m)
    mult+=2
 for m in s.modifiers:
  var prior_chips=chips
  var prior_mult=mult
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
    if s.hands_played_this_round==0: mult*=1.75
   "last":
    if s.hands_left==1: mult*=2.5
   "compact":
    if card_ids.size()<=3: mult*=1.5
   "bank": mult+=mini(int(s.money)/5,6)*2
   "growth": chips+=int(m.stored)
  if chips!=prior_chips or mult!=prior_mult: _score_event(timeline,"passive_mult","independent",m.get("instance_id",m.id),"","multiply" if m.id in ["first","last","compact"] else "add",prior_chips,prior_mult,chips,mult,m)
 var blocked = false
 match s.boss.get("id",""):
  "full_assembly": blocked=card_ids.size()!=5
  "changing_signal": blocked=cat in s.played_categories
  "single_frequency": blocked=not s.played_categories.is_empty() and cat!=s.played_categories[0]
 out.chips=chips
 out.mult=mult
 out.total=0 if blocked else int(floor(chips*mult))
 out["blocked"]=blocked
 _score_event(timeline,"score_total","total",cat,"","multiply",chips,mult,chips,mult,{"blocked":blocked})
 timeline[-1].after.total=out.total
 out["timeline"]=timeline
 return out

static func _refill(s: Dictionary) -> void:
 var size = 7 if s.boss.get("id","")=="narrow_gate" else int(s.hand_size)
 while s.hand_ids.size()<size and not s.draw_ids.is_empty(): s.hand_ids.append(s.draw_ids.pop_back())

static func dispatch(state: Dictionary, action: Dictionary) -> Dictionary:
 var fail = {"state":state,"events":[],"error":"Invalid state"}
 if not validate_save(state): return fail
 fail.error="Invalid action"
 if not action.get("type") is String: return fail
 if state.phase in ["won","lost"]: fail.error="Run is finished"; return fail
 var s = _normalize(state)
 var ordered_levels={}
 for category in HANDS: ordered_levels[category]=s.levels[category]
 s.levels=ordered_levels
 var events = []
 var error = _apply(s,action,events)
 if error!="": fail.error=error; return fail
 s.action_seq+=1
 for i in range(events.size()):
  var e=events[i]
  e.merge({"seq":s.action_seq*1000+i,"stage":"action","source_id":"","target_id":"","operation":"set","before":{},"after":{},"delta":{},"label":e.type},false)
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
    events.append_array(score.timeline)
    events.append({"type":"round_total","stage":"round","before":{"total":s.round_score},"after":{"total":s.round_score+score.total},"delta":{"total":score.total}})
    s.round_score+=score.total
    s.hands_left-=1
    s.hands_played_this_round+=1
    s.played_categories.append(score.category)
    events.append({"type":"score","category":score.category,"chips":score.chips,"mult":score.mult,"total":score.total,"blocked":score.blocked})
    if not score.blocked:
     for m in s.modifiers:
      if m.id=="growth":
       events.append({"type":"growth","stage":"after_hand","source_id":m.get("instance_id",m.id),"before":{"stored":m.stored},"after":{"stored":m.stored+3},"delta":{"stored":3}})
       m.stored+=3
   else: s.discards_left-=1
   for id in a.ids:
    s.hand_ids.erase(id)
    s.used_ids.append(id)
   _refill(s)
   if a.type=="PLAY":
    if s.round_score>=s.target:
     var interest = mini(int(s.money)/5,5)
     var lines=[{"id":"blind","label":"Blind reward","amount":8 if s.ante==8 and s.round==2 else 3+int(s.round)},{"id":"hands","label":"Unused hands","amount":s.hands_left},{"id":"interest","label":"Interest","amount":interest}]
     for m in s.modifiers:
      if m.id=="wage": lines.append({"id":m.get("instance_id",m.id),"label":m.name,"amount":3})
     var reward=0
     for line in lines: reward+=int(line.amount)
     s.receipt={"line_items":lines,"money_before":s.money,"interest_base":s.money,"interest_cap":5,"total":reward,"money_after":s.money+reward,"paid":false}
     s.phase="cashout"
     events.append({"type":"receipt","stage":"receipt","before":{"money":s.money},"after":s.receipt.duplicate(true)})
    elif s.hands_left==0 or s.hand_ids.is_empty(): s.phase="lost"
  "NEXT":
   if s.phase!="shop": return "Not in shop"
   _advance(s)
  "BUY":
   if s.phase!="shop": return "Not in shop"
   a=a.duplicate(true)
   if a.has("offer_id"): a["slot"]=_find(s.shop,"offer_id",a.offer_id)
   if not _integer(a.get("slot"),0,s.shop.size()-1): return "Invalid shop slot"
   var item = s.shop[int(a.slot)]
   var inventory = s.modifiers if item.kind=="modifier" else s.consumables
   if inventory.size()>=(s.passive_capacity if item.kind=="modifier" else s.consumable_capacity): return "Inventory full"
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
   if not s.phase in ["shop","pack_select"]: return "Sell in the shop"
   a=a.duplicate(true)
   if a.has("instance_id"): a["index"]=_find(s.modifiers,"instance_id",a.instance_id)
   if not _integer(a.get("index"),0,s.modifiers.size()-1): return "Invalid modifier index"
   s.money+=maxi(1,int(s.modifiers[int(a.index)].cost)/2)
   s.modifiers.remove_at(int(a.index))
  "REROLL":
   if s.phase!="shop": return "Not in shop"
   if s.money<s.reroll_cost: return "Not enough money"
   s.money-=int(s.reroll_cost)
   s.reroll_cost=(3 if "thrift" in s.purchased_vouchers else 5) if s.reroll_cost==0 else s.reroll_cost+1
   _shop(s)
  "REORDER":
   var ids = []
   var durable=not a.get("ids",[]).is_empty() and str(a.ids[0]).begins_with("i")
   for m in s.modifiers: ids.append(m.get("instance_id",m.id) if durable else m.id)
   if not _ids_ok(a.get("ids"),ids,ids.size(),ids.size()): return "Provide each owned modifier once"
   var ordered = []
   for id in a.ids:
    for m in s.modifiers:
     if (m.get("instance_id",m.id) if durable else m.id)==id: ordered.append(m)
   s.modifiers=ordered
  "USE":
   if not s.phase in ["playing","shop"]: return "Use items during play or shop"
   a=a.duplicate(true)
   if a.has("instance_id"): a["index"]=_find(s.consumables,"instance_id",a.instance_id)
   if not _integer(a.get("index"),0,s.consumables.size()-1): return "Invalid consumable index"
   var allowed=s.hand_ids.duplicate()
   if s.phase=="shop":
    allowed=[]
    for c in s.deck: allowed.append(c.id)
   var err=_use(s,s.consumables[int(a.index)].id,a.get("targets",[]),allowed,events)
   if err!="": return err
   s.consumables.remove_at(int(a.index))
  "CANCEL_TARGET":
   if not s.phase in ["playing","shop","pack_select"]: return "No targeting here"
  "CASH_OUT":
   if s.phase!="cashout" or s.receipt.get("paid",true): return "No unpaid receipt"
   s.money+=int(s.receipt.total)
   s.receipt.paid=true
   s.rounds_won+=1
   s.history.append({"ante":s.ante,"round":s.round,"outcome":"won","score":s.round_score,"reward":s.receipt.total,"interest":mini(int(s.receipt.interest_base)/5,5)})
   s.ante_blinds[int(s.round)].status="won"
   events.append({"type":"cash_out","stage":"receipt","before":{"money":s.receipt.money_before},"after":{"money":s.money},"delta":{"money":s.receipt.total}})
   if s.ante==8 and s.round==2: s.phase="won"
   else: _enter_shop(s)
  "SKIP_BLIND":
   if s.phase!="blind_select" or s.round==2: return "Only Small and Big may be skipped"
   var effect=s.ante_blinds[int(s.round)].tag
   s.tags.append({"id":_uid(s),"effect":effect,"status":"consumed" if effect=="cash" else "queued"})
   if effect=="cash": s.money+=5
   s.ante_blinds[int(s.round)].status="skipped"
   s.history.append({"ante":s.ante,"round":s.round,"outcome":"skipped","score":0,"reward":0,"interest":0})
   _advance(s)
  "BUY_VOUCHER":
   if s.phase!="shop" or s.voucher_offer.is_empty() or s.voucher_offer.purchased: return "Voucher unavailable"
   if a.has("offer_id") and a.offer_id!=s.voucher_offer.offer_id: return "Invalid voucher"
   if s.money<10: return "Not enough money"
   s.money-=10
   var id=s.voucher_offer.id
   s.purchased_vouchers.append(id)
   s.voucher_offer.purchased=true
   match id:
    "extra_hand": s.hands_per_round+=1
    "extra_discard": s.discards_per_round+=1
    "extra_pocket": s.consumable_capacity+=1
    "thrift": s.reroll_cost=maxi(0,int(s.reroll_cost)-2)
  "OPEN_PACK":
   if s.phase!="shop": return "Not in shop"
   var index=_find(s.pack_offers,"offer_id",a.get("offer_id"))
   if index<0: return "Invalid pack offer"
   var pack=s.pack_offers[index]
   if s.money<pack.cost: return "Not enough money"
   s.money-=int(pack.cost)
   var options=[]
   for i in range(int(pack.count)):
    var item={}
    if pack.family=="playing_card": item={"id":_uid(s),"rank":2+_rand(s,13),"suit":_rand(s,4),"bonus_chips":0,"family":"playing_card"}
    else: item=_instance(s,_family_item(s,pack.family))
    item["option_id"]=_uid(s)
    options.append(item)
   var targets=[]
   var pool=[]
   for c in s.deck: pool.append(c.id)
   if pack.family=="tarot":
    for i in range(mini(s.hand_size,pool.size())): targets.append(pool.pop_at(_rand(s,pool.size())))
   s.pack_state={"offer_id":pack.offer_id,"family":pack.family,"options":options,"remaining":1,"target_ids":targets,"seed":s.rng_state}
   s.pack_offers.remove_at(index)
   s.phase="pack_select"
  "CHOOSE_PACK":
   if s.phase!="pack_select": return "No open pack"
   var index=_find(s.pack_state.options,"option_id",a.get("option_id"))
   if index<0: return "Invalid pack option"
   var item=s.pack_state.options[index].duplicate(true)
   match s.pack_state.family:
    "passive":
     if s.modifiers.size()>=s.passive_capacity: return "Passive slots full; sell or skip"
     for m in s.modifiers:
      if m.id==item.id: return "Already owned"
     item.erase("option_id")
     s.modifiers.append(item)
    "playing_card":
     item.erase("option_id")
     item.erase("family")
     s.deck.append(item)
     s.draw_ids.append(item.id)
    _:
     var err=_use(s,item.id,a.get("targets",[]),s.pack_state.target_ids,events)
     if err!="": return err
   s.pack_state={}
   s.phase="shop"
  "SKIP_PACK":
   if s.phase!="pack_select": return "No open pack"
   s.pack_state={}
   s.phase="shop"
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

static func _valid_item(v: Variant, is_modifier: bool) -> bool:
 if not v is Dictionary or not v.get("id") is String: return false
 var catalog = MODS if is_modifier else ITEMS
 if not catalog.has(v.id): return false
 var expected = modifier(v.id) if is_modifier else consumable(v.id)
 return v.get("name")==expected.name and v.get("description")==expected.description and _integer(v.get("cost"),expected.cost,expected.cost)

static func _uid(s: Dictionary) -> String:
 var id="i%d"%s.next_instance_id
 s.next_instance_id+=1
 return id

static func _instance(s: Dictionary, item: Dictionary) -> Dictionary:
 item["instance_id"]=_uid(s)
 return item

static func _family_item(s: Dictionary, family: String) -> Dictionary:
 if family=="passive":
  var available=MODS.keys()
  for m in s.modifiers: available.erase(m.id)
  return modifier(available[_rand(s,available.size())])
 var choices=[]
 for id in ITEMS:
  if id.begins_with("study_")==(family=="planet"): choices.append(id)
 return consumable(choices[_rand(s,choices.size())])

static func _shop(s: Dictionary) -> void:
 s.erase("legacy_shop")
 s.shop=[]
 for i in range(2):
  var roll=_rand(s,28)
  var family="passive" if roll<20 else ("tarot" if roll<24 else "planet")
  var item=_instance(s,_family_item(s,family))
  item["kind"]="modifier" if family=="passive" else "consumable"
  item["offer_id"]=item.instance_id
  s.shop.append(item)

static func _pack_offer(s: Dictionary, family: String, cost: int=4) -> Dictionary:
 return {"offer_id":_uid(s),"family":family,"name":family.capitalize()+" Parcel","cost":cost,"choose":1,"count":2 if family=="passive" else 3}

static func _enter_shop(s: Dictionary) -> void:
 s.phase="shop"
 s.reroll_cost=3 if "thrift" in s.purchased_vouchers else 5
 _shop(s)
 s.pack_offers=[]
 for i in range(2): s.pack_offers.append(_pack_offer(s,["passive","planet","tarot","playing_card"][_rand(s,4)]))
 for tag in s.tags:
  if tag.status!="queued": continue
  if tag.effect=="free_reroll": s.reroll_cost=0
  if tag.effect=="free_planet": s.pack_offers.append(_pack_offer(s,"planet",0))
  tag.status="consumed"

static func _route(s: Dictionary) -> void:
 var choices=BOSSES.keys().slice(0,5)
 choices.erase(s.last_boss)
 var id="basalt_crown" if s.ante==8 else choices[_rand(s,choices.size())]
 s.last_boss=id
 s.ante_blinds=[]
 for r in range(3):
  var base=(STANDARD_TARGETS if s.mode=="standard" else TARGETS)[int(s.ante)-1]
  s.ante_blinds.append({"round":r,"name":["Small","Big","Boss"][r],"target":int(base*([1.0,1.5,3.0 if s.ante==8 else 2.0][r])),"boss":{"id":id,"name":BOSSES[id][0],"description":BOSSES[id][1]} if r==2 else {},"status":"available" if r==s.round else "locked","tag":["cash","free_reroll","free_planet"][_rand(s,3)] if r<2 else ""})
 var available=VOUCHERS.keys()
 for v in s.purchased_vouchers: available.erase(v)
 s.voucher_offer={}
 if not available.is_empty():
  var v=available[_rand(s,available.size())]
  s.voucher_offer={"id":v,"name":VOUCHERS[v][0],"description":VOUCHERS[v][1],"cost":10,"offer_id":_uid(s),"purchased":false}

static func _prepare(s: Dictionary) -> void:
 s.boss=s.ante_blinds[int(s.round)].boss.duplicate(true)
 s.target=s.ante_blinds[int(s.round)].target
 s.hands_left=s.hands_per_round
 s.hands_played_this_round=0
 s.discards_left=0 if s.boss.get("id","")=="dry_well" else s.discards_per_round
 s.round_score=0
 s.played_categories=[]
 s.hand_ids=[]
 s.used_ids=[]
 s.draw_ids=[]
 for c in s.deck: s.draw_ids.append(c.id)

static func _advance(s: Dictionary) -> void:
 s.round+=1
 if s.round==3:
  s.round=0
  s.ante+=1
  _route(s)
 s.ante_blinds[int(s.round)].status="available"
 s.phase="blind_select"
 s.erase("legacy_shop")
 s.shop=[]
 s.pack_offers=[]
 s.receipt={}
 _prepare(s)

static func _find(items: Array, key: String, value: Variant) -> int:
 for i in range(items.size()):
  if items[i].get(key)==value: return i
 return -1

static func _use(s: Dictionary, id: String, targets: Variant, allowed: Array, events: Array) -> String:
 if id.begins_with("study_"):
  if not targets is Array or not targets.is_empty(): return "Study needs no targets"
  var cat=id.trim_prefix("study_")
  var level=int(s.levels[cat])
  var h=HANDS[cat]
  s.levels[cat]+=1
  events.append({"type":"hand_upgrade","stage":"upgrade","source_id":id,"target_id":cat,"before":{"level":level,"chips":h[0]+(level-1)*h[2],"mult":h[1]+(level-1)*h[3]},"after":{"level":level+1,"chips":h[0]+level*h[2],"mult":h[1]+level*h[3]}})
  return ""
 var count=2 if id=="rank_copy" else 1
 if not _ids_ok(targets,allowed,count,count): return "Choose %d valid distinct target cards"%count
 var c=_card(s,targets[-1])
 var before=c.duplicate(true)
 match id:
  "scarlet_dye": c.suit=1
  "ink_dye": c.suit=0
  "diamond_dye": c.suit=2
  "club_dye": c.suit=3
  "rank_copy": c.rank=_card(s,targets[0]).rank
  "rank_lift": c.rank=2 if c.rank==14 else int(c.rank)+1
  "chip_etching": c.bonus_chips=20
  "prune":
   if s.deck.size()<=8: return "Keep at least eight cards"
   s.deck.erase(c)
   s.hand_ids.erase(c.id)
   s.draw_ids.erase(c.id)
   s.used_ids.erase(c.id)
   if s.phase=="playing": _refill(s)
 events.append({"type":"card_mutation","stage":"mutation","source_id":id,"target_id":c.id,"before":before,"after":{} if id=="prune" else c.duplicate(true)})
 return ""

static func validate_save(s: Dictionary) -> bool:
 return _validate_state(_normalize_integral(s))

static func _normalize_integral(v: Variant) -> Variant:
 if v is float and is_finite(v) and v==floor(v): return int(v)
 if v is Array:
  var out=[]
  for item in v: out.append(_normalize_integral(item))
  return out
 if v is Dictionary:
  var out={}
  for key in v: out[key]=_normalize_integral(v[key])
  return out
 return v

static func _validate_state(s: Dictionary) -> bool:
 for k in ["version","seed","rng_state","phase","ante","round","money","deck","draw_ids","hand_ids","used_ids","hands_left","discards_left","round_score","target","boss","levels","modifiers","consumables","shop","reroll_cost","history","played_categories","last_boss","rounds_won","mode","ante_blinds","tags","hands_per_round","discards_per_round","hand_size","passive_capacity","consumable_capacity","hands_played_this_round","receipt","voucher_offer","purchased_vouchers","pack_offers","pack_state","next_instance_id","action_seq"]:
  if not s.has(k): return false
 if not _integer(s.version,2,2) or not _integer(s.seed,-2147483646,2147483646) or not _integer(s.rng_state,1,2147483646): return false
 if not s.phase is String or not s.phase in ["blind_select","playing","cashout","shop","pack_select","won","lost"]: return false
 for spec in [["ante",1,8],["round",0,2],["money",0,1000000000],["hands_left",0,5],["discards_left",0,4],["round_score",0,1000000000000],["target",1,1000000000],["reroll_cost",0,1000000],["rounds_won",0,24]]:
  if not _integer(s[spec[0]],spec[1],spec[2]): return false
 for k in ["deck","draw_ids","hand_ids","used_ids","modifiers","consumables","shop","history","played_categories"]:
  if not s[k] is Array: return false
 if not s.boss is Dictionary or not s.levels is Dictionary or not s.last_boss is String: return false
 if s.last_boss!="" and not BOSSES.has(s.last_boss): return false
 if s.deck.size()<8 or s.deck.size()>256 or s.hand_ids.size()>8 or s.modifiers.size()>5 or s.consumables.size()>int(s.consumable_capacity) or s.shop.size()>(3 if s.get("legacy_shop",false) == true else 2): return false
 if s.has("legacy_shop") and (not s.legacy_shop is bool or (s.legacy_shop and not s.phase in ["shop","pack_select","won"])): return false
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
  offers.append(c.id)
 for cat in s.played_categories:
  if not cat is String or not HANDS.has(cat): return false
 if s.played_categories.size()!=s.hands_played_this_round: return false
 if s.boss.is_empty():
  if s.round==2: return false
 else:
  if s.round!=2 or not s.boss.get("id") is String or not BOSSES.has(s.boss.id): return false
  if s.boss.get("name")!=BOSSES[s.boss.id][0] or s.boss.get("description")!=BOSSES[s.boss.id][1]: return false
  if (s.ante==8)!=(s.boss.id=="basalt_crown"): return false
 var victories=0
 for i in range(s.history.size()):
  var h = s.history[i]
  if not h is Dictionary or h.get("ante")!=i/3+1 or h.get("round")!=i%3: return false
  if not h.get("outcome") in ["won","skipped"] or (h.outcome=="skipped" and h.round==2): return false
  if h.outcome=="won": victories+=1
  for k in ["score","reward","interest"]:
   if not _integer(h.get(k),0,1000000000000): return false
 var index = (int(s.ante)-1)*3+int(s.round)
 if victories!=s.rounds_won or s.history.size()!=index+(1 if s.phase in ["shop","pack_select","won"] else 0): return false
 if s.boss.get("id","")=="dry_well" and s.discards_left!=0: return false
 if s.boss.get("id","")=="narrow_gate" and s.hand_ids.size()>7: return false
 if not s.phase in ["shop","pack_select","won"] and not s.shop.is_empty(): return false
 if s.phase=="won" and (s.ante!=8 or s.round!=2 or s.round_score<s.target): return false
 if s.phase in ["cashout","shop","pack_select"] and s.round_score<s.target: return false
 if s.phase=="playing" and (s.hands_left==0 or s.round_score>=s.target or s.hand_ids.is_empty()): return false
 if s.phase=="blind_select" and (not s.hand_ids.is_empty() or not s.used_ids.is_empty() or s.hands_left!=s.hands_per_round or s.round_score!=0): return false
 if s.phase=="lost" and (s.round_score>=s.target or (s.hands_left!=0 and not s.hand_ids.is_empty())): return false
 if not _validate_v2(s): return false
 return true


static func _validate_v2(s: Dictionary) -> bool:
 if not s.mode in ["practice","standard"]: return false
 for spec in [["hands_per_round",4,5],["discards_per_round",3,4],["hand_size",8,8],["passive_capacity",5,5],["consumable_capacity",2,3],["hands_played_this_round",0,5],["next_instance_id",1,1000000000],["action_seq",0,1000000000]]:
  if not _integer(s[spec[0]],spec[1],spec[2]): return false
 for k in ["ante_blinds","tags","purchased_vouchers","pack_offers"]:
  if not s[k] is Array: return false
 for k in ["receipt","voucher_offer","pack_state"]:
  if not s[k] is Dictionary: return false
 var purchased=[]
 for id in s.purchased_vouchers:
  if not id is String or not VOUCHERS.has(id) or id in purchased: return false
  purchased.append(id)
 if s.hands_left>s.hands_per_round or s.discards_left>s.discards_per_round: return false
 if s.hands_per_round!=4+int("extra_hand" in purchased) or s.discards_per_round!=3+int("extra_discard" in purchased) or s.consumable_capacity!=2+int("extra_pocket" in purchased): return false
 # During a shop purchase current-round counters still reflect the completed round.
 if s.phase in ["playing","blind_select","cashout","lost"] and s.hands_left+s.hands_played_this_round!=s.hands_per_round: return false
 if s.ante_blinds.size()!=3: return false
 for i in range(3):
  var b=s.ante_blinds[i]
  if not b is Dictionary or not b.get("name") is String or b.get("round")!=i or not b.get("boss") is Dictionary or not b.get("status") in ["available","locked","won","skipped"]: return false
  if not _integer(b.get("target"),1,1000000000) or not b.get("tag") in ["cash","free_reroll","free_planet",""]: return false
 for t in s.tags:
  if not t is Dictionary or not t.get("id") is String or not t.get("effect") in ["cash","free_reroll","free_planet"] or not t.get("status") in ["queued","consumed"]: return false
 if not s.voucher_offer.is_empty():
  var v=s.voucher_offer
  if not VOUCHERS.has(v.get("id","")) or v.get("cost")!=10 or not v.get("offer_id") is String or not v.get("purchased") is bool: return false
  if v.purchased!=(v.id in purchased): return false
 var unique=[]
 for c in s.deck: unique.append(c.id)
 for item in s.modifiers+s.consumables+s.shop:
  if not item.get("instance_id") is String or item.instance_id in unique: return false
  unique.append(item.instance_id)
  if item.has("offer_id") and item.offer_id!=item.instance_id: return false
 for offer in s.pack_offers:
  if not offer is Dictionary or not offer.get("offer_id") is String or offer.offer_id in unique or not offer.get("family") in ["passive","planet","tarot","playing_card"]: return false
  unique.append(offer.offer_id)
  if not offer.get("cost") in [0,4] or offer.get("choose")!=1 or offer.get("count")!=(2 if offer.family=="passive" else 3): return false
 if s.phase=="cashout" or not s.receipt.is_empty():
  var r=s.receipt
  if not r.get("line_items") is Array or not r.get("paid") is bool: return false
  for k in ["money_before","money_after","interest_base","total"]:
   if not _integer(r.get(k),0,1000000000): return false
  var total=0
  for line in r.line_items:
   if not line is Dictionary or not _integer(line.get("amount"),0,1000000000): return false
   total+=int(line.amount)
  if total!=r.total or r.money_after!=r.money_before+r.total or r.get("interest_cap")!=5: return false
  if s.phase=="cashout":
   if r.paid or s.money!=r.money_before or r.interest_base!=r.money_before: return false
   var expected=[8 if s.ante==8 and s.round==2 else 3+int(s.round),int(s.hands_left),mini(int(s.money)/5,5)]
   for m in s.modifiers:
    if m.id=="wage": expected.append(3)
   if r.line_items.size()!=expected.size(): return false
   for i in range(expected.size()):
    if r.line_items[i].amount!=expected[i]: return false
  if s.phase in ["shop","pack_select","won"] and not r.paid: return false
 if (s.phase=="pack_select")!=not s.pack_state.is_empty(): return false
 if s.phase=="pack_select":
  var pack=s.pack_state
  if not pack.get("family") in ["passive","planet","tarot","playing_card"] or pack.get("remaining")!=1 or not pack.get("options") is Array or not pack.get("target_ids") is Array: return false
  if not _integer(pack.get("seed"),1,2147483646) or not pack.get("offer_id") is String: return false
  if pack.options.size()!=(2 if pack.family=="passive" else 3): return false
  var ids=[]
  for c in s.deck: ids.append(c.id)
  if not _ids_ok(pack.target_ids,ids,0,s.hand_size): return false
  for item in pack.options:
   if not item is Dictionary or not item.get("option_id") is String or item.option_id in unique: return false
   unique.append(item.option_id)
   if pack.family=="playing_card":
    if not item.get("id") is String or item.id in ids or not _integer(item.get("rank"),2,14) or not _integer(item.get("suit"),0,3) or item.get("bonus_chips")!=0: return false
    ids.append(item.id)
   else:
    if not _valid_item(item,pack.family=="passive") or not item.get("instance_id") is String or item.instance_id in unique: return false
    unique.append(item.instance_id)
    if pack.family=="passive" and not _integer(item.get("stored"),0,1000000): return false
    if item.get("family")!=pack.family: return false
 for id in unique:
  if id.begins_with("i") and (not id.substr(1).is_valid_int() or int(id.substr(1))>=s.next_instance_id): return false
 return true

static func migrate_save(input: Dictionary) -> Dictionary:
 if input.get("version")==2: return _normalize(input) if validate_save(input) else {}
 var old=preload("res://core/legacy_v1.gd")
 if not old.validate_save(_normalize_integral(input)): return {}
 var s=_normalize(input)
 var defaults=new_run(int(s.seed))
 for k in defaults:
  if not s.has(k): s[k]=defaults[k]
 s.version=2
 s.mode="practice"
 s.hands_played_this_round=4-int(s.hands_left)
 for h in s.history: h["outcome"]="won"
 for list in [s.modifiers,s.consumables,s.shop]:
  for item in list:
   var metadata=modifier(item.id) if MODS.has(item.id) else consumable(item.id)
   item.merge(metadata,false)
   _instance(s,item)
   if item.has("kind"): item["offer_id"]=item.instance_id
 # Compatibility shelf only for a strictly validated v1 shop; never drop offers.
 if s.shop.size()>2: s["legacy_shop"]=true
 var legacy_rng=s.rng_state
 _route(s)
 s.rng_state=legacy_rng
 if not s.boss.is_empty(): s.ante_blinds[2].boss=s.boss.duplicate(true)
 for h in s.history:
  if h.ante==s.ante: s.ante_blinds[int(h.round)].status="won"
 if not validate_save(s): return {}
 return s

static func _score_event(events: Array, type: String, stage: String, source: String, target: String, operation: String, bc: int, bm: float, ac: int, am: float, metadata: Dictionary) -> void:
 events.append({"seq":events.size(),"type":type,"stage":stage,"source_id":source,"target_id":target,"operation":operation,"before":{"chips":bc,"mult":bm,"total":int(floor(bc*bm))},"after":{"chips":ac,"mult":am,"total":int(floor(ac*am))},"delta":{"chips":ac-bc,"mult":am-bm},"label":metadata.get("name",type),"source":metadata.duplicate(true)})
