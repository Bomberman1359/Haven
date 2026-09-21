extends CharacterBody2D
## The lantern keeper. Fuel is your light radius, your dash, your bolts and
## your flare all at once. Everything you do spends the same resource.

signal died

const BASE_SPEED := 118.0
const ACCEL := 900.0
const FRICTION := 1250.0

const DASH_SPEED := 345.0
const DASH_TIME := 0.16
const DASH_COST := 5.0

const FUEL_BURN := 2.1
const FLARE_RADIUS := 158.0
const BOLT_RANGE := 300.0
const LIGHT_MIN := 38.0
const LIGHT_MAX := 132.0

var max_hp := 5
var max_fuel := 150.0
var flare_cost := 35.0
var flare_cd_max := 1.35
var dash_cd_max := 0.72

var bolt_cost := 2.5
var bolt_cd_max := 0.30
var bolt_damage := 5.0
var bolt_pierce := 0
var bolt_count := 1

# boon modifiers
var mod_burn := 1.0
var mod_light := 1.0
var mod_speed := 1.0
var mod_flask := 0.0
var mod_keen := 1.0
var mod_ward := 0.0
var mod_hearth := 1.0
var mod_scavenge := 0.0
var has_revive := false
var has_trail := false
var revive_used := false
var invuln_time := 0.95

var fuel := 150.0
var hp := 5
var alive := true
var invuln := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var flare_cd := 0.0
var bolt_cd := 0.0
var trail_t := 0.0
var light_r := LIGHT_MAX
var facing := 1
var anim := 0.0
var step_t := 0.0
var starve_t := 0.0
var drain_flash := 0.0

@onready var body: Sprite2D = $Body
@onready var lantern: Sprite2D = $Lantern
@onready var lamp: PointLight2D = $Light
var game


func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")
	add_to_group("player")
	fuel = max_fuel
	hp = max_hp


func apply_boon(id: String) -> void:
	## permanent modifiers only. Instant effects live in on_boon_taken
	match id:
		"wick": mod_burn *= 0.80
		"glass": mod_light *= 1.18
		"tank": max_fuel += 30.0
		"oil": mod_flask += 14.0
		"keen": mod_keen *= 1.32
		"flare":
			flare_cost = maxf(12.0, flare_cost - 7.0)
			flare_cd_max = maxf(0.7, flare_cd_max - 0.28)
		"steady":
			bolt_cost *= 0.7
			bolt_cd_max = maxf(0.16, bolt_cd_max - 0.08)
		"twin":
			bolt_count += 1
			bolt_cost *= 1.25
		"pierce": bolt_pierce += 1
		"heart": max_hp += 1
		"mend": invuln_time += 0.3
		"revive": has_revive = true
		"boots":
			mod_speed *= 1.11
			dash_cd_max = maxf(0.34, dash_cd_max - 0.12)
		"trail": has_trail = true
		"ward": mod_ward += 25.0
		"hearth": mod_hearth *= 1.7
		"scavenge": mod_scavenge += 0.18
		"eyes": pass


