extends Node2D
## Draws the whole ruin in one retained draw list. Cheaper than thousands of
## Sprite2D nodes and it still takes 2D lighting like any other CanvasItem.

const FloorTex: Texture2D = preload("res://assets/sprites/floor.png")
const WallTex: Texture2D = preload("res://assets/sprites/wall.png")

var grid := PackedByteArray()
var variants := PackedByteArray()
var w := 0
var h := 0
var tile := 32


func setup(g: PackedByteArray, v: PackedByteArray, mw: int, mh: int, ts: int) -> void:
	grid = g
	variants = v
	w = mw
	h = mh
	tile = ts
	queue_redraw()


func _solid(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return true
	return grid[y * w + x] == 1


func _near_floor(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not _solid(x + dx, y + dy):
				return true
	return false


func _draw() -> void:
	if w == 0:
		return
	var size := Vector2(tile, tile)
	for y in h:
		for x in w:
			var i := y * w + x
			var at := Vector2(x * tile, y * tile)
			if grid[i] == 0:
				var fv: int = variants[i] % 4
				draw_texture_rect_region(FloorTex, Rect2(at, size), Rect2(fv * 32, 0, 32, 32))
			elif _near_floor(x, y):
				var face := 2 if not _solid(x, y + 1) else 0
				var wv: int = (variants[i] % 2) + face
				draw_texture_rect_region(WallTex, Rect2(at, size), Rect2(wv * 32, 0, 32, 32))
