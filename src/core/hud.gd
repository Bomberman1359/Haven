extends Control
## Everything drawn in screen space: the play HUD, the tutorial panel, the
## bestiary, and the title / boon / death screens. Buttons are rebuilt every
## frame as we draw them, so keyboard and mouse always agree on what is where.

const HeartTex: Texture2D = preload("res://assets/sprites/heart.png")
const KIND_TEX := {
	0: preload("res://assets/sprites/wisp.png"),
	1: preload("res://assets/sprites/husk.png"),
	2: preload("res://assets/sprites/stalker.png"),
	3: preload("res://assets/sprites/leech.png"),
	4: preload("res://assets/sprites/splitter.png"),
	5: preload("res://assets/sprites/brute.png"),
}

const WARM := Color(1.0, 0.82, 0.48)
const PALE := Color(0.72, 0.74, 0.86)
const DIM := Color(0.42, 0.44, 0.56)
const VIOLET := Color(0.78, 0.72, 1.0)
const BACK := Color(0.12, 0.11, 0.18, 0.85)
const PANEL := Color(0.07, 0.07, 0.12, 0.94)
const EDGE := Color(0.34, 0.32, 0.47, 0.9)

var font: Font
var game
var flash_col := Color(0, 0, 0, 0)
var note := ""
var note_t := 0.0
var pulse := 0.0

var menu_index := 0
var _btns: Array = []

var unlock_kind := -1
var unlock_t := 0.0


func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	flash_col.a = maxf(0.0, flash_col.a - delta * 1.9)
	note_t = maxf(0.0, note_t - delta)
	unlock_t = maxf(0.0, unlock_t - delta)
	if unlock_t <= 0.0:
		unlock_kind = -1
	pulse += delta
	queue_redraw()


func flash(c: Color) -> void:
	flash_col = c


func announce(text: String) -> void:
	note = text
	note_t = 2.4


func unlock_free() -> bool:
	return unlock_t <= 0.0


func show_unlock(kind: int) -> void:
	unlock_kind = kind
	unlock_t = 4.0
	Sfx.play("discover", -9.0)


# ------------------------------------------------------------- menu plumbing ---
func menu_reset() -> void:
	menu_index = 0


func menu_move(d: int) -> void:
	if _btns.is_empty():
		return
	menu_index = wrapi(menu_index + d, 0, _btns.size())
	Sfx.play_var("blip", -24.0)


func menu_current() -> String:
	if _btns.is_empty() or menu_index >= _btns.size():
		return ""
	return _btns[menu_index]["id"]


func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventMouseMotion:
		for i in _btns.size():
			var r: Rect2 = _btns[i]["rect"]
			if r.has_point(event.position):
				menu_index = i
				return
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if game.state == game.PLAY:
			if is_instance_valid(game.player):
				game.player.try_shoot()
			return
		for b in _btns:
			var br: Rect2 = b["rect"]
			if br.has_point(event.position):
				game.menu_activate(b["id"])
				return


# ------------------------------------------------------------------ drawing ---
func _shadowed(at: Vector2, s: String, fs: int, col: Color, width := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font, at + Vector2(1, 1), s, align, width, fs, Color(0, 0, 0, 0.72))
	draw_string(font, at, s, align, width, fs, col)


func _clock(t: float) -> String:
	var mins := int(t / 60.0)
	var secs := int(t) - mins * 60
	return "%02d:%02d" % [mins, secs]


func _bar(at: Vector2, w: float, h: float, frac: float, fill: Color, back := BACK) -> void:
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(at, Vector2(w, h)), back)
	if frac > 0.0:
		draw_rect(Rect2(at, Vector2(w * clampf(frac, 0.0, 1.0), h)), fill)


func _wrap_lines(text: String, width: float, fs: int) -> Array:
	var out: Array = []
	var line := ""
	for w in text.split(" "):
		var test: String = w if line == "" else line + " " + w
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and line != "":
			out.append(line)
			line = w
		else:
			line = test
	if line != "":
		out.append(line)
	return out


