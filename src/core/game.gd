extends Node2D
## HAVEN: the main game controller.
## Owns the descent: each depth is a freshly generated ruin, and lighting every
## beacon opens the way down. Registers itself in the "game" group in
## _enter_tree so every other script can grab it from its own _ready.

enum { MENU, PLAY, BOON, DEAD, BESTIARY }

# shadow kinds. shadow.gd holds the stats for each of them
const WISP := 0
const HUSK := 1
const STALKER := 2
const LEECH := 3
const SPLITTER := 4
const BRUTE := 5
const KIND_COUNT := 6

const TILE := 32
const WALL_SHADOWS := true
const FLARE_DAMAGE := 15.0
const SAVE_PATH := "user://haven.cfg"

const PlayerScene: PackedScene = preload("res://src/player/player.tscn")
const ShadowScene: PackedScene = preload("res://src/shadows/shadow.tscn")
const BeaconScene: PackedScene = preload("res://src/world/beacon.tscn")
const FlaskScene: PackedScene = preload("res://src/world/flask.tscn")
const StairScene: PackedScene = preload("res://src/world/stair.tscn")
const BoltScene: PackedScene = preload("res://src/player/bolt.tscn")

const SparkTex: Texture2D = preload("res://assets/sprites/spark.png")
const FlareTex: Texture2D = preload("res://assets/sprites/flare.png")

const AMBIENT_CALM := Color(0.290196, 0.278431, 0.403922)
const AMBIENT_DREAD := Color(0.141176, 0.129412, 0.211765)

const BOONS := [
	{"id": "wick", "name": "DEEP WICK",
		"desc": "Your lantern burns 20% slower, so a full tank lasts longer."},
	{"id": "glass", "name": "WIDE GLASS",
		"desc": "Your light reaches 18% further at any fuel level."},
	{"id": "tank", "name": "LONG WICK",
		"desc": "Adds 30 to your maximum fuel and fills the tank right now."},
	{"id": "oil", "name": "RICH OIL",
		"desc": "Every oil flask you pick up is worth 14 more fuel."},
	{"id": "keen", "name": "KEEN LIGHT",
		"desc": "Standing light burns shadows 32% faster. Useful against husks."},
	{"id": "flare", "name": "QUICK FLARE",
		"desc": "Flares cost 7 less fuel and recharge a little quicker."},
	{"id": "steady", "name": "STEADY HAND",
		"desc": "Lantern bolts cost 30% less fuel and fire a bit faster."},
	{"id": "twin", "name": "TWIN SPARK",
		"desc": "Each shot fires two bolts in a narrow spread, for 25% more fuel a shot."},
	{"id": "pierce", "name": "PIERCING BEAM",
		"desc": "Your bolts pass through one more shadow before they burn out."},
	{"id": "heart", "name": "IRON HEART",
		"desc": "Adds a permanent heart to your maximum, and mends one now."},
	{"id": "mend", "name": "MENDED CLOAK",
		"desc": "Mends one heart now. After a hit you stay safe from damage 0.3s longer."},
	{"id": "revive", "name": "SECOND WIND",
		"desc": "Once a run, the hit that would kill you leaves you standing with two hearts."},
	{"id": "boots", "name": "SWIFT BOOTS",
		"desc": "You move 11% faster and your dash recharges sooner."},
	{"id": "trail", "name": "EMBER TRAIL",
		"desc": "Dashing leaves burning embers behind you. They count as light, so they hurt shadows for a couple of seconds."},
	{"id": "ward", "name": "WARDEN'S VOW",
		"desc": "Lighting a beacon gives 25 extra fuel and scours shadows from further out."},
	{"id": "hearth", "name": "WIDE HEARTH",
		"desc": "Lit beacons refuel you 70% faster and from 70% further away."},
	{"id": "scavenge", "name": "SCAVENGER",
		"desc": "About one shadow in six leaves a splash of oil behind when you banish it."},
	{"id": "eyes", "name": "NIGHT EYES",
		"desc": "The ruin renders brighter, so you can read the room past your own light."},
]

