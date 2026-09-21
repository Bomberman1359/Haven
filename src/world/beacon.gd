extends Node2D
## A dead brazier. Holding E starts a vigil: the beacon takes a long time to
## catch, the dark sends a wave the moment you begin, and letting go lets the
## charge bleed back out. The growing flame is its own reward, because it lights up
## while you hold it, so the longer you last the safer the ground gets.

const INTERACT_R := 42.0
const LIGHT_R := 232.0
const FUEL_REWARD := 50.0
const CLEAR_R := 268.0
const REGEN_R := 92.0
const REGEN_RATE := 9.0
const DRAIN_RATE := 0.55

var lit := false
var charge := 0.0
var charge_time := 4.0
var vigil_called := false
var flicker := 0.0
var regen_r := REGEN_R
var game

@onready var body: Sprite2D = $Body
@onready var lamp: PointLight2D = $Light
var embers: CPUParticles2D
var prompt: Label


func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")
	add_to_group("beacon")
	flicker = randf() * TAU
	lamp.enabled = false
	body.frame = 0

	embers = CPUParticles2D.new()
	embers.texture = preload("res://assets/sprites/spark.png")
	embers.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	embers.position = Vector2(0, -26)
	embers.amount = 26
	embers.lifetime = 1.9
	embers.spread = 26.0
	embers.direction = Vector2(0, -1)
	embers.gravity = Vector2(0, -16)
	embers.initial_velocity_min = 14.0
	embers.initial_velocity_max = 34.0
	embers.scale_amount_min = 0.2
	embers.scale_amount_max = 0.6
	embers.color = Color(1.0, 0.74, 0.36, 0.9)
	embers.emitting = false
	add_child(embers)

	prompt = Label.new()
	prompt.text = "HOLD  E"
	prompt.position = Vector2(-34, -66)
	prompt.size = Vector2(68, 14)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 9)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	prompt.visible = false
	add_child(prompt)


func active_light_radius() -> float:
	## what this beacon contributes to the world's light right now
	if lit:
		return LIGHT_R
	if charge > 0.01:
		return lerpf(0.0, LIGHT_R * 0.72, charge / maxf(0.1, charge_time))
	return 0.0


func charging() -> bool:
	return not lit and charge > 0.01


func charge_frac() -> float:
	return clampf(charge / maxf(0.1, charge_time), 0.0, 1.0)


func _process(delta: float) -> void:
	var p = game.player
	var near: bool = is_instance_valid(p) and p.alive \
		and p.global_position.distance_to(global_position) < INTERACT_R

	if lit:
		flicker += delta
		body.frame = 1 + int(flicker * 10.0) % 4
		lamp.energy = 1.5 + sin(flicker * 7.4) * 0.12 + sin(flicker * 13.3) * 0.05
		lamp.texture_scale = (LIGHT_R / 128.0) * (1.0 + sin(flicker * 5.2) * 0.02)
		if is_instance_valid(p):
			regen_r = REGEN_R * p.mod_hearth
			if p.global_position.distance_to(global_position) < regen_r:
				p.add_fuel(REGEN_RATE * p.mod_hearth * delta)
		queue_redraw()
		return

	prompt.visible = near and charge <= 0.01

	if near and Input.is_action_pressed("interact"):
		if not vigil_called:
			vigil_called = true
			charge_time = 3.0 + game.depth * 0.25 + game.beacons_lit * 0.55
			game.summon_vigil(global_position, 3 + game.depth + game.beacons_lit)
			game.hud.flash(Color(0.7, 0.45, 0.9, 0.22))
		charge += delta
		if int(charge * 3.0) != int((charge - delta) * 3.0):
			Sfx.play_var("blip", -26.0, 0.25)
		if charge >= charge_time:
			ignite()
	else:
		charge = maxf(0.0, charge - delta * DRAIN_RATE)
		if charge <= 0.01:
			vigil_called = false

	# the half-lit brazier flickers while you hold it
	if charge > 0.01:
		flicker += delta
		body.frame = 1 + int(flicker * 6.0) % 4
		lamp.enabled = true
		var f := charge_frac()
		lamp.energy = lerpf(0.2, 0.9, f)
		lamp.texture_scale = maxf(0.6, active_light_radius() / 128.0)
		embers.emitting = f > 0.35
	else:
		lamp.enabled = false
		body.frame = 0
		embers.emitting = false
	queue_redraw()


func ignite() -> void:
	lit = true
	charge = charge_time
	lamp.enabled = true
	body.frame = 1
	embers.emitting = true
	embers.amount = 34
	prompt.visible = false
	queue_redraw()
	Sfx.play("ignite", -4.0)
	game.on_beacon_lit(self)


func _draw() -> void:
	if lit:
		var pulse := 1.0 + sin(flicker * 2.4) * 0.03
		draw_arc(Vector2(0, 6), regen_r * pulse, 0.0, TAU, 54,
			Color(1.0, 0.78, 0.42, 0.10), 2.0)
		draw_arc(Vector2(0, 6), regen_r * 0.62 * pulse, 0.0, TAU, 44,
			Color(1.0, 0.86, 0.55, 0.07), 1.5)
		return
	if charge <= 0.02:
		return
	var at := Vector2(0, -60)
	var f := charge_frac()
	draw_arc(at, 14.0, 0.0, TAU, 32, Color(0.5, 0.48, 0.6, 0.45), 1.5)
	draw_arc(at, 14.0, -PI * 0.5, -PI * 0.5 + TAU * f, 32,
		Color(1.0, 0.85, 0.5, 0.95), 3.0)
