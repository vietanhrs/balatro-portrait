# Core V2 frozen integration contract

`new_run(seed, mode="practice")`, `preview(state, ids)`, `dispatch(state, action) -> {state, events, error}`, `validate_save(state)`, `migrate_save(state) -> Dictionary` (empty on failure). Errors are atomic, including RNG. Default mode stays Practice.

Phases: blind_select, playing, cashout, shop, pack_select, won, lost. PLAY commits scoring and a pending receipt; CASH_OUT alone transfers receipt.total and enters shop/won. NEXT only leaves shop.

State retains v1 fields and adds mode, ante_blinds (three dictionaries with round/name/target/boss/status/tag), tags (id/effect/status), hands_per_round, discards_per_round, hand_size, passive_capacity, consumable_capacity, hands_played_this_round, receipt, voucher_offer, purchased_vouchers, pack_offers, pack_state, next_instance_id, action_seq. Items retain catalog `id`; durable `instance_id` and offers `offer_id` are unique strings.

Actions: SELECT_BLIND; SKIP_BLIND (current Small/Big only); PLAY/DISCARD {ids}; CASH_OUT; NEXT; BUY {offer_id} (legacy slot accepted); SELL {instance_id} (legacy index); REORDER {ids} (instance IDs or legacy catalog IDs); USE {instance_id,targets} (legacy index); REROLL; BUY_VOUCHER; OPEN_PACK {offer_id}; CHOOSE_PACK {option_id,targets}; SKIP_PACK. CANCEL_TARGET is a successful no-effect cancellation.

Shop: exactly two mixed offers when generated, kind modifier/consumable, family passive/planet/tarot. Purchased mixed offers removed. Two pack_offers with family passive/planet/tarot/playing_card, cost 4, choose 1, count 2 for passive otherwise 3. voucher_offer is {} if exhausted, otherwise id/name/description/cost/offer_id/purchased. Voucher IDs extra_hand, extra_discard, extra_pocket, thrift.

pack_state: {offer_id,family,options,remaining:1,target_ids,seed}. Options carry option_id; targeted tarot requires held temporary `target_ids` (dealt once on opening). CHOOSE_PACK planet/tarot applies immediately, passive inventory capacity enforced, playing_card adds a unique card. Choose/Skip returns to unchanged shop. Target order for rank_copy is [source,target]. Empty/malformed targets fail without mutation; cancel consumes nothing.

receipt: {line_items:[{id,label,amount}],money_before,interest_base,interest_cap:5,total,money_after,paid:false}. Kept with paid:true after cashout until NEXT. Tags effects cash/free_reroll/free_planet, status queued/consumed. Cash tag immediate; next-shop tags consumed on entry.

Timeline events share seq/type/stage/source_id/target_id/operation/before/after/delta/label; score values include chips/mult/total. Preview returns timeline without mutations; dispatch emits that timeline followed by round_total, growth, receipt and action. Event source metadata is included for removed-card presentation.

20 original passives; nine natural hand studies; eight mutations (four suits, rank lift, bonus, prune, rank copy). Not complete reference content. Standard targets 300/800/2000/5000/11000/20000/35000/50000; Practice prior curve. Final boss original ×3 exception.

## Integration examples and boundaries


    var s = GameEngine.new_run(1, "standard")
    var r = GameEngine.dispatch(s, {"type":"SELECT_BLIND"})
    var p = GameEngine.preview(r.state, r.state.hand_ids.slice(0, 2))
    # PLAY -> cashout: persist result before animating events.
    # CASH_OUT -> shop (or won at final boss); never auto-NEXT.
    # OPEN_PACK {offer_id}; CHOOSE_PACK {option_id, targets: []}.

Generated readable fixtures: core/fixture_route.json, fixture_playing.json, fixture_timeline.json, fixture_cashout.json, fixture_shop.json, fixture_pack_{passive,planet,tarot,playing_card}.json. These are explicit structural fixtures (cash/target edits), NOT honest balance evidence. Owned items must receive an instance via purchase/pack/migration; catalog constructors alone do not allocate run IDs.

CANCEL_TARGET changes only action_seq and emits action bookkeeping; it spends/consumes/rerolls nothing. Card mutations use source→target order for rank_copy. Pack targets are temporary card IDs referencing the deck, not a second ownership zone. Free planet tags add a bonus third pack offer rather than replacing a paid offer. Multiple free-reroll tags coalesce into one free first reroll (original bounded rule).

Migration: valid v1 states migrate as Practice, with preserved cards/money/levels/current round. A strictly validated v1 shop retains all three outstanding offers via a bounded legacy_shop compatibility shelf. Every offer still passes item/unique-ID validation; reroll and NEXT remove the compatibility flag and restore the ordinary two-slot contract. Platform archives the exact original envelope before writing v2; unrecoverable files require explicit archive/reset confirmation. v1 does not have a pending receipt; already paid shops stay paid. New ante preview/voucher is derived deterministically during migration while preserving the stored gameplay RNG. No claim of identical future v1 gameplay, since the new shop/content algorithms differ. legacy_v1.gd is retained solely for strict legacy validation, not a second playable mode.

Limits: 20 original passives; 17 consumables (nine natural-category studies, eight mutations); four normal packs; four run vouchers; six bosses; three tag effects. Altered-category studies, spectral, jumbo/mega, editions/seals and reference-complete content omitted. Deck safety bound 256 cards (normal finite-run purchases remain below this). Balance is not established; Standard intentionally keeps the reference baseline and may be harsh with this sparse catalog. Manual/Android/UI validation belongs to integrator and was not performed in core lane.