const LORE := [
	{"kind": WISP, "name": "WISP", "tex": "wisp",
		"line": "The common dark. Weak, quick to burn, and it never arrives alone.",
		"tip": "One bolt kills it. Standing light takes about three seconds."},
	{"kind": HUSK, "name": "HUSK", "tex": "husk",
		"line": "A slab of dark carrying roughly twice the health of a wisp.",
		"tip": "It walks into your glare instead of backing off, so it will reach you. Shoot it."},
	{"kind": STALKER, "name": "STALKER", "tex": "stalker",
		"line": "Thin and fast, and almost blind in the light. Shows up from depth 2.",
		"tip": "Light pins it where it stands. The danger is a low lantern, not a full one."},
	{"kind": LEECH, "name": "LEECH", "tex": "leech",
		"line": "It never touches you. It hangs at the edge of your reach. Shows up from depth 3.",
		"tip": "It drinks your fuel from range, so it kills you with darkness. Shoot it early."},
	{"kind": SPLITTER, "name": "SPLITTER", "tex": "splitter",
		"line": "Swollen and slow to commit. Shows up from depth 4.",
		"tip": "Light or a bolt breaks it into two wisps. Only a flare kills it outright."},
	{"kind": BRUTE, "name": "BRUTE", "tex": "brute",
		"line": "Armoured, horned, and immune to standing lantern light. Shows up from depth 5.",
		"tip": "Flares hurt it properly and bolts only half work. It takes two hearts a hit, so walking away is fair."},
]

const TUT := [
	{"id": "move", "title": "MOVE",
		"body": "WASD or the arrow keys.", "min": 1.2},
	{"id": "lantern", "title": "YOUR LANTERN",
		"body": "Top left is your fuel. It burns down every second, and how far your light reaches is however much fuel is left.", "min": 6.0},
	{"id": "shoot", "title": "FIRE",
		"body": "Press F or click to snap a bolt of light at the nearest shadow. It costs a little fuel. Try it on that wisp.", "min": 1.0},
	{"id": "flask", "title": "LAMP OIL",
		"body": "Those small bottles refill your lantern. Walk over one.", "min": 1.0},
	{"id": "dash", "title": "DASH",
		"body": "SHIFT dashes. Nothing can hit you during the dash itself.", "min": 1.0},
	{"id": "flare", "title": "FLARE",
		"body": "SPACE throws a flare. It hits everything around you hard, but it costs a good chunk of your fuel.", "min": 1.0},
	{"id": "hearts", "title": "HEARTS",
		"body": "The hearts above your fuel bar are your health. Any shadow that reaches you takes one.", "min": 5.0},
	{"id": "beacon", "title": "FIND A BEACON",
		"body": "The arrow near the middle of the screen points at the nearest dead beacon and tells you how far it is. Go there.", "min": 2.0},
	{"id": "vigil", "title": "KEEP VIGIL",
		"body": "Hold E. The beacon takes time to catch, and the dark sends a wave the moment you start. Hold on anyway. The flame grows while you do, and it fights on your side.", "min": 2.0},
	{"id": "dread", "title": "DREAD",
		"body": "The bar under DEPTH on the right. It climbs the longer you stay on a floor and makes everything worse. Going down resets it.", "min": 5.5},
	{"id": "descend", "title": "GO DOWN",
		"body": "Light every beacon and a stairway opens. Step into it to take a boon and go down. There is no bottom.", "min": 3.0},
]

@onready var dark: CanvasModulate = $Dark
@onready var terrain = $Terrain
@onready var entities: Node2D = $Entities
@onready var walls: Node2D = $Walls
@onready var fx_root: Node2D = $Fx
@onready var cam: Camera2D = $Cam
@onready var hud = $HUD/Root

var state := MENU
var depth := 1
var mw := 52
var mh := 38

var grid := PackedByteArray()
var variants := PackedByteArray()
var floor_tiles: Array[Vector2i] = []
var rooms: Array[Rect2i] = []

var player = null
var stair = null
var beacons: Array = []
var shadows: Array = []
var flasks: Array = []
var light_sources: Array = []

var boons: Array = []
var boon_choices: Array = []
var carry_hp := -1
var carry_fuel := -1.0

var beacons_lit := 0
var shadows_banished := 0
var run_banished := 0
var run_beacons := 0
var run_flasks := 0
var kills := {}
var best_depth := 1
var elapsed := 0.0
var run_time := 0.0
var spawn_t := 3.0
var flask_respawn_t := -1.0
var shake_amt := 0.0
var rng := RandomNumberGenerator.new()

# bestiary + tutorial
var seen := {}
var unlock_queue: Array = []
var tutorial_on := true
var tutorial_done := false
var tut_active := false
var tut_step := 0
var tut_t := 0.0
var tut_moved := 0.0
var tut_flags := {}


# ------------------------------------------------------------------ setup ---
func _enter_tree() -> void:
	add_to_group("game")


func _ready() -> void:
	_setup_input()
	rng.randomize()
	_load_progress()
	depth = 1
	_reset_run_stats()
	build_world()
	state = MENU
	entities.process_mode = Node.PROCESS_MODE_DISABLED


