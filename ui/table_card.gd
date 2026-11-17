extends Button
## Runtime indices over original raster print skins; index strip remains exposed in overlap.
var data: Dictionary = {}
var family := "playing"
var order := -1
var compact := false
var artwork: TextureRect
const PAPER = Color("fff1d2")
const INK = Color("152d32")
func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for key in ["normal", "hover", "pressed", "disabled", "focus"]: add_theme_stylebox_override(key, StyleBoxEmpty.new())
	if family != "playing":
		var surround := TextureRect.new()
		surround.texture = preload("res://assets/v3/background.png")
		surround.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		surround.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		surround.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		surround.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(surround)
	artwork = TextureRect.new()
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_SCALE if family == "playing" else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(artwork)
	# Parent draw runs before children; indices live in a separate foreground Control.
	var indices := Control.new()
	indices.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	indices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indices.draw.connect(_draw_indices.bind(indices))
	add_child(indices)
	resized.connect(func(): indices.queue_redraw())
	draw.connect(func(): indices.queue_redraw())
	var art_family := family
	if art_family == "modifier": art_family = "passive"
	if art_family == "consumable": art_family = "tarot"
	var id := str(data.get("id", ""))
	if art_family == "pack": id = str(data.get("pack_family", str(data.get("name", "passive")).trim_suffix(" pack").to_lower().replace(" ", "_")))
	var path := "res://assets/v3/card_front.png" if family == "playing" else "res://assets/v3/items/%s/%s.png" % [art_family, id]
	if ResourceLoader.exists(path): artwork.texture = load(path)
	else:
		var fallback := "res://assets/v3/card_back.png"
		if ResourceLoader.exists(fallback): artwork.texture = load(fallback)
	tooltip_text = str(data.get("name", ""))
func _draw_indices(canvas: Control) -> void:
	var font := ThemeDB.fallback_font
	if family == "playing":
		var rank := int(data.get("rank", 2))
		var mark: String = str(rank) if rank < 11 else ["J", "Q", "K", "A"][clampi(rank - 11, 0, 3)]
		var suit := int(data.get("suit", 0))
		var tint := Color("b43940") if suit in [1, 2] else INK
		var symbol: String = ["♠", "♥", "♦", "♣"][clampi(suit, 0, 3)]
		canvas.draw_string(font, Vector2(8, 23), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, tint)
		canvas.draw_string(font, Vector2(8, 43), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, tint)
		canvas.draw_string(font, Vector2(size.x / 2 - 9, size.y * 0.72), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, tint)
	elif not compact:
		canvas.draw_string(font, Vector2(5, size.y - 8), str(data.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 10, 12, PAPER)
	if order >= 0:
		canvas.draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color("f49a24"), false, 2)
		canvas.draw_circle(Vector2(size.x - 12, 12), 10, Color("f49a24"))
		canvas.draw_string(font, Vector2(size.x - 16, 17), str(order + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
