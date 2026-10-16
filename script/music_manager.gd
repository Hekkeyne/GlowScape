extends Node
@export var autoplay_music := true
@export var built_in_tracks: Array[AudioStream] = []
var _bag: Array[AudioStream] = []
var _last_stream: AudioStream = null
@onready var player: AudioStreamPlayer = $AudioStreamPlayer

func _ready() -> void:
	player.finished.connect(_on_player_finished)
	if autoplay_music:
		start_music()

func start_music() -> void:
	if not player.playing:
		play_next()

func stop_music() -> void:
	player.stop()
	_bag.clear()
	_last_stream = null

func play_next() -> void:
	if built_in_tracks.is_empty():
		player.stop()
		return
	if _bag.is_empty():
		_refill_bag()
	var next := _pop_next_valid_stream()
	if next == null:
		player.stop()
		return
	_last_stream = next
	_disable_loop_if_needed(next)
	player.stream = next
	player.play()

func _refill_bag() -> void:
	_bag.clear()
	for track in built_in_tracks:
		if track != null:
			_bag.append(track)
	_bag.shuffle()
	if _bag.size() > 1 and _last_stream != null and _bag[0] == _last_stream:
		var swap_index := randi_range(1, _bag.size() - 1)
		var temp: AudioStream = _bag[0]
		_bag[0] = _bag[swap_index]
		_bag[swap_index] = temp

func _pop_next_valid_stream() -> AudioStream:
	while not _bag.is_empty():
		var track: AudioStream = _bag.pop_front()
		if track != null:
			return track
	return null

func _disable_loop_if_needed(track: AudioStream) -> void:
	if track is AudioStreamWAV:
		track.loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif "loop" in track:
		track.set("loop", false)

func _on_player_finished() -> void:
	play_next()