func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("flare", [KEY_SPACE])
	_bind("shoot", [KEY_F, KEY_J])
	_bind("interact", [KEY_E])
	_bind("dash", [KEY_SHIFT, KEY_K])
	_bind("restart", [KEY_R])
	_bind("home", [KEY_H])
	_bind("begin", [KEY_ENTER, KEY_KP_ENTER])
	_bind("ui_upx", [KEY_UP, KEY_W])
	_bind("ui_downx", [KEY_DOWN, KEY_S])
	_bind("skip_tut", [KEY_T])
	_bind("pick_1", [KEY_1, KEY_KP_1])
	_bind("pick_2", [KEY_2, KEY_KP_2])
	_bind("pick_3", [KEY_3, KEY_KP_3])


func _bind(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


# ------------------------------------------------------------ persistence ---
func _load_progress() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return
	for k in KIND_COUNT:
		if cf.get_value("bestiary", str(k), false):
			seen[k] = true
	best_depth = int(cf.get_value("run", "best_depth", 1))
	tutorial_done = bool(cf.get_value("run", "tutorial_done", false))
	tutorial_on = bool(cf.get_value("run", "tutorial_on", not tutorial_done))


func _save_progress() -> void:
	var cf := ConfigFile.new()
	for k in seen.keys():
		cf.set_value("bestiary", str(k), true)
	cf.set_value("run", "best_depth", best_depth)
	cf.set_value("run", "tutorial_done", tutorial_done)
	cf.set_value("run", "tutorial_on", tutorial_on)
	cf.save(SAVE_PATH)


func note_seen(kind: int) -> void:
	if seen.has(kind):
		return
	seen[kind] = true
	unlock_queue.append(kind)
	_save_progress()


func bestiary_entry(kind: int) -> Dictionary:
	for e in LORE:
		if e["kind"] == kind:
			return e
	return LORE[0]


# --------------------------------------------------------- depth balancing ---
func dread() -> float:
	## how bad THIS floor has got, 0 to 1. Shown on the HUD.
	return clampf(elapsed * 0.0040 + beacons_lit * 0.085, 0.0, 1.0)


func menace() -> float:
	## total pressure: floor tension plus how deep you are. Left unbounded on purpose,
	## so there is always a floor that finally kills you.
	return dread() + (depth - 1) * 0.42


func beacon_count() -> int:
	return clampi(5 + int((depth - 1) / 2.0), 5, 9)


func spawn_interval() -> float:
	var base := clampf(2.5 - menace() * 0.72, 0.42, 2.5)
	return base * (1.7 if tut_active else 1.0)


func max_shadows() -> int:
	if tut_active:
		return 6
	return mini(46, 8 + depth * 2 + int(dread() * 10.0))


func speed_mult() -> float:
	return minf(2.2, 1.0 + menace() * 0.16)


func hp_mult() -> float:
	return 1.0 + menace() * 0.30


func burn_mult() -> float:
	return minf(2.6, 1.0 + dread() * 0.45 + (depth - 1) * 0.09)


func spawn_table() -> Array:
	var t := [[WISP, 10.0]]
	t.append([HUSK, 2.0 + depth * 0.6])
	if depth >= 2:
		t.append([STALKER, 1.2 + depth * 0.7])
	if depth >= 3:
		t.append([LEECH, 1.2 + depth * 0.5])
	if depth >= 4:
		t.append([SPLITTER, 1.2 + depth * 0.5])
	if depth >= 5:
		t.append([BRUTE, 0.8 + depth * 0.35])
	return t


func roll_kind() -> int:
	if tut_active:
		return WISP
	var table := spawn_table()
	var total := 0.0
	for e in table:
		total += e[1]
	var r := rng.randf() * total
	for e in table:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return WISP


# ------------------------------------------------------------- world build ---
func _reset_run_stats() -> void:
	boons.clear()
	carry_hp = -1
	carry_fuel = -1.0
	run_banished = 0
	run_beacons = 0
	run_flasks = 0
	run_time = 0.0
	kills = {}
	for k in KIND_COUNT:
		kills[k] = 0


func build_world() -> void:
	for c in entities.get_children():
		c.queue_free()
	for c in walls.get_children():
		c.queue_free()
	for c in fx_root.get_children():
		c.queue_free()
	beacons.clear()
	shadows.clear()
	flasks.clear()
	light_sources.clear()
	stair = null
	beacons_lit = 0
	shadows_banished = 0
	elapsed = 0.0
	spawn_t = 5.0
	flask_respawn_t = -1.0
	shake_amt = 0.0

	mw = clampi(50 + (depth - 1) * 3, 50, 74)
	mh = clampi(36 + (depth - 1) * 2, 36, 56)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = mw * TILE
	cam.limit_bottom = mh * TILE
	cam.make_current()

	_generate_map()
	terrain.setup(grid, variants, mw, mh, TILE)
	_build_colliders()
	_spawn_entities()
	_refresh_ambient()


func _idx(x: int, y: int) -> int:
	return y * mw + x


func solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= mw or y >= mh:
		return true
	return grid[_idx(x, y)] == 1


func _generate_map() -> void:
	grid = PackedByteArray()
	grid.resize(mw * mh)
	grid.fill(1)
	variants = PackedByteArray()
	variants.resize(mw * mh)
	for i in variants.size():
		variants[i] = rng.randi_range(0, 3)
	rooms.clear()

	var want_rooms := clampi(12 + depth, 12, 22)
	var tries := 0
	while rooms.size() < want_rooms and tries < 900:
		tries += 1
		var rw := rng.randi_range(6, 12)
		var rh := rng.randi_range(5, 9)
		var rx := rng.randi_range(2, mw - rw - 3)
		var ry := rng.randi_range(2, mh - rh - 3)
		var r := Rect2i(rx, ry, rw, rh)
		var ok := true
		for o in rooms:
			if r.grow(2).intersects(o):
				ok = false
				break
		if ok:
			rooms.append(r)

	for r in rooms:
		_carve_rect(r)

	for i in range(1, rooms.size()):
		_carve_corridor(rooms[i - 1].get_center(), rooms[i].get_center())
	for i in 4:
		if rooms.size() < 3:
			break
		var a: int = rng.randi_range(0, rooms.size() - 1)
		var b: int = rng.randi_range(0, rooms.size() - 1)
		if a != b:
			_carve_corridor(rooms[a].get_center(), rooms[b].get_center())

	for r in rooms:
		for i in rng.randi_range(1, 3):
			var cx := rng.randi_range(r.position.x - 2, r.end.x + 1)
			var cy := rng.randi_range(r.position.y - 2, r.end.y + 1)
			_carve_blob(cx, cy, rng.randi_range(2, 3))

	for x in mw:
		grid[_idx(x, 0)] = 1
		grid[_idx(x, 1)] = 1
		grid[_idx(x, mh - 1)] = 1
		grid[_idx(x, mh - 2)] = 1
	for y in mh:
		grid[_idx(0, y)] = 1
		grid[_idx(1, y)] = 1
		grid[_idx(mw - 1, y)] = 1
		grid[_idx(mw - 2, y)] = 1

	floor_tiles.clear()
	for y in mh:
		for x in mw:
			if grid[_idx(x, y)] == 0:
				floor_tiles.append(Vector2i(x, y))


func _carve_rect(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x > 0 and y > 0 and x < mw - 1 and y < mh - 1:
				grid[_idx(x, y)] = 0


func _carve_blob(cx: int, cy: int, rad: int) -> void:
	for y in range(cy - rad, cy + rad + 1):
		for x in range(cx - rad, cx + rad + 1):
			if x < 2 or y < 2 or x >= mw - 2 or y >= mh - 2:
				continue
			if Vector2(x - cx, y - cy).length() <= float(rad) + 0.2:
				grid[_idx(x, y)] = 0


func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	var wide := rng.randi_range(0, 1)
	if rng.randi_range(0, 1) == 0:
		_carve_h(a.x, b.x, a.y, wide)
		_carve_v(a.y, b.y, b.x, wide)
	else:
		_carve_v(a.y, b.y, a.x, wide)
		_carve_h(a.x, b.x, b.y, wide)


func _carve_h(x0: int, x1: int, y: int, wide: int) -> void:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		for dy in range(0, 2 + wide):
			var yy := y + dy - 1
			if x > 1 and yy > 1 and x < mw - 2 and yy < mh - 2:
				grid[_idx(x, yy)] = 0


func _carve_v(y0: int, y1: int, x: int, wide: int) -> void:
	for y in range(mini(y0, y1), maxi(y0, y1) + 1):
		for dx in range(0, 2 + wide):
			var xx := x + dx - 1
			if xx > 1 and y > 1 and xx < mw - 2 and y < mh - 2:
				grid[_idx(xx, y)] = 0


func _is_edge(x: int, y: int) -> bool:
	if not solid(x, y):
		return false
	return (not solid(x + 1, y)) or (not solid(x - 1, y)) \
		or (not solid(x, y + 1)) or (not solid(x, y - 1)) \
		or (not solid(x + 1, y + 1)) or (not solid(x - 1, y - 1)) \
		or (not solid(x + 1, y - 1)) or (not solid(x - 1, y + 1))


func _build_colliders() -> void:
	## merge each row of edge tiles into horizontal runs, which needs far fewer bodies
	for y in mh:
		var x := 0
		while x < mw:
			if _is_edge(x, y):
				var x0 := x
				while x < mw and _is_edge(x, y):
					x += 1
				_add_run(x0, x - 1, y)
			else:
				x += 1


func _add_run(x0: int, x1: int, y: int) -> void:
	var w := (x1 - x0 + 1) * TILE
	var centre := Vector2(x0 * TILE + w * 0.5, y * TILE + TILE * 0.5)

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = centre
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, TILE)
	shape.shape = rect
	body.add_child(shape)
	walls.add_child(body)

	if WALL_SHADOWS:
		var occ := LightOccluder2D.new()
		occ.position = centre
		var poly := OccluderPolygon2D.new()
		poly.closed = true
		poly.cull_mode = OccluderPolygon2D.CULL_DISABLED
		var hw := w * 0.5
		var hh := TILE * 0.5
		poly.polygon = PackedVector2Array([
			Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)
		])
		occ.occluder = poly
		walls.add_child(occ)


