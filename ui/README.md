# Portrait UI v2 — integration handoff

Entry: scenes/main.tscn → ui/main.gd. Reusable original vector cards: ui/table_card.gd. No video/game artwork, extracted textures, downloaded typefaces, or audio. Existing engine font only.

Implemented: fixed non-scrolling 360×640 table, green felt, cream cards with pips/geometric face markers, lifted outlined numbered selection, blue Chips/red Mult, orange primary actions. Route shows all three targets and persistent boss preview; skip confirmation explains tag. Practice/Standard selector. Five passive slots and separate consumable inventory control. Stable instance-ID buy/sell/reorder/use, capacity/funds explanations, voucher detail, separate pack selection, temporary-hand tarot targeting with ordered source/target, cancel without dispatch. Planet use shows old/new level and base. Cashout is a dedicated line-item receipt. Terminal remains engine-owned.

PLAY dispatches once, saves committed state through existing SaveStore before presentation, retains a pre-action snapshot, presents event values/deltas and source highlights, then renders committed phase. Skip and Back finish presentation without dispatch. Fast/reduced-motion available in menu (session preference, not persisted). Android Back signal and safe-area signal retained. Receipt/pack resumes use engine checkpoint, never regenerate choices in UI.

## Checks actually performed
- Godot 4.7.2 import/compile after fixing typed card label.
- tests/ui/smoke.gd: UI_SMOKE failures=0; uses reduced-motion for synchronous legacy assertions.
- tests/ui/redesign_transactions.gd: REDESIGN_TRANSACTIONS failures=0. Real seed 531: commit before presentation, disk equality, input lock, skip no duplicate action, real cashout, repeat cashout atomic, receipt/pack resume exact, Back preserves pack, pack skip returns shop. Run with isolated HOME/XDG_DATA_HOME.
- tests/ui/redesign_capture.gd: REDESIGN_VISUAL_FIXTURES failures=0; measures visible button minimum 48×48 and viewport bounds for table and overlays. Real route/hand plus clearly marked synthetic receipt/shop/pack fixtures; not a balance test.
- 18 final rendered images personally inspected: tests/ui/redesign-{360x640,430x932}-{route,playing,selected,scoring,receipt,shop,pack,detail,targeting}.png. No clipped hand/actions; family designs visually distinct; overlays keep Apply/Close fixed. See redesign-render-final.log.

## Integration and honest limits
No core/platform/project edits and no git operations. Git HEAD/log read directly; parent integrator must inspect/commit the shared working-tree diff. All owned files released on handoff.

No publication or Android build/test in this UI lane. Integrator must re-run Android safe-area, Back, force-stop/resume and APK export. Existing full-run tools/check_ui_run.gd assumes synchronous play and v1 transitions; adapt by setting reduced_motion=true and adding CASH_OUT actions (integrator-owned).

Motion is a bounded event-by-event snapshot presentation, not a full physics/tween choreography: source outline pulses replace elaborate flying-card effects; held-card source is represented by event label rather than a complete held-card tableau. Receipt accounting is immediate, not animated digit counting. Inventory uses accessible reorder arrows, not drag-and-drop. Target cancellation discards only transient UI selection; resume returns safely to the persisted pack, not the unfinished selection. UI deliberately does not claim complete reference-game parity or balance. Larger portrait screens add breathing room; illustrations are simple original geometric families.
