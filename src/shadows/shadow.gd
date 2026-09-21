extends Node2D
## Every shadow walks through walls, because the dark has no geometry, so light is
## the only thing that stops them. What light DOES to one depends on its kind.
##
##   WISP      the basic thing. Light burns it, flares delete it.
##   HUSK      slab of dark. Twice the health, and it leans into the glare.
##   STALKER   sprints in the dark, freezes solid the instant light touches it.
##   LEECH     never touches you. Hangs at the edge and drinks your lantern.
##   SPLITTER  kill it with light and it becomes two wisps. Flares kill it clean.
##   BRUTE     immune to lantern light entirely. Only a flare hurts it.

const WISP := 0
const HUSK := 1
const STALKER := 2
const LEECH := 3
const SPLITTER := 4
const BRUTE := 5

const TEX := {
	WISP: preload("res://assets/sprites/wisp.png"),
	HUSK: preload("res://assets/sprites/husk.png"),
	STALKER: preload("res://assets/sprites/stalker.png"),
	LEECH: preload("res://assets/sprites/leech.png"),
	SPLITTER: preload("res://assets/sprites/splitter.png"),
	BRUTE: preload("res://assets/sprites/brute.png"),
}

const STATS := {
	#        hp     speed   dmg  contact  light-mult  glow colour            glow size
	# "light" scales how fast your lantern burns it, "push" how far light shoves
	# it back. A husk leans into the glare; a brute does not care at all.
	WISP: {"hp": 4.0, "speed": 56.0, "dmg": 1, "contact": 13.0, "light": 1.0,
		"push": 1.0, "bolt": 1.0, "glow": Color(1.0, 0.24, 0.36), "gs": 0.22},
	HUSK: {"hp": 9.0, "speed": 40.0, "dmg": 1, "contact": 16.0, "light": 0.8,
		"push": 0.45, "bolt": 0.9, "glow": Color(1.0, 0.48, 0.22), "gs": 0.30},
	STALKER: {"hp": 3.0, "speed": 138.0, "dmg": 1, "contact": 12.0, "light": 1.3,
		"push": 0.0, "bolt": 1.0, "glow": Color(0.85, 0.95, 1.0), "gs": 0.20},
	LEECH: {"hp": 5.5, "speed": 54.0, "dmg": 0, "contact": 0.0, "light": 1.0,
		"push": 0.0, "bolt": 1.0, "glow": Color(0.35, 1.0, 0.82), "gs": 0.26},
	SPLITTER: {"hp": 7.0, "speed": 62.0, "dmg": 1, "contact": 13.0, "light": 1.0,
		"push": 1.0, "bolt": 1.0, "glow": Color(1.0, 0.82, 0.35), "gs": 0.24},
	BRUTE: {"hp": 28.0, "speed": 33.0, "dmg": 2, "contact": 20.0, "light": 0.0,
		"push": 0.15, "bolt": 0.5, "glow": Color(1.0, 0.36, 0.16), "gs": 0.40},
}

const LIGHT_DPS := 2.9
const LIGHT_FLOOR := 0.30
const SEPARATION_R := 24.0
const LEECH_NEAR := 78.0
const LEECH_FAR := 118.0
const LEECH_REACH := 170.0
const LEECH_DRAIN := 7.5

var kind := WISP
var hp := 4.0
var max_hp := 4.0
var speed := 55.0
var dmg := 1
var contact_r := 13.0
var light_mult := 1.0
var push_mult := 1.0
var bolt_mult := 1.0
var wobble := 0.0
var stun := 0.0
var frozen := 0.0
var vel := Vector2.ZERO
var exposure := 0.0
var game

@onready var body: Sprite2D = $Body
@onready var glow: PointLight2D = $Glow


func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")
	add_to_group("shadow")
	wobble = randf() * TAU

	var st: Dictionary = STATS[kind]
	var sm: float = game.speed_mult()
	var hm: float = game.hp_mult()
	hp = st["hp"] * hm
	max_hp = hp
	speed = st["speed"] * sm * randf_range(0.92, 1.08)
	dmg = st["dmg"]
	contact_r = st["contact"]
	light_mult = st["light"]
	push_mult = st["push"]
	bolt_mult = st["bolt"]

	body.texture = TEX[kind]
	body.hframes = 4
	body.frame = randi() % 4
	glow.color = st["glow"]
	glow.texture_scale = st["gs"]
	glow.energy = 0.6

	scale = Vector2.ONE * randf_range(0.9, 1.1)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.45)


