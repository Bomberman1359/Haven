extends Node2D
## The way down. Appears once every beacon on this depth is burning.

const REACH := 20.0

var t := 0.0
var game

@onready var body: Sprite2D = $Body
@onready var glow: PointLight2D = $Glow


func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")
	add_to_group("stair")
	t = randf() * TAU


func _process(delta: float) -> void:
	t += delta * 3.0
	body.frame = int(t) % 4
	glow.energy = 0.95 + sin(t * 0.8) * 0.2

	var p = game.player
	if is_instance_valid(p) and p.alive and p.global_position.distance_to(global_position) < REACH:
		game.descend()
