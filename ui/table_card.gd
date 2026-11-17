extends Button
## Original vector artwork; no external game assets.
var data: Dictionary = {}
var family := "playing"
var order := -1
var compact := false
const PAPER = Color("fff1d2")
const INK = Color("152d32")
func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for key in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(key, StyleBoxEmpty.new())
	resized.connect(queue_redraw)
func _draw() -> void:
	var r := Rect2(Vector2(3, 10 if order < 0 else 2), size - Vector2(6, 14))
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.set_corner_radius_all(6)
	box.shadow_color = Color(0.02, 0.08, 0.07, 0.5)
	box.shadow_size = 3
	box.shadow_offset = Vector2(1, 4)
	box.border_color = Color("f49a24") if order >= 0 else Color("d8c9a9")
	box.set_border_width_all(3 if order >= 0 else 1)
	draw_style_box(box, r)
	var font := ThemeDB.fallback_font
	if family == "playing":
		var rank := int(data.get("rank", 2))
		var mark: String = str(rank) if rank < 11 else ["J", "Q", "K", "A"][clampi(rank - 11, 0, 3)]
		var suit := int(data.get("suit", 0))
		var tint := Color("b43940") if suit in [1, 2] else INK
		draw_string(font, r.position + Vector2(7, 20), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, tint)
		_pip(r.get_center() + Vector2(0, 4), suit, 12, tint)
		if rank in [11, 12, 13]:
			draw_arc(r.get_center() + Vector2(0, 4), 19, 0, TAU, 6, tint, 1.5, true)
		draw_string(font, r.end - Vector2(23, 7), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)
	else:
		var color := Color("247baf")
		if family in ["tarot", "consumable"]: color = Color("91508d")
		elif family in ["modifier", "passive"]: color = Color("bf5846")
		elif family == "voucher": color = Color("b47c24")
		elif family == "pack": color = Color("326e64")
		var art := Rect2(r.position + Vector2(5, 5), Vector2(r.size.x - 10, r.size.y * 0.65))
		draw_style_box(_art_box(color), art)
		var center := art.get_center()
		var radius := minf(art.size.x, art.size.y) * 0.29
		var variant_id := posmod(str(data.get("id", data.get("name", ""))).hash(), 5)
		if family == "planet":
			draw_circle(center, radius * 0.65, PAPER)
			draw_arc(center, radius + 5, -0.5, 2.7, 28, PAPER, 2, true)
			draw_arc(center, radius + 10, 2.5, 5.8, 28, PAPER, 1, true)
			draw_circle(center + Vector2(radius, -radius), 3, PAPER)
		elif family in ["tarot", "consumable"]:
			var points := PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius*0.8,0),center+Vector2(0,radius),center+Vector2(-radius*0.8,0),center+Vector2(0,-radius)])
			draw_polyline(points, PAPER, 2, true)
			draw_circle(center, 5, PAPER)
			draw_line(center+Vector2(-radius, -radius),center+Vector2(radius,radius),PAPER,1,true)
		elif family == "pack":
			draw_rect(Rect2(center-Vector2(radius,radius),Vector2(radius*2,radius*2)),PAPER,false,2)
			draw_line(center-Vector2(radius,0),center+Vector2(radius,0),PAPER,2)
			draw_line(center-Vector2(0,radius),center+Vector2(0,radius),PAPER,2)
		else:
			for i in range(3):
				draw_arc(center + Vector2((i - 1) * 4, 0), radius + i * 3, 0, TAU, 5 + variant_id, PAPER, 1.4, true)
			draw_circle(center, 3.5, PAPER)
		if not compact:
			var name_text := str(data.get("name", "Mystery"))
			var words := name_text.split(" ")
			draw_string(font, Vector2(r.position.x + 6, art.end.y + 17), words[0], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 14, INK)
			if words.size() > 1: draw_string(font, Vector2(r.position.x + 6, art.end.y + 32), " ".join(words.slice(1)), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 14, INK)
	if order >= 0:
		draw_circle(Vector2(r.end.x - 10, r.position.y + 10), 10, Color("f49a24"))
		draw_string(font, Vector2(r.end.x - 14, r.position.y + 15), str(order + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, INK)
func _art_box(color: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(3)
	return b
func _pip(c: Vector2, suit: int, radius: float, color: Color) -> void:
	if suit == 2:
		draw_colored_polygon(PackedVector2Array([c+Vector2(0,-radius), c+Vector2(radius,0), c+Vector2(0,radius), c+Vector2(-radius,0)]), color)
	elif suit == 1:
		draw_circle(c+Vector2(-5,-4), 7, color)
		draw_circle(c+Vector2(5,-4), 7, color)
		draw_colored_polygon(PackedVector2Array([c+Vector2(-12,-2), c+Vector2(12,-2), c+Vector2(0,13)]), color)
	else:
		if suit == 3:
			for delta in [Vector2(0,-7),Vector2(-7,2),Vector2(7,2)]: draw_circle(c+delta, 6, color)
		else:
			draw_colored_polygon(PackedVector2Array([c+Vector2(0,-13),c+Vector2(12,4),c+Vector2(-12,4)]), color)
			draw_circle(c+Vector2(-5,3),6,color)
			draw_circle(c+Vector2(5,3),6,color)
		draw_colored_polygon(PackedVector2Array([c+Vector2(0,3),c+Vector2(5,13),c+Vector2(-5,13)]), color)