# ----------------------------------------------------------------- spawning ---
func _spawn_entities() -> void:
	if rooms.is_empty():
		return
	var order := range(rooms.size())
	order.shuffle()

	var home: Rect2i = rooms[order[0]]
	player = PlayerScene.instantiate()
	player.position = Vector2(home.get_center()) * TILE + Vector2(TILE, TILE) * 0.5
	entities.add_child(player)
	player.died.connect(_on_player_died)
	for b in boons:
		player.apply_boon(b)
	if carry_hp > 0:
		player.hp = mini(carry_hp, player.max_hp)
	if carry_fuel >= 0.0:
		player.fuel = clampf(carry_fuel, 40.0, player.max_fuel)
	cam.global_position = player.global_position

	var candidates := []
	for i in range(1, rooms.size()):
		var r: Rect2i = rooms[order[i]]
		candidates.append({
			"rect": r,
			"d": Vector2(r.get_center() - home.get_center()).length()
		})
	candidates.sort_custom(func(a, b): return a["d"] > b["d"])
	var want: int = mini(beacon_count(), candidates.size())
	for i in want:
		var r: Rect2i = candidates[i]["rect"]
		var b := BeaconScene.instantiate()
		b.position = Vector2(r.get_center()) * TILE + Vector2(TILE, TILE) * 0.5
		entities.add_child(b)
		beacons.append(b)

	var n_flasks: int = clampi(8 + int(depth / 2.0), 8, 13)
	for i in n_flasks:
		_spawn_flask()


