# Raster art v3 — stable integration interface

Original tactile copper/teal print suite. PNG, RGBA, straight alpha, no baked game labels except menu logo. All paths below relative to assets/v3/. Generator: tools/art_v3/generate.py.

- background.png, background_flow.png, background_grain.png: 512×512 seamless same-hue teal layers. Repeat enabled; drift UV slowly in different directions. Base opaque, flow/grain opaque: blend rather than alpha-overlay; restrained 0.1–0.2 mix.
- panel.png: 256×256, StyleBoxTexture margins L/T/R/B 24 px; dark teal textured inset.
- button.png: 256×96, margins 20 px all sides; copper textured action. Modulate for press/focus.
- card_front.png, card_back.png: 256×352, rounded transparent corners, margin 14; front blank for runtime rank/suit overlays. Do not nine-slice back ornament.
- logo.png: 768×256 transparent original VELVET CIRCUIT wordmark.
- items/passive/<engine_id>.png: twenty 192×256 individually illustrated prints.
- items/planet/<engine_id>.png: nine astronomical prints.
- items/tarot/<engine_id>.png: eight workshop/alchemical prints.
- items/voucher/<engine_id>.png: four embossed ticket prints.
- items/pack/<family>.png: passive, planet, tarot, playing_card foil packets.
- items_atlas.png: all item illustrations, with exact rects in manifest.json. Individual textures are alternative to atlas, not both required.

All item art reserves bottom 26 px decorative footer, no baked names: UI owns localized title/description and semantics. Fit illustration as whole card or use in upper art pane; do not rely on art for accessible identity. manifest.json includes `items[family][id]` path plus `atlas_rect`. Use family aliases modifier→passive, consumable→tarot only when actual engine family absent.

Only assets/v3 and tools/art_v3 are owned by art lane; no runtime integration performed here. Contact sheets are developer evidence, not runtime dependencies.
