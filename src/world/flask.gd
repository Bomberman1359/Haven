extends Node2D
## Lamp oil. Walk over it.

const PICK_R := 13.0
const AMOUNT := 30.0

var t := 0.0
var small := false
var game

@onready var body: Sprite2D = $Body
@onready var glow: PointLight2D = $Glow


func _ready() -> void:
	game = get_tree().get_first_node_in_group("game")
	add_to_group("flask")
	t = randf() * TAU
	if small:
		scale = Vector2.ONE * 0.7
		glow.texture_scale *= 0.7


func _process(delta: float) -> void:
	t += delta * 2.3
	body.position.y = sin(t) * 1.9
	body.frame = int(t * 1.3) % 2
	glow.energy = 0.44 + sin(t * 1.6) * 0.09

	var p = game.player
	if is_instance_valid(p) and p.alive and p.global_position.distance_to(global_position) < PICK_R:
		p.add_fuel(p.flask_value(AMOUNT) * (0.5 if small else 1.0))
		Sfx.play_var("pickup", -9.0)
		game.puff(global_position, Color(1.0, 0.76, 0.36), 11, 75.0)
		game.flasks.erase(self)
		if not small:
			game.on_flask_taken()
		queue_free()