func _spawn_flask() -> void:
	var p := _random_floor_point(120.0, 100000.0, 0.99)
	if p == Vector2.INF:
		return
	var f := FlaskScene.instantiate()
	f.position = p
	entities.add_child(f)
	flasks.append(f)


func _random_floor_point(min_d: float, max_d: float, max_light := 1.1) -> Vector2:
	if floor_tiles.is_empty():
		return Vector2.INF
	for attempt in 60:
		var t: Vector2i = floor_tiles[rng.randi_range(0, floor_tiles.size() - 1)]
		var p := Vector2(t) * TILE + Vector2(TILE, TILE) * 0.5
		if is_instance_valid(player):
			var d := p.distance_to(player.global_position)
			if d < min_d or d > max_d:
				continue
		if max_light < 1.0 and light_level_at(p) > max_light:
			continue
		var clear := true
		for b in beacons:
			if is_instance_valid(b) and b.global_position.distance_to(p) < 60.0:
				clear = false
				break
		if clear:
			return p
	return Vector2.INF


func spawn_shadow_at(pos: Vector2, kind: int) -> void:
	var s := ShadowScene.instantiate()
	s.kind = kind
	s.position = pos
	entities.add_child(s)
	shadows.append(s)
	note_seen(kind)


func summon_vigil(centre: Vector2, count: int) -> void:
	## the dark answers a beacon being woken
	Sfx.play("vigil", -6.0)
	hud.announce("THE DARK STIRS")
	for i in count:
		var ang := TAU * (float(i) / maxf(1.0, float(count))) + rng.randf() * 0.7
		var dist := rng.randf_range(150.0, 260.0)
		spawn_shadow_at(centre + Vector2(dist, 0).rotated(ang), roll_kind())


func fire_bolt(from: Vector2, dir: Vector2, damage: float, pierce: int) -> void:
	var b := BoltScene.instantiate()
	b.position = from
	b.dir = dir
	b.damage = damage
	b.pierce = pierce
	fx_root.add_child(b)


func aim_target(from: Vector2, max_range: float):
	var best = null
	var bd := max_range
	for s in shadows:
		if not is_instance_valid(s):
			continue
		var d: float = from.distance_to(s.global_position)
		if d < bd:
			bd = d
			best = s
	return best


