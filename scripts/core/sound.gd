extends Node
## Every sound in the game, made from code (no audio files): noise shaped into
## rumbles, wind, surf, rain and fire, a siren, booms and crashes, and UI blips.
## They are generated a few per frame after startup (in the menu), then played
## through call_group("sound", ...):
##   play(name, pos)        one-shot, positional when pos is given (crash, boom)
##   loop(name, level, pitch) keeps a looping sound at level 0..1 for as long as
##                          it is called (fades out about 0.3 s after the last call)

## Noise, rumbles and the siren need little treble; the blips get more.
const RATE := 11025
const HI_RATE := 22050
const ONE_SHOT_PLAYERS := 10
## Crashes are frequent in collapses: at most one per this many seconds, and
## only within earshot.
const CRASH_GAP := 0.09
const HEARING := 45.0
const LOOPS := {"rumble": 2.0, "wind": 2.5, "fire": 2.0, "surf": 2.5, "rain": 2.0}
const SHOTS := {"siren": 3.0, "boom": 1.4, "crash": 0.5, "splash": 0.8, "click": 0.05, "coin": 0.4}

var _streams := {}
var _pending: Array = []
var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _flat: Array[AudioStreamPlayer] = []
var _next_flat := 0
## name -> [player, level, target, last call time]
var _loops := {}
var _time := 0.0
var _last_crash := -1.0


func _ready() -> void:
	add_to_group("sound")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pending = ["click", "siren", "boom", "crash", "rumble", "wind", "fire", "surf", "rain", "splash", "coin"]
	for i in ONE_SHOT_PLAYERS:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 8.0
		p.max_distance = HEARING * 1.5
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p)
		_players.append(p)
	for i in 3:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_flat.append(p)
	for name: String in LOOPS:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_loops[name] = [p, 0.0, 0.0, -10.0]


func _process(delta: float) -> void:
	_time += delta
	if not _pending.is_empty():
		var name: String = _pending.pop_front()
		_streams[name] = _make(name)
		if _loops.has(name):
			_loops[name][0].stream = _streams[name]
	for name: String in _loops:
		var entry: Array = _loops[name]
		var player: AudioStreamPlayer = entry[0]
		if _time - entry[3] > 0.3:
			entry[2] = 0.0
		entry[1] = move_toward(entry[1], entry[2], delta * 1.5)
		if entry[1] > 0.001 and player.stream:
			if not player.playing:
				player.play()
			player.volume_db = linear_to_db(entry[1])
		elif player.playing:
			player.stop()


func play(name: String, pos: Variant = null, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	if pos == null:
		var flat := _flat[_next_flat]
		_next_flat = (_next_flat + 1) % _flat.size()
		flat.stream = _streams[name]
		flat.volume_db = volume_db
		flat.pitch_scale = pitch
		flat.play()
		return
	var camera := get_viewport().get_camera_3d()
	if camera and camera.global_position.distance_to(pos) > HEARING:
		return
	if name == "crash":
		if _time - _last_crash < CRASH_GAP:
			return
		_last_crash = _time
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.9, 1.1)
	p.play()


func loop(name: String, level: float, pitch := 1.0) -> void:
	if not _loops.has(name):
		return
	var entry: Array = _loops[name]
	entry[2] = maxf(entry[2] if _time - entry[3] < 0.05 else 0.0, clampf(level, 0.0, 1.0))
	entry[3] = _time
	entry[0].pitch_scale = pitch


## Loudest sample of each sound after normalizing.
const PEAKS := {"siren": 0.45, "boom": 0.95, "crash": 0.7, "splash": 0.6, "click": 0.5, "coin": 0.35,
		"rumble": 0.85, "wind": 0.6, "fire": 0.6, "surf": 0.75, "rain": 0.4}


## Builds one sound: float samples from a tight loop per kind, normalized, then
## turned into a WAV in memory (the float-to-PCM conversion is native).
func _make(name: String) -> AudioStreamWAV:
	var seconds: float = LOOPS.get(name, SHOTS.get(name, 1.0))
	var rate := HI_RATE if name == "click" or name == "coin" else RATE
	var n := int(seconds * rate)
	var looped := LOOPS.has(name)
	# Loops get extra samples to crossfade their end into their start.
	var fade := int(rate * 0.25) if looped else 0
	var x := _samples(name, n + fade, seconds, rate)
	if looped:
		for i in fade:
			var k := float(i) / fade
			x[i] = x[i] * k + x[n + i] * (1.0 - k)
		x.resize(n)
	var peak := 0.0001
	for v in x:
		peak = maxf(peak, absf(v))
	var gain: float = PEAKS[name] / peak
	for i in n:
		x[i] *= gain
	var wav := AudioStreamWAV.load_from_buffer(_wav_header(n, rate) + x.to_byte_array())
	if looped:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav


