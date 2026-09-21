extends Node2D
## A snapped-off piece of your own lantern light. Travels fast, dies on the
## first wall, and counts as light, so a splitter still splits when one kills
## it, and a brute still shrugs most of it off.

const SPEED := 440.0
const LIFE := 0.85
const HIT_R := 10.0

var dir := Vector2.RIGHT
var damage := 5.0
var pierce := 0
var life := LIFE
var struck: Array = []
var game

@onready var body: Sprite2D = $Body
@onready var glow: PointLight2D = $Glow


func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")
	add_to_group("bolt")
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_fizzle()
		return

	global_position += dir * SPEED * delta
	body.frame = int(Time.get_ticks_msec() * 0.025) % 2
	glow.energy = 0.7 + sin(Time.get_ticks_msec() * 0.02) * 0.1

	for s in game.shadows:
		if not is_instance_valid(s) or struck.has(s):
			continue
		var reach: float = HIT_R + 5.0 * s.scale.x
		if global_position.distance_to(s.global_position) < reach:
			struck.append(s)
			s.hit_bolt(damage, global_position)
			game.puff(global_position, Color(1.0, 0.86, 0.52), 5, 70.0)
			if struck.size() > pierce:
				queue_free()
				return

	var tx := int(global_position.x / float(game.TILE))
	var ty := int(global_position.y / float(game.TILE))
	if game.solid(tx, ty):
		_fizzle()


func _fizzle() -> void:
	if is_instance_valid(game):
		game.puff(global_position, Color(1.0, 0.8, 0.45), 4, 50.0)
	queue_free()