# -------------------------------------------------------------------- loop ---
func _refresh_ambient() -> void:
	var lift := 0.0
	if boons.has("eyes"):
		lift = 0.22
	var t := clampf(dread() * 0.6 + (depth - 1) * 0.11 - lift, 0.0, 1.0)
	dark.color = AMBIENT_CALM.lerp(AMBIENT_DREAD, t)
	if lift > 0.0:
		dark.color = dark.color.lightened(0.18)


func _physics_process(delta: float) -> void:
	_refresh_lights()
	if state != PLAY:
		return
	elapsed += delta
	run_time += delta
	_refresh_ambient()
	_tut_tick(delta)

	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = spawn_interval()
		_try_spawn_shadow()
	if flask_respawn_t > 0.0:
		flask_respawn_t -= delta
		if flask_respawn_t <= 0.0:
			flask_respawn_t = -1.0
			_spawn_flask()
	if is_instance_valid(player) and player.fuel <= 0.0 and player.hp > 0:
		player.starve(delta)


func _process(delta: float) -> void:
	shake_amt = move_toward(shake_amt, 0.0, delta * 26.0)
	if is_instance_valid(player):
		var look: Vector2 = player.global_position + player.velocity * 0.16
		var k := 1.0 - pow(0.0008, delta)
		cam.global_position = cam.global_position.lerp(look, k)
	cam.offset = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake_amt

	if unlock_queue.size() > 0 and hud.unlock_free():
		hud.show_unlock(unlock_queue.pop_front())

	match state:
		MENU, BESTIARY, DEAD:
			_menu_keys()
		BOON:
			for i in 3:
				if Input.is_action_just_pressed("pick_%d" % (i + 1)) and i < boon_choices.size():
					menu_activate("boon_%d" % i)
					break
		PLAY:
			if tut_active and Input.is_action_just_pressed("skip_tut"):
				_tut_finish()


func _menu_keys() -> void:
	if Input.is_action_just_pressed("ui_upx"):
		hud.menu_move(-1)
	if Input.is_action_just_pressed("ui_downx"):
		hud.menu_move(1)
	if Input.is_action_just_pressed("begin"):
		menu_activate(hud.menu_current())
	if state == DEAD:
		if Input.is_action_just_pressed("restart"):
			menu_activate("retry")
		elif Input.is_action_just_pressed("home"):
			menu_activate("home")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			match state:
				MENU:
					# a browser tab cannot be closed from inside the game
					if not OS.has_feature("web"):
						get_tree().quit()
				BESTIARY, DEAD, PLAY:
					menu_activate("home")


func menu_activate(id: String) -> void:
	match id:
		"play":
			new_run()
		"tutorial":
			tutorial_on = not tutorial_on
			_save_progress()
			Sfx.play("blip", -12.0)
		"bestiary":
			state = BESTIARY
			hud.menu_reset()
			Sfx.play("blip", -10.0)
		"quit":
			if not OS.has_feature("web"):
				get_tree().quit()
		"back", "home":
			_go_home()
		"retry":
			new_run()
		_:
			if id.begins_with("boon_") and state == BOON:
				_take_boon(int(id.substr(5)))


func _go_home() -> void:
	if state == MENU:
		return
	state = MENU
	entities.process_mode = Node.PROCESS_MODE_DISABLED
	tut_active = false
	hud.menu_reset()
	Sfx.play("blip", -10.0)


func new_run() -> void:
	depth = 1
	_reset_run_stats()
	build_world()
	state = PLAY
	entities.process_mode = Node.PROCESS_MODE_INHERIT
	Sfx.play("blip", -8.0)
	tut_active = tutorial_on
	tut_step = 0
	tut_t = 0.0
	tut_moved = 0.0
	tut_flags = {}
	if not tut_active:
		hud.announce("DEPTH  1")


func _refresh_lights() -> void:
	light_sources.clear()
	if is_instance_valid(player):
		light_sources.append({"pos": player.global_position, "r": player.light_r})
	for b in beacons:
		if is_instance_valid(b):
			var r: float = b.active_light_radius()
			if r > 1.0:
				light_sources.append({"pos": b.global_position, "r": r})
	# embers from the Ember Trail boon count as light, so they burn and repel
	for n in get_tree().get_nodes_in_group("ember"):
		var e := n as PointLight2D
		if e != null and e.energy > 0.06:
			light_sources.append({"pos": e.global_position, "r": 52.0 * clampf(e.energy, 0.0, 1.0)})