func _para(at: Vector2, text: String, width: float, fs: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> float:
	var y := at.y
	for l in _wrap_lines(text, width, fs):
		_shadowed(Vector2(at.x, y), l, fs, col, width, align)
		y += fs + 3
	return y


func _sprite_box(tex: Texture2D, box: Rect2, frames: int, tint := Color(1, 1, 1, 1)) -> void:
	var fw: float = tex.get_width() / float(frames)
	var fh: float = tex.get_height()
	var k: float = minf(box.size.x / fw, box.size.y / fh)
	var w := fw * k
	var h := fh * k
	var at := box.position + (box.size - Vector2(w, h)) * 0.5
	draw_texture_rect_region(tex, Rect2(at, Vector2(w, h)), Rect2(0, 0, fw, fh), tint)


func _button(rect: Rect2, id: String, label: String, fs: int, sub := "") -> void:
	var idx := _btns.size()
	_btns.append({"id": id, "rect": rect})
	var hot: bool = idx == menu_index
	draw_rect(rect, Color(0.13, 0.12, 0.2, 0.95) if hot else Color(0.07, 0.07, 0.12, 0.9))
	draw_rect(rect, WARM if hot else EDGE, false, 1.0)
	if hot:
		draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), WARM)
	var ty := rect.position.y + rect.size.y * 0.5 + fs * 0.36
	if sub != "":
		ty -= 5
	_shadowed(Vector2(rect.position.x, ty), label, fs, WARM if hot else PALE,
		rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	if sub != "":
		_shadowed(Vector2(rect.position.x, ty + 12), sub, 8, DIM,
			rect.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw() -> void:
	if game == null:
		return
	_btns.clear()
	var vs := get_viewport_rect().size
	var p = game.player
	var playing: bool = game.state == game.PLAY or game.state == game.DEAD

	if is_instance_valid(p) and playing:
		_draw_hearts(p)
		_draw_bars(p)
		_draw_boons()
		_draw_stats(vs)
		_draw_compass(p, vs)
		_draw_vigil(vs)

	if game.state == game.PLAY and game.tut_active:
		_draw_tutorial(vs)
	if unlock_kind >= 0:
		_draw_unlock(vs)

	if note_t > 0.0:
		var a := clampf(note_t / 0.6, 0.0, 1.0)
		_shadowed(Vector2(0, vs.y - 122), note, 14,
			Color(WARM.r, WARM.g, WARM.b, a), vs.x, HORIZONTAL_ALIGNMENT_CENTER)

	if flash_col.a > 0.002:
		draw_rect(Rect2(Vector2.ZERO, vs), flash_col)

	if game.state == game.MENU:
		_draw_menu(vs)
	elif game.state == game.BESTIARY:
		_draw_bestiary(vs)
	elif game.state == game.BOON:
		_draw_boon_screen(vs)
	elif game.state == game.DEAD:
		_draw_death(vs)


# ------------------------------------------------------------------ play HUD ---
func _draw_hearts(p) -> void:
	var maxhp: int = p.max_hp
	var step: int = 16 if maxhp <= 8 else 11
	for i in maxhp:
		var full: bool = i < p.hp
		var src := Rect2(0 if full else 7, 0, 7, 6)
		var dst := Rect2(Vector2(10 + i * step, 10), Vector2(14, 12))
		draw_texture_rect_region(HeartTex, dst, src)


func _draw_bars(p) -> void:
	var frac: float = p.fuel / p.max_fuel
	var col := Color(1.0, 0.72, 0.28).lerp(Color(0.85, 0.22, 0.28), clampf(1.0 - frac * 2.2, 0.0, 1.0))
	if frac < 0.22:
		col.a = 0.55 + 0.45 * absf(sin(pulse * 7.0))
	_shadowed(Vector2(10, 40), "LANTERN", 9, DIM)
	_bar(Vector2(10, 44), 132, 9, frac, col)
	_shadowed(Vector2(146, 53), "%d%%" % int(frac * 100.0), 10, PALE)

	var fc: float = p.flare_cd / p.flare_cd_max
	var f_cd := 1.0 - clampf(fc, 0.0, 1.0)
	var f_ok: bool = f_cd >= 1.0 and p.fuel >= p.flare_cost
	_bar(Vector2(10, 58), 62, 4, f_cd, WARM if f_ok else DIM)
	_shadowed(Vector2(78, 63), "FLARE  SPACE", 8, WARM if f_ok else DIM)

	var dc: float = p.dash_cd / p.dash_cd_max
	var d_cd := 1.0 - clampf(dc, 0.0, 1.0)
	_bar(Vector2(10, 68), 62, 4, d_cd, PALE if d_cd >= 1.0 else DIM)
	_shadowed(Vector2(78, 73), "DASH  SHIFT", 8, PALE if d_cd >= 1.0 else DIM)

	var bc: float = p.bolt_cd / p.bolt_cd_max
	var b_cd := 1.0 - clampf(bc, 0.0, 1.0)
	var b_ok: bool = b_cd >= 1.0 and p.fuel >= p.bolt_cost
	_bar(Vector2(10, 78), 62, 4, b_cd, Color(1.0, 0.88, 0.6) if b_ok else DIM)
	_shadowed(Vector2(78, 83), "FIRE  F / CLICK", 8, Color(1.0, 0.88, 0.6) if b_ok else DIM)


func _draw_boons() -> void:
	var list: Array = game.boons
	if list.is_empty():
		return
	var y := 100.0
	_shadowed(Vector2(10, y), "CARRYING", 8, DIM)
	y += 11
	for id in list:
		var nm: String = game.boon_name(id)
		_shadowed(Vector2(10, y), nm, 8, Color(0.62, 0.72, 0.62))
		y += 10


func _draw_stats(vs: Vector2) -> void:
	var right := vs.x - 150.0
	_shadowed(Vector2(right, 22), "DEPTH  %d" % game.depth, 15, VIOLET,
		140, HORIZONTAL_ALIGNMENT_RIGHT)

	var lit: int = game.beacons_lit
	var total: int = game.beacons.size()
	total = maxi(1, total)
	_shadowed(Vector2(right, 38), "BEACONS  %d / %d" % [lit, total], 11,
		WARM, 140, HORIZONTAL_ALIGNMENT_RIGHT)

	_shadowed(Vector2(right, 50), "%s      banished %d" % [_clock(game.run_time),
		game.run_banished + game.shadows_banished], 9, DIM, 140, HORIZONTAL_ALIGNMENT_RIGHT)

	var d: float = game.dread()
	var dcol := Color(0.55, 0.45, 0.85).lerp(Color(0.95, 0.20, 0.30), d)
	if d > 0.75:
		dcol.a = 0.6 + 0.4 * absf(sin(pulse * 5.0))
	_shadowed(Vector2(right, 66), "DREAD", 8, DIM, 140, HORIZONTAL_ALIGNMENT_RIGHT)
	_bar(Vector2(vs.x - 142, 70), 132, 6, d, dcol)


func _draw_compass(p, vs: Vector2) -> void:
	if game.state != game.PLAY:
		return
	var b = game.nearest_unlit_beacon()
	if b == null:
		return
	var d: Vector2 = b.global_position - p.global_position
	if d.length() < 200.0:
		return
	var dir := d.normalized()
	var c := vs * 0.5 + dir * 80.0
	var a := dir.angle()
	var to_stair: bool = is_instance_valid(game.stair)
	var base := Color(0.5, 0.68, 1.0) if to_stair else WARM
	var col := Color(base.r, base.g, base.b, 0.45 + 0.28 * sin(pulse * 3.4))
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(8, 0).rotated(a),
		c + Vector2(-5, -5).rotated(a),
		c + Vector2(-5, 5).rotated(a),
	]), col)
	var label := "DOWN  %d m" % int(d.length() / 32.0) if to_stair else "%d m" % int(d.length() / 32.0)
	_shadowed(c + dir * 13.0 - Vector2(30, -3), label, 8, col, 60, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_vigil(vs: Vector2) -> void:
	var best := 0.0
	for b in game.beacons:
		if is_instance_valid(b) and b.charging():
			best = maxf(best, b.charge_frac())
	if best <= 0.0:
		return
	var w := 200.0
	var at := Vector2((vs.x - w) * 0.5, vs.y - 52)
	_shadowed(Vector2(0, vs.y - 58), "V I G I L", 11, Color(1.0, 0.86, 0.56),
		vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	_bar(at, w, 7, best, Color(1.0, 0.8, 0.42))
	_shadowed(Vector2(0, vs.y - 32), "hold  E", 8, DIM, vs.x, HORIZONTAL_ALIGNMENT_CENTER)


# ------------------------------------------------------------------ tutorial ---
func _draw_tutorial(vs: Vector2) -> void:
	var step: Dictionary = game.tut_current()
	if step.is_empty():
		return
	var w := 306.0
	var pad := 9.0
	var lines := _wrap_lines(step["body"], w - pad * 2, 9)
	var h := 30.0 + lines.size() * 12.0
	var at := Vector2((vs.x - w) * 0.5, 6)

	draw_rect(Rect2(at, Vector2(w, h)), PANEL)
	draw_rect(Rect2(at, Vector2(w, h)), EDGE, false, 1.0)
	draw_rect(Rect2(at, Vector2(w, 2)), WARM)

	_shadowed(at + Vector2(pad, 16), step["title"], 11, WARM)
	var step_no := "%d / %d" % [game.tut_step + 1, game.TUT.size()]
	_shadowed(at + Vector2(-pad, 16), step_no, 8, DIM, w, HORIZONTAL_ALIGNMENT_RIGHT)
	var y := at.y + 29
	for l in lines:
		_shadowed(Vector2(at.x + pad, y), l, 9, PALE)
		y += 12
	_shadowed(Vector2(at.x, at.y + h + 11), "T  skip the tutorial", 8, DIM,
		w, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_unlock(vs: Vector2) -> void:
	var e: Dictionary = game.bestiary_entry(unlock_kind)
	var w := 158.0
	var h := 56.0
	var slide := clampf((4.0 - unlock_t) * 6.0, 0.0, 1.0) * clampf(unlock_t * 3.0, 0.0, 1.0)
	var at := Vector2(vs.x - 8 - w * slide, 112)

	draw_rect(Rect2(at, Vector2(w, h)), PANEL)
	draw_rect(Rect2(at, Vector2(w, h)), Color(0.6, 0.45, 0.75, 0.95), false, 1.0)
	_sprite_box(KIND_TEX[unlock_kind], Rect2(at + Vector2(6, 12), Vector2(34, 34)), 4)
	_shadowed(at + Vector2(46, 20), "NEW SHADOW", 8, Color(0.72, 0.62, 0.95))
	_shadowed(at + Vector2(46, 34), e["name"], 13, WARM)
	_shadowed(at + Vector2(46, 46), "see the bestiary", 7, DIM)


# -------------------------------------------------------------------- menus ---
func _draw_menu(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.03, 0.06, 0.88))
	_shadowed(Vector2(0, 74), "H A V E N", 40, WARM, vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	_shadowed(Vector2(0, 96), "the lantern keeper", 12, PALE, vs.x, HORIZONTAL_ALIGNMENT_CENTER)

	var bw := 214.0
	var bh := 30.0
	var x0 := (vs.x - bw) * 0.5
	var y := 128.0
	_button(Rect2(Vector2(x0, y), Vector2(bw, bh)), "play", "PLAY", 16)
	y += bh + 8
	_button(Rect2(Vector2(x0, y), Vector2(bw, bh)), "tutorial",
		"TUTORIAL:  %s" % ("ON" if game.tutorial_on else "OFF"), 12,
		"teaches the controls on depth 1")
	y += bh + 8
	_button(Rect2(Vector2(x0, y), Vector2(bw, bh)), "bestiary", "BESTIARY", 14,
		"%d of %d shadows met" % [game.seen.size(), game.KIND_COUNT])
	y += bh + 8
	if not OS.has_feature("web"):
		_button(Rect2(Vector2(x0, y), Vector2(bw, 24)), "quit", "QUIT", 12)

	if game.best_depth > 1:
		_shadowed(Vector2(0, vs.y - 26), "deepest run so far:  depth %d" % game.best_depth,
			9, DIM, vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	_shadowed(Vector2(0, vs.y - 12), "arrow keys and ENTER, or click", 8, DIM,
		vs.x, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_bestiary(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.03, 0.07, 0.95))
	_shadowed(Vector2(0, 26), "B E S T I A R Y", 20, WARM, vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	_shadowed(Vector2(0, 42), "%d of %d shadows met" % [game.seen.size(), game.KIND_COUNT],
		9, DIM, vs.x, HORIZONTAL_ALIGNMENT_CENTER)

	var cw := 286.0
	var ch := 78.0
	var gx := 14.0
	var x0 := (vs.x - (cw * 2 + gx)) * 0.5
	var count: int = game.LORE.size()
	for i in count:
		var e: Dictionary = game.LORE[i]
		var col_i: int = i % 2
		var row: int = int(i / 2.0)
		var at := Vector2(x0 + col_i * (cw + gx), 56 + row * (ch + 8))
		var known: bool = game.seen.has(e["kind"])

		draw_rect(Rect2(at, Vector2(cw, ch)), PANEL)
		draw_rect(Rect2(at, Vector2(cw, ch)), EDGE if known else Color(0.2, 0.2, 0.28, 0.8),
			false, 1.0)

		var tint := Color(1, 1, 1, 1) if known else Color(0.16, 0.16, 0.24, 0.9)
		_sprite_box(KIND_TEX[e["kind"]], Rect2(at + Vector2(6, 16), Vector2(44, 44)), 4, tint)

		if known:
			draw_rect(Rect2(at, Vector2(cw, 2)), WARM)
			_shadowed(at + Vector2(56, 18), e["name"], 12, WARM)
			var y := _para(at + Vector2(56, 32), e["line"], cw - 64, 7, PALE)
			_para(Vector2(at.x + 56, y + 2), e["tip"], cw - 64, 7, Color(0.58, 0.68, 0.58))
		else:
			_shadowed(at + Vector2(56, 18), "? ? ? ? ?", 12, DIM)
			_shadowed(at + Vector2(56, 34), "You have not met this one yet.", 7, DIM)
			_shadowed(at + Vector2(56, 46), "Go deeper.", 7, Color(0.32, 0.33, 0.42))

	_button(Rect2(Vector2((vs.x - 150) * 0.5, vs.y - 32), Vector2(150, 24)), "back", "BACK", 12)


func _draw_boon_screen(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.03, 0.07, 0.9))
	_shadowed(Vector2(0, 52), "DEPTH  %d  CLEARED" % game.depth, 20, VIOLET,
		vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	_shadowed(Vector2(0, 72), "take one thing down with you", 11, DIM,
		vs.x, HORIZONTAL_ALIGNMENT_CENTER)

	var n: int = game.boon_choices.size()
	if n == 0:
		return
	var cw := 180.0
	var ch := 152.0
	var gap := 14.0
	var total := n * cw + (n - 1) * gap
	var x0 := (vs.x - total) * 0.5
	for i in n:
		var c: Dictionary = game.boon_choices[i]
		var at := Vector2(x0 + i * (cw + gap), 96)
		var idx := _btns.size()
		_btns.append({"id": "boon_%d" % i, "rect": Rect2(at, Vector2(cw, ch))})
		var hot: bool = idx == menu_index

		draw_rect(Rect2(at, Vector2(cw, ch)), Color(0.11, 0.1, 0.17, 0.97) if hot else PANEL)
		draw_rect(Rect2(at, Vector2(cw, ch)), WARM if hot else EDGE, false, 1.0)
		draw_rect(Rect2(at, Vector2(cw, 3)), WARM if hot else Color(0.6, 0.5, 0.35, 0.7))
		_shadowed(at + Vector2(0, 34), "%d" % (i + 1), 22,
			Color(1.0, 0.82, 0.48, 0.6 + 0.35 * absf(sin(pulse * 3.0 + i))), cw,
			HORIZONTAL_ALIGNMENT_CENTER)
		_shadowed(at + Vector2(0, 58), c["name"], 13, WARM, cw, HORIZONTAL_ALIGNMENT_CENTER)
		_para(at + Vector2(10, 78), c["desc"], cw - 20, 8, PALE, HORIZONTAL_ALIGNMENT_CENTER)

	_shadowed(Vector2(0, vs.y - 16), "press 1, 2 or 3, or click a card", 9, DIM,
		vs.x, HORIZONTAL_ALIGNMENT_CENTER)


# ---------------------------------------------------------------------- death ---
func _draw_death(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.05, 0.92))
	_shadowed(Vector2(0, 34), "THE LANTERN WENT OUT", 22, Color(0.92, 0.36, 0.42),
		vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	_shadowed(Vector2(0, 54), "you got to depth %d" % game.depth, 14, VIOLET,
		vs.x, HORIZONTAL_ALIGNMENT_CENTER)
	if game.best_depth > game.depth:
		_shadowed(Vector2(0, 68), "your best is depth %d" % game.best_depth, 9, DIM,
			vs.x, HORIZONTAL_ALIGNMENT_CENTER)

	# left panel: the run
	var pw := 176.0
	var ph := 138.0
	var left := Vector2((vs.x * 0.5) - pw - 8, 80)
	draw_rect(Rect2(left, Vector2(pw, ph)), PANEL)
	draw_rect(Rect2(left, Vector2(pw, ph)), EDGE, false, 1.0)
	_shadowed(left + Vector2(10, 17), "THE RUN", 10, WARM)
	var rows := [
		["time survived", _clock(game.run_time)],
		["depth reached", str(game.depth)],
		["beacons lit", str(game.run_beacons)],
		["oil flasks taken", str(game.run_flasks)],
		["shadows banished", str(game.run_banished)],
		["boons carried", str(game.boons.size())],
	]
	var y := left.y + 36.0
	for r in rows:
		_shadowed(Vector2(left.x + 10, y), r[0], 8, DIM)
		_shadowed(Vector2(left.x - 10, y), r[1], 9, PALE, pw, HORIZONTAL_ALIGNMENT_RIGHT)
		y += 15

	# right panel: what you killed
	var right := Vector2((vs.x * 0.5) + 8, 80)
	draw_rect(Rect2(right, Vector2(pw, ph)), PANEL)
	draw_rect(Rect2(right, Vector2(pw, ph)), EDGE, false, 1.0)
	_shadowed(right + Vector2(10, 17), "BANISHED", 10, WARM)
	var ky := right.y + 26.0
	for e in game.LORE:
		var k: int = e["kind"]
		var n: int = int(game.kills.get(k, 0))
		var live: bool = n > 0
		_sprite_box(KIND_TEX[k], Rect2(Vector2(right.x + 9, ky), Vector2(16, 16)), 4,
			Color(1, 1, 1, 1) if live else Color(0.28, 0.28, 0.36, 0.8))
		_shadowed(Vector2(right.x + 32, ky + 12), e["name"], 8, PALE if live else DIM)
		_shadowed(Vector2(right.x - 10, ky + 12), str(n), 9, WARM if live else DIM,
			pw, HORIZONTAL_ALIGNMENT_RIGHT)
		ky += 18

	if not game.boons.is_empty():
		var carried := ""
		for id in game.boons:
			carried += ("" if carried == "" else "   ") + str(game.boon_name(id))
		_shadowed(Vector2(0, 232), carried, 8, Color(0.55, 0.65, 0.55),
			vs.x, HORIZONTAL_ALIGNMENT_CENTER)

	var bw := 150.0
	var gap := 12.0
	var x0 := (vs.x - (bw * 2 + gap)) * 0.5
	_button(Rect2(Vector2(x0, vs.y - 62), Vector2(bw, 26)), "retry", "DESCEND AGAIN", 12, "R")
	_button(Rect2(Vector2(x0 + bw + gap, vs.y - 62), Vector2(bw, 26)), "home", "MAIN MENU", 12, "H")