## A WAV file header for n mono 32-bit float samples.
func _wav_header(n: int, rate: int) -> PackedByteArray:
	var h := PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)  # "RIFF"
	h.encode_u32(4, 36 + n * 4)
	h.encode_u32(8, 0x45564157)  # "WAVE"
	h.encode_u32(12, 0x20746d66)  # "fmt "
	h.encode_u32(16, 16)
	h.encode_u16(20, 3)  # IEEE float
	h.encode_u16(22, 1)
	h.encode_u32(24, rate)
	h.encode_u32(28, rate * 4)
	h.encode_u16(32, 4)
	h.encode_u16(34, 32)
	h.encode_u32(36, 0x61746164)  # "data"
	h.encode_u32(40, n * 4)
	return h


func _samples(name: String, count: int, seconds: float, rate: int) -> PackedFloat32Array:
	var x := PackedFloat32Array()
	x.resize(count)
	var brown := 0.0
	var low := 0.0
	var phase := 0.0
	var dt := 1.0 / rate
	match name:
		"rumble":
			for i in count:
				brown = (brown + 0.02 * (randf() * 2.0 - 1.0)) / 1.02
				low += (brown - low) * 0.05
				x[i] = low * (0.8 + 0.2 * sin(TAU * i * dt / seconds * 3.0))
		"wind":
			for i in count:
				var white := randf() * 2.0 - 1.0
				brown = (brown + 0.02 * white) / 1.02
				low += (white - low) * 0.035
				x[i] = (low * 1.5 + brown) * (0.65 + 0.35 * sin(TAU * i * dt / seconds))
		"surf":
			for i in count:
				var white := randf() * 2.0 - 1.0
				brown = (brown + 0.02 * white) / 1.02
				low += (white - low) * 0.08
				var swell := sin(PI * i * dt / seconds)
				x[i] = low * (0.35 + 0.65 * swell * swell) + brown * 0.7
		"rain":
			for i in count:
				var white := randf() * 2.0 - 1.0
				low += (white - low) * 0.5
				x[i] = low + (white * 1.3 if randf() < 0.002 else 0.0)
		"fire":
			var crackle := 0.0
			for i in count:
				var white := randf() * 2.0 - 1.0
				brown = (brown + 0.02 * white) / 1.02
				if randf() < 0.0012:
					crackle = randf_range(0.4, 1.0)
				crackle *= 0.86
				low += (brown - low) * 0.1
				x[i] = low * 2.5 + crackle * white
		"siren":
			for i in count:
				var t := i * dt
				phase += TAU * (650.0 + 260.0 * sin(TAU * t / 1.5 - PI * 0.5)) * dt
				x[i] = (sin(phase) + 0.25 * sin(phase * 3.0)) * minf(t * 8.0, 1.0) * minf((seconds - t) * 4.0, 1.0)
		"boom":
			for i in count:
				var t := i * dt
				var white := randf() * 2.0 - 1.0
				brown = (brown + 0.02 * white) / 1.02
				low += (white - low) * 0.12
				var thump := sin(TAU * 52.0 * t * (1.0 - t * 0.25)) * exp(-t * 5.0)
				x[i] = (thump * 0.5 + low * exp(-t * 3.0) + brown * 2.0 * exp(-t * 2.0)) * minf(t * 200.0, 1.0)
		"crash":
			for i in count:
				var t := i * dt
				var white := randf() * 2.0 - 1.0
				low += (white - low) * 0.3
				x[i] = (low + white * 0.3 * exp(-t * 30.0)) * exp(-t * 8.0)
		"splash":
			for i in count:
				var t := i * dt
				var white := randf() * 2.0 - 1.0
				low += (white - low) * 0.4
				x[i] = (white - low) * exp(-t * 4.0) * minf(t * 40.0, 1.0)
		"click":
			for i in count:
				var t := i * dt
				x[i] = sin(TAU * 1400.0 * t) * exp(-t * 90.0)
		"coin":
			for i in count:
				var t := i * dt
				var second := t >= 0.09
				phase += TAU * (1319.0 if second else 988.0) * dt
				x[i] = signf(sin(phase)) * exp(-(t - (0.09 if second else 0.0)) * 9.0)
	return x