func light_level_at(p: Vector2) -> float:
	var best := 0.0
	for s in light_sources:
		var r: float = s["r"]
		var l: float = clampf(1.0 - p.distance_to(s["pos"]) / maxf(1.0, r), 0.0, 1.0)
		best = maxf(best, l)
	return best


func _try_spawn_shadow() -> void:
	if shadows.size() >= max_shadows():
		return
	var p := _random_floor_point(190.0, 560.0, 0.08)
	if p == Vector2.INF:
		return
	spawn_shadow_at(p, roll_kind())


# -------------------------------------------------------------- tutorial ---
func tut_event(what: String) -> void:
	if tut_active:
		tut_flags[what] = true


func tut_current() -> Dictionary:
	if not tut_active or tut_step >= TUT.size():
		return {}
	return TUT[tut_step]


func _tut_next() -> void:
	tut_step += 1
	tut_t = 0.0
	if tut_step >= TUT.size():
		_tut_finish()
	else:
		Sfx.play_var("blip", -18.0)


func _tut_finish() -> void:
	tut_active = false
	tutorial_done = true
	_save_progress()
	hud.announce("DEPTH  1")


func _tut_tick(delta: float) -> void:
	if not tut_active or not is_instance_valid(player):
		return
	tut_t += delta
	tut_moved += player.velocity.length() * delta
	var step: Dictionary = TUT[tut_step]
	if tut_t < float(step["min"]):
		return

	match step["id"]:
		"move":
			if tut_moved > 150.0 or tut_t > 25.0:
				_tut_next()
		"lantern":
			_tut_next()
		"shoot":
			if shadows.is_empty() and tut_t > 1.4:
				spawn_shadow_at(player.global_position + Vector2(110, 0).rotated(randf() * TAU), WISP)
			if tut_flags.has("shot") or tut_t > 30.0:
				_tut_next()
		"flask":
			if tut_flags.has("flask") or tut_t > 28.0:
				_tut_next()
		"dash":
			if tut_flags.has("dash") or tut_t > 26.0:
				_tut_next()
		"flare":
			if tut_flags.has("flare") or tut_t > 34.0:
				_tut_next()
		"hearts":
			_tut_next()
		"beacon":
			if tut_t > 100.0:
				_tut_next()
			for b in beacons:
				if is_instance_valid(b) and not b.lit \
						and b.global_position.distance_to(player.global_position) < 80.0:
					_tut_next()
					break
		"vigil":
			if beacons_lit >= 1 or tut_t > 150.0:
				_tut_next()
		"dread":
			_tut_next()
		"descend":
			pass


# -------------------------------------------------------------- callbacks ---
func on_beacon_lit(b) -> void:
	beacons_lit += 1
	run_beacons += 1
	var ward: float = 0.0
	var reward: float = b.FUEL_REWARD
	var clear_r: float = b.CLEAR_R
	if is_instance_valid(player):
		ward = player.mod_ward
		player.add_fuel(reward + ward)
	clear_r += ward * 2.4
	shake(11.0)
	hud.flash(Color(1.0, 0.86, 0.55, 0.36))
	puff(b.global_position, Color(1.0, 0.78, 0.38), 38, 200.0)
	for s in shadows.duplicate():
		if is_instance_valid(s) and s.global_position.distance_to(b.global_position) < clear_r:
			s.die(true)
	hud.announce("BEACON LIT   %d / %d" % [beacons_lit, beacons.size()])
	if beacons_lit >= beacons.size():
		_open_descent()


func _open_descent() -> void:
	## room centres are always carved floor, so the stair is never walled in
	var best: Vector2 = player.global_position + Vector2(80, 0)
	var bd := -1.0
	for r in rooms:
		var c := Vector2(r.get_center()) * TILE + Vector2(TILE, TILE) * 0.5
		var clash := false
		for b in beacons:
			if is_instance_valid(b) and b.global_position.distance_to(c) < 46.0:
				clash = true
				break
		if clash:
			continue
		var d := c.distance_to(player.global_position)
		if d > bd:
			bd = d
			best = c
	stair = StairScene.instantiate()
	stair.position = best
	entities.add_child(stair)
	hud.announce("THE WAY DOWN OPENS")
	hud.flash(Color(0.55, 0.7, 1.0, 0.3))
	Sfx.play("ignite", -6.0)


func descend() -> void:
	if state != PLAY:
		return
	state = BOON
	entities.process_mode = Node.PROCESS_MODE_DISABLED
	carry_hp = player.hp
	carry_fuel = player.fuel
	run_banished += shadows_banished
	if tut_active:
		_tut_finish()
	Sfx.play("descend", -4.0)
	hud.flash(Color(0.6, 0.75, 1.0, 0.45))
	hud.menu_reset()

	var pool := []
	for b in BOONS:
		var repeatable: bool = b["id"] in ["heart", "mend", "tank", "oil", "wick", "keen"]
		if repeatable or not boons.has(b["id"]):
			pool.append(b)
	pool.shuffle()
	boon_choices = pool.slice(0, 3)