func on_boon_taken(id: String) -> void:
	match id:
		"heart": hp = mini(max_hp, hp + 1)
		"mend": hp = mini(max_hp, hp + 1)
		"tank": fuel = max_fuel


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		move_and_slide()
		return

	invuln = maxf(0.0, invuln - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	flare_cd = maxf(0.0, flare_cd - delta)
	bolt_cd = maxf(0.0, bolt_cd - delta)
	drain_flash = maxf(0.0, drain_flash - delta)

	var burn: float = FUEL_BURN * mod_burn * game.burn_mult()
	fuel = maxf(0.0, fuel - burn * delta)

	var top: float = BASE_SPEED * mod_speed
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 1.0:
		dir = dir.normalized()

	if dash_t > 0.0:
		dash_t -= delta
		if has_trail:
			trail_t -= delta
			if trail_t <= 0.0:
				trail_t = 0.045
				game.ember_trail(global_position)
	else:
		if dir != Vector2.ZERO:
			velocity = velocity.move_toward(dir * top, ACCEL * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 \
				and dir != Vector2.ZERO and fuel >= DASH_COST:
			dash_t = DASH_TIME
			dash_cd = dash_cd_max
			fuel -= DASH_COST
			velocity = dir * DASH_SPEED
			invuln = maxf(invuln, DASH_TIME + 0.06)
			Sfx.play_var("dash", -13.0)
			game.puff(global_position, Color(1.0, 0.82, 0.5), 9, 55.0)
			game.tut_event("dash")

		if Input.is_action_just_pressed("flare") and flare_cd <= 0.0 and fuel >= flare_cost:
			fuel -= flare_cost
			flare_cd = flare_cd_max
			game.do_flare(global_position, FLARE_RADIUS)
			game.tut_event("flare")

	if Input.is_action_pressed("shoot"):
		try_shoot()

	move_and_slide()
	_animate(delta)
	_update_lantern()


func try_shoot() -> void:
	if not alive or bolt_cd > 0.0 or fuel < bolt_cost:
		return
	bolt_cd = bolt_cd_max
	fuel -= bolt_cost

	var muzzle: Vector2 = global_position + Vector2(8.0 * facing, 2.0)
	var aim := Vector2(facing, 0.0)
	var target = game.aim_target(global_position, BOLT_RANGE)
	if target != null:
		aim = (target.global_position - muzzle).normalized()
		facing = 1 if aim.x > 0.0 else -1

	var spread := 0.0 if bolt_count <= 1 else 0.13
	for i in bolt_count:
		var off := 0.0 if bolt_count <= 1 else lerpf(-spread, spread, float(i) / (bolt_count - 1.0))
		game.fire_bolt(muzzle, aim.rotated(off), bolt_damage, bolt_pierce)
	Sfx.play_var("shoot", -15.0, 0.14)
	game.tut_event("shot")


func _animate(delta: float) -> void:
	var spd := velocity.length()
	if spd > 7.0:
		anim += delta * (2.4 + spd * 0.05)
		body.frame = int(anim) % 4
		if absf(velocity.x) > 4.0:
			facing = 1 if velocity.x > 0.0 else -1
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.36
			Sfx.play_var("step", -24.0, 0.2)
	else:
		anim = 0.0
		body.frame = 0
	body.flip_h = facing < 0

	var a := 1.0
	if invuln > 0.0 and fmod(invuln * 16.0, 1.0) < 0.5:
		a = 0.4
	body.modulate = Color(1, 1, 1, a)
	if drain_flash > 0.0:
		body.modulate = Color(0.55, 1.0, 0.9, a)


func _update_lantern() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var ratio := fuel / max_fuel
	light_r = lerpf(LIGHT_MIN, LIGHT_MAX, ratio) * mod_light

	var flick := 1.0 + sin(t * 11.0) * 0.035 + sin(t * 23.7) * 0.02 + randf() * 0.025
	lamp.texture_scale = (light_r / 128.0) * flick
	lamp.energy = lerpf(0.55, 1.5, ratio) * flick
	lamp.color = Color(1.0, 0.79, 0.47).lerp(Color(0.62, 0.55, 0.78), 1.0 - ratio)

	lantern.position = Vector2(8.0 * facing, 3.0 + sin(t * 4.0) * 0.9)
	lantern.modulate = Color(1, 1, 1).lerp(Color(0.45, 0.45, 0.58), clampf(1.0 - ratio, 0.0, 0.8))


func starve(delta: float) -> void:
	## lantern is dry: the dark closes in on its own
	starve_t += delta
	if starve_t >= 2.4:
		starve_t = 0.0
		damage(1, global_position + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 30.0)


func add_fuel(x: float) -> void:
	fuel = minf(max_fuel, fuel + x)


func flask_value(base: float) -> float:
	return base + mod_flask


func drain(x: float) -> void:
	if not alive:
		return
	fuel = maxf(0.0, fuel - x)
	drain_flash = 0.1


func damage(amount: int, from: Vector2) -> void:
	if not alive or invuln > 0.0:
		return
	hp -= amount
	invuln = invuln_time
	var away := global_position - from
	velocity = (away.normalized() if away.length() > 0.1 else Vector2.RIGHT) * 195.0
	Sfx.play("hurt", -7.0)
	game.shake(7.0 + amount * 2.0)
	game.hud.flash(Color(0.95, 0.2, 0.3, 0.3))
	game.puff(global_position, Color(0.95, 0.35, 0.45), 12, 90.0)
	if hp <= 0:
		if has_revive and not revive_used:
			revive_used = true
			hp = mini(max_hp, 2)
			invuln = 2.2
			fuel = maxf(fuel, 45.0)
			Sfx.play("ignite", -3.0)
			game.shake(14.0)
			game.hud.flash(Color(1.0, 0.92, 0.7, 0.55))
			game.hud.announce("SECOND WIND")
			game.puff(global_position, Color(1.0, 0.9, 0.6), 40, 200.0)
			return
		hp = 0
		alive = false
		died.emit()