func _physics_process(delta: float) -> void:
	wobble += delta * 3.1
	body.frame = int(wobble * 1.7) % 4

	var target = game.player
	if not is_instance_valid(target) or not target.alive:
		return

	# how much light is on me, and which way is away from the brightest source
	var lit := 0.0
	var away := Vector2.RIGHT
	for s in game.light_sources:
		var sp: Vector2 = s["pos"]
		var sr: float = s["r"]
		sr = maxf(1.0, sr)
		var d := global_position.distance_to(sp)
		var l := clampf(1.0 - d / sr, 0.0, 1.0)
		if l > lit:
			lit = l
			away = (global_position - sp).normalized() if d > 0.5 else Vector2.RIGHT
	exposure = lit

	var keen: float = target.mod_keen
	if lit > LIGHT_FLOOR and light_mult > 0.0:
		hp -= lit * LIGHT_DPS * light_mult * keen * delta
		if hp <= 0.0:
			die(false)
			return

	stun = maxf(0.0, stun - delta)
	frozen = maxf(0.0, frozen - delta)

	var to_player: Vector2 = target.global_position - global_position
	var dist: float = to_player.length()
	var chase: Vector2 = to_player.normalized() if dist > 0.1 else Vector2.RIGHT
	var drift := Vector2(-chase.y, chase.x) * sin(wobble * 1.45) * 0.5
	var desired: Vector2 = (chase + drift).normalized() * speed

	match kind:
		STALKER:
			# light does not just hurt it, it pins it in place
			if lit > LIGHT_FLOOR:
				frozen = 0.18
			if frozen > 0.0:
				desired = Vector2.ZERO
				vel = vel * 0.25
		LEECH:
			# hover at the edge of your reach and drink the lantern
			if dist < LEECH_NEAR:
				desired = -chase * speed
			elif dist < LEECH_FAR:
				desired = Vector2(-chase.y, chase.x) * speed * 0.9
			if dist < LEECH_REACH:
				target.drain(LEECH_DRAIN * delta)
				_draw_tether()
		BRUTE:
			if lit > LIGHT_FLOOR:
				desired *= 0.82

	if lit > LIGHT_FLOOR and push_mult > 0.0:
		var push := (lit - LIGHT_FLOOR) / (1.0 - LIGHT_FLOOR)
		desired = desired.lerp(away * speed * 1.3, clampf(push * 1.7 * push_mult, 0.0, 1.0))

	# keep the swarm from stacking into one sprite
	var apart := Vector2.ZERO
	for o in game.shadows:
		if o == self or not is_instance_valid(o):
			continue
		var diff: Vector2 = global_position - o.global_position
		var od: float = diff.length()
		if od > 0.1 and od < SEPARATION_R:
			apart += diff / od * (1.0 - od / SEPARATION_R)
	desired += apart * speed * 0.8

	if stun > 0.0:
		desired = vel
	vel = vel.lerp(desired, 1.0 - pow(0.002, delta))
	global_position += vel * delta

	var f := clampf(lit, 0.0, 1.0)
	if kind == STALKER and frozen > 0.0:
		body.modulate = Color(1.6, 1.7, 1.9, 1.0)
		glow.energy = 1.1
	elif kind == BRUTE:
		body.modulate = Color(1, 1, 1, 1)
		glow.energy = lerpf(0.75, 0.95, f)
	else:
		body.modulate = Color(1, 1, 1, lerpf(1.0, 0.4, f))
		glow.energy = lerpf(0.6, 0.12, f)

	if dmg > 0 and dist < contact_r * scale.x and stun <= 0.0:
		target.damage(dmg, global_position)
		stun = 0.6
		vel = -chase * 240.0


func _draw_tether() -> void:
	if randf() < 0.14:
		var target = game.player
		var mid: Vector2 = global_position.lerp(target.global_position, randf())
		game.puff(mid, Color(0.35, 1.0, 0.82), 1, 18.0)


func hit_bolt(amount: float, from: Vector2) -> void:
	## a bolt is still lantern light, so a brute mostly shrugs it off and a
	## splitter still comes apart rather than dying clean
	hp -= amount * bolt_mult
	var push: Vector2 = (global_position - from).normalized() if global_position.distance_to(from) > 0.5 \
		else Vector2.RIGHT
	vel += push * 90.0
	if hp <= 0.0:
		die(false)


func hit_flare(amount: float, from: Vector2) -> void:
	hp -= amount
	var push: Vector2 = (global_position - from).normalized() if global_position.distance_to(from) > 0.5 \
		else Vector2.RIGHT
	vel = push * 210.0
	stun = 0.3
	if hp <= 0.0:
		die(true)
	else:
		game.puff(global_position, Color(1.0, 0.8, 0.5), 5, 60.0)


func die(by_flare: bool) -> void:
	if not is_instance_valid(game):
		queue_free()
		return
	if kind == SPLITTER and not by_flare:
		# light alone only breaks it apart
		for i in 2:
			var off := Vector2(11, 0).rotated(randf() * TAU)
			game.spawn_shadow_at(global_position + off, WISP)
			var kid = game.shadows[game.shadows.size() - 1]
			if is_instance_valid(kid):
				kid.hp = 2.6
				kid.max_hp = 2.6
				kid.scale = Vector2.ONE * 0.68
				kid.speed *= 1.25
		game.puff(global_position, Color(1.0, 0.82, 0.35), 12, 110.0)
	else:
		var col: Color = STATS[kind]["glow"]
		var n := 26 if kind == BRUTE else (18 if kind == HUSK else 14)
		game.puff(global_position, col, n, 95.0 + (60.0 if kind == BRUTE else 0.0))
		if kind == BRUTE:
			game.shake(7.0)
	Sfx.play_var("shadow", -16.0, 0.18)
	game.shadows.erase(self)
	game.on_shadow_banished(kind, global_position)
	queue_free()