func _take_boon(i: int) -> void:
	if i < 0 or i >= boon_choices.size():
		return
	var b: Dictionary = boon_choices[i]
	boons.append(b["id"])
	Sfx.play("boon", -5.0)
	depth += 1
	best_depth = maxi(best_depth, depth)
	_save_progress()
	build_world()
	if is_instance_valid(player):
		player.on_boon_taken(b["id"])
		carry_hp = player.hp
		carry_fuel = player.fuel
	boon_choices.clear()
	state = PLAY
	entities.process_mode = Node.PROCESS_MODE_INHERIT
	hud.announce("DEPTH  %d" % depth)


func on_flask_taken() -> void:
	flask_respawn_t = 5.0
	run_flasks += 1
	tut_event("flask")


func on_shadow_banished(kind: int, pos: Vector2) -> void:
	shadows_banished += 1
	kills[kind] = int(kills.get(kind, 0)) + 1
	if is_instance_valid(player) and player.mod_scavenge > 0.0 and rng.randf() < player.mod_scavenge:
		drop_fuel(pos)


func _on_player_died() -> void:
	state = DEAD
	run_banished += shadows_banished
	best_depth = maxi(best_depth, depth)
	_save_progress()
	entities.process_mode = Node.PROCESS_MODE_DISABLED
	tut_active = false
	hud.menu_reset()
	shake(16.0)
	hud.flash(Color(0.8, 0.1, 0.2, 0.5))
	puff(player.global_position, Color(1.0, 0.7, 0.4), 44, 210.0)
	Sfx.play("lose", -6.0)


func nearest_unlit_beacon():
	if not is_instance_valid(player):
		return null
	if is_instance_valid(stair):
		return stair
	var best = null
	var bd := INF
	for b in beacons:
		if is_instance_valid(b) and not b.lit:
			var d: float = b.global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = b
	return best


func boon_name(id: String) -> String:
	for b in BOONS:
		if b["id"] == id:
			return b["name"]
	return id


# ---------------------------------------------------------------- effects ---
func shake(a: float) -> void:
	shake_amt = maxf(shake_amt, a)


func puff(pos: Vector2, col: Color, amount: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = SparkTex
	p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	p.position = pos
	p.amount = maxi(1, amount)
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.direction = Vector2(0, -1)
	p.gravity = Vector2(0, 24)
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.damping_min = 50.0
	p.damping_max = 110.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.4
	p.color = col
	p.emitting = true
	fx_root.add_child(p)
	_reap(p, 1.4)


func drop_fuel(pos: Vector2) -> void:
	## Scavenger boon: a banished shadow leaves a splash of oil behind
	var f := FlaskScene.instantiate()
	f.position = pos
	f.small = true
	entities.add_child(f)
	flasks.append(f)


func ember_trail(pos: Vector2) -> void:
	## Ember Trail boon: a burning mote that hurts shadows for a few seconds
	var l := PointLight2D.new()
	l.texture = FlareTex
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.color = Color(1.0, 0.62, 0.28)
	l.energy = 1.1
	l.position = pos
	l.texture_scale = 0.32
	l.add_to_group("ember")
	fx_root.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, 2.2)
	_reap(l, 2.3)


func do_flare(pos: Vector2, radius: float) -> void:
	Sfx.play("flare", -3.0)
	shake(9.0)
	hud.flash(Color(1.0, 0.92, 0.72, 0.30))
	puff(pos, Color(1.0, 0.87, 0.55), 30, 230.0)

	var l := PointLight2D.new()
	l.texture = FlareTex
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	l.color = Color(1.0, 0.87, 0.62)
	l.energy = 3.2
	l.position = pos
	l.texture_scale = radius / 128.0 * 0.35
	fx_root.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "texture_scale", radius / 128.0 * 1.3, 0.32) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "energy", 0.0, 0.44)
	_reap(l, 0.6)

	for s in shadows.duplicate():
		if is_instance_valid(s) and s.global_position.distance_to(pos) < radius:
			s.hit_flare(FLARE_DAMAGE, pos)


func _reap(n: Node, after: float) -> void:
	## the timer lives INSIDE the node it reaps, so if the node is freed early
	## (a rebuild between depths, say) the timer dies with it and nothing is
	## left holding a dangling reference
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = after
	t.autostart = true
	n.add_child(t)
	t.timeout.connect(n.queue_free)
