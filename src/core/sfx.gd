extends Node
## Autoloaded audio bus. A small pool of one-shot players plus the looping ambience.
## Every wav in assets/sfx was generated from scratch, no samples.

const KEYS := ["step", "dash", "flare", "ignite", "pickup", "hurt", "shadow", "win", "lose", "blip", "vigil", "descend", "boon", "shoot", "discover"]
const POOL_SIZE := 14

var _bank := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in KEYS:
		var path := "res://assets/audio/%s.wav" % k
		if ResourceLoader.exists(path):
			_bank[k] = load(path)
	for i in POOL_SIZE:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_pool.append(pl)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	var mpath := "res://assets/audio/music.wav"
	if ResourceLoader.exists(mpath):
		_music.stream = load(mpath)
		_music.volume_db = -15.0
		_music.finished.connect(_loop_music)
		_music.play()


func _loop_music() -> void:
	_music.play()


func play(key: String, vol_db := -6.0, pitch := 1.0) -> void:
	if not _bank.has(key):
		return
	var pl := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	pl.stream = _bank[key]
	pl.volume_db = vol_db
	pl.pitch_scale = clampf(pitch, 0.25, 3.0)
	pl.play()


func play_var(key: String, vol_db := -6.0, spread := 0.12) -> void:
	play(key, vol_db, 1.0 + randf_range(-spread, spread))
