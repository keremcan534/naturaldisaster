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
const LOOPS := {"rumble": 2.0, "wind": 2.5, "fire": 2.0, "surf": 2.5, "rain": 2.0, "crickets": 3.0}
const SHOTS := {"siren": 3.0, "boom": 1.4, "crash": 0.5, "splash": 0.8, "click": 0.05, "coin": 0.4, "bark": 0.6,
		"win": 1.6, "lose": 1.8, "step": 0.12, "glass": 0.6, "metal": 0.9, "wood": 0.4, "scream": 0.9, "shout": 0.35,
		"chirp": 0.5, "gull": 0.7}
## Under water everything sounds muffled: a low-pass on the master bus.
const MUFFLE_HZ := 600.0
## Music loops: a calm one for the menu and between disasters, a tense one while
## a disaster is coming or under way.
const MUSIC := {"calm": 8.0, "tense": 4.0}
const MUSIC_FADE := 1.2
## Music is built a slice at a time (samples per frame) at a lower rate, so the
## menu never stalls while it is made.
const MUSIC_RATE := 8000
const MUSIC_SLICE := 2000

const Settings := preload("res://scripts/core/settings.gd")

var _streams := {}
var _pending: Array = []
var _players: Array[AudioStreamPlayer3D] = []
var _next := 0
var _flat: Array[AudioStreamPlayer] = []
var _next_flat := 0
## name -> [player, level, target, last call time]
var _loops := {}
var _time := 0.0
## Breaking sounds come in bursts: each at most once per CRASH_GAP.
const BREAKS := ["crash", "glass", "metal", "wood"]
var _last_break := {}
var _music: AudioStreamPlayer
var _music_mode := ""
var _music_level := 0.0
var _building := false
var _muffle_index := -1


func _ready() -> void:
	add_to_group("sound")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pending = ["click", "calm", "siren", "boom", "crash", "rumble", "wind", "fire", "surf", "rain", "splash", "coin", "bark",
			"step", "glass", "metal", "wood", "win", "lose", "scream", "shout", "chirp", "gull", "crickets", "tense"]
	var muffle := AudioEffectLowPassFilter.new()
	muffle.cutoff_hz = MUFFLE_HZ
	AudioServer.add_bus_effect(0, muffle)
	_muffle_index = AudioServer.get_bus_effect_count(0) - 1
	AudioServer.set_bus_effect_enabled(0, _muffle_index, false)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -80.0
	add_child(_music)
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
	if not _pending.is_empty() and not _building:
		var name: String = _pending.pop_front()
		if MUSIC.has(name):
			_build_music(name)
		else:
			_streams[name] = _make(name)
			if _loops.has(name):
				_loops[name][0].stream = _streams[name]
	_update_music(delta)
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


## Muffled (under water) or clear.
func muffle(on: bool) -> void:
	if _muffle_index >= 0 and AudioServer.is_bus_effect_enabled(0, _muffle_index) != on:
		AudioServer.set_bus_effect_enabled(0, _muffle_index, on)


## "calm", "tense" or "" (silence): fades out what plays and into the new one.
func music(mode: String) -> void:
	_music_mode = mode


func _update_music(delta: float) -> void:
	var want: AudioStream = _streams.get(_music_mode)
	if _music.stream != want:
		_music_level = move_toward(_music_level, 0.0, delta / MUSIC_FADE)
		if _music_level <= 0.0:
			_music.stream = want
			if want:
				_music.play()
	elif want:
		_music_level = move_toward(_music_level, 1.0, delta / MUSIC_FADE)
		if not _music.playing:
			_music.play()
	var volume := _music_level * Settings.music * 0.55
	_music.volume_db = linear_to_db(maxf(volume, 0.0001))


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
	if name in BREAKS:
		if _time - _last_break.get(name, -1.0) < CRASH_GAP:
			return
		_last_break[name] = _time
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
const PEAKS := {"bark": 0.7, "siren": 0.45, "boom": 0.95, "crash": 0.7, "splash": 0.6, "click": 0.5, "coin": 0.35,
		"rumble": 0.85, "wind": 0.6, "fire": 0.6, "surf": 0.75, "rain": 0.4, "crickets": 0.25, "win": 0.45, "lose": 0.45,
		"step": 0.35, "glass": 0.55, "metal": 0.5, "wood": 0.65, "scream": 0.5, "shout": 0.45, "chirp": 0.3, "gull": 0.35}


## Builds one sound: float samples from a tight loop per kind, normalized, then
## turned into a WAV in memory (the float-to-PCM conversion is native).
func _make(name: String) -> AudioStreamWAV:
	var seconds: float = LOOPS.get(name, SHOTS.get(name, 1.0))
	var rate := HI_RATE if name in ["click", "coin", "glass", "chirp", "win", "lose", "metal"] else RATE
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


## The music loops: chords, an arpeggio and bass (calm); drums, a pulsing bass
## and trembling strings (tense). Every part repeats exactly at the loop length.
func _build_music(name: String) -> void:
	_building = true
	var rate := MUSIC_RATE
	var n := int(MUSIC[name] * rate)
	var x := PackedFloat32Array()
	x.resize(n)
	var dt := 1.0 / rate
	if name == "calm":
		# Am - F - C - G, two seconds each.
		var chords := [[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 261.63, 329.63], [196.0, 246.94, 293.66]]
		var bass := [110.0, 87.31, 130.81, 98.0]
		for i in n:
			var t := i * dt
			var c := int(t / 2.0) % 4
			var tc := fmod(t, 2.0)
			var env := minf(tc / 0.5, 1.0) * minf((2.0 - tc) / 0.35, 1.0)
			var chord: Array = chords[c]
			var pad := 0.0
			for f: float in chord:
				var ph := TAU * f * t
				pad += sin(ph) + 0.2 * sin(ph * 2.0)
			var step := int(t / 0.25)
			var tp := t - step * 0.25
			var note: float = chord[step % 3] * 2.0
			var pluck := sin(TAU * note * tp) * exp(-tp * 7.0)
			var tb := fmod(t, 1.0)
			var low := sin(TAU * bass[c] * t) * exp(-tb * 2.0)
			x[i] = pad * 0.09 * env + pluck * 0.22 + low * 0.25 * env
			if i % MUSIC_SLICE == 0:
				await get_tree().process_frame
	else:
		# D - D - Bb - A, eighth notes at 120 bpm, kick on the beat, hats between.
		var roots := [73.42, 73.42, 58.27, 55.0]
		var noise := 0.0
		for i in n:
			var t := i * dt
			var root: float = roots[int(t) % 4]
			var t8 := fmod(t, 0.25)
			var ph := TAU * root * t
			var bass := (sin(ph) + 0.5 * sin(ph * 2.0) + 0.3 * sin(ph * 3.0)) * exp(-t8 * 9.0)
			var tb := fmod(t, 0.5)
			var kick := sin(TAU * (48.0 * tb + 3.0 * (1.0 - exp(-tb * 30.0)))) * exp(-tb * 9.0)
			var th := fmod(t + 0.25, 0.5)
			noise = randf() * 2.0 - 1.0
			var hat := noise * exp(-th * 70.0)
			var strings := (sin(TAU * 587.33 * t) + sin(TAU * 880.0 * t)) * (0.6 + 0.4 * sin(TAU * 8.0 * t))
			x[i] = bass * 0.3 + kick * 0.55 + hat * 0.12 + strings * 0.05
			if i % MUSIC_SLICE == 0:
				await get_tree().process_frame
	var peak := 0.0001
	for v in x:
		peak = maxf(peak, absf(v))
	var gain := 0.8 / peak
	for i in n:
		x[i] *= gain
	var wav := AudioStreamWAV.load_from_buffer(_wav_header(n, rate) + x.to_byte_array())
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	_streams[name] = wav
	_building = false


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
		"bark":
			# Two "woof"s: a falling growly tone with a breathy edge.
			for i in count:
				var t := i * dt
				var local := t if t < 0.3 else t - 0.3
				var f := 520.0 - local * 900.0
				phase += TAU * maxf(f, 200.0) * dt
				var env := exp(-local * 14.0) * minf(local * 120.0, 1.0)
				x[i] = (sin(phase) + 0.6 * sin(phase * 2.0) + 0.3 * (randf() * 2.0 - 1.0)) * env
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
		"win", "lose":
			# Survived: a bright arpeggio up (C E G C). Died: a slow fall in minor.
			var notes := [523.25, 659.25, 783.99, 1046.5] if name == "win" else [440.0, 415.3, 392.0, 329.63]
			var length := 0.16 if name == "win" else 0.3
			for i in count:
				var t := i * dt
				var k := mini(int(t / length), 3)
				var tn := t - k * length
				var f: float = notes[k]
				var tail := 3.0 if k == 3 else 9.0
				var tone := sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) + 0.15 * sin(TAU * f * 3.0 * t)
				x[i] = tone * exp(-tn * tail) * minf(tn * 300.0, 1.0)
		"step":
			# A soft thud: low noise with a quick fall.
			for i in count:
				var t := i * dt
				var white := randf() * 2.0 - 1.0
				low += (white - low) * 0.18
				x[i] = (low + sin(TAU * 90.0 * t) * 0.5) * exp(-t * 45.0) * minf(t * 900.0, 1.0)
		"glass":
			# Bright tinkles: a few high rings scattered over the first moments.
			var rings := []
			for k in 7:
				rings.append([randf_range(2200.0, 5200.0), randf_range(0.0, 0.25)])
			for i in count:
				var t := i * dt
				var v := (randf() * 2.0 - 1.0) * exp(-t * 40.0) * 0.6
				for r: Array in rings:
					var tr: float = t - r[1]
					if tr > 0.0:
						v += sin(TAU * r[0] * tr) * exp(-tr * 18.0) * 0.4
				x[i] = v
		"metal":
			# A clang: inharmonic partials ringing out.
			for i in count:
				var t := i * dt
				var v := sin(TAU * 310.0 * t) + 0.7 * sin(TAU * 853.0 * t) + 0.5 * sin(TAU * 1471.0 * t) + 0.3 * sin(TAU * 2290.0 * t)
				x[i] = (v * exp(-t * 5.0) + (randf() * 2.0 - 1.0) * exp(-t * 60.0)) * minf(t * 2000.0, 1.0)
		"wood":
			# A crack and a hollow knock.
			for i in count:
				var t := i * dt
				var white := randf() * 2.0 - 1.0
				low += (white - low) * 0.45
				x[i] = (low * exp(-t * 35.0) + sin(TAU * 180.0 * t) * exp(-t * 22.0) * 0.8) * minf(t * 1500.0, 1.0)
		"scream", "shout":
			# A voice: a buzzy tone through two vowel formants ("aaah"), falling
			# (scream) or short and rising (shout).
			var b1 := 0.0
			var b2 := 0.0
			for i in count:
				var t := i * dt
				var f := (420.0 - 160.0 * t / seconds) if name == "scream" else (230.0 + 120.0 * t / seconds)
				f *= 1.0 + 0.02 * sin(TAU * 6.0 * t)
				phase += f * dt
				var buzz := fmod(phase, 1.0) * 2.0 - 1.0
				b1 += (buzz - b1) * 0.35
				b2 += (buzz - b2) * 0.75
				var env := minf(t * 25.0, 1.0) * minf((seconds - t) * 6.0, 1.0)
				x[i] = (b1 * 0.7 + (b2 - b1) * 0.6) * env
		"chirp":
			# A bird: two or three quick up-sweeping whistles.
			for i in count:
				var t := i * dt
				var k := int(t / 0.13)
				var tn := t - k * 0.13
				var on := 1.0 if k < 3 and tn < 0.08 else 0.0
				phase += TAU * (2600.0 + tn * 14000.0) * dt
				x[i] = sin(phase) * on * sin(PI * minf(tn / 0.08, 1.0))
		"gull":
			# A gull's cry: a high, rough, falling "kyaa".
			for i in count:
				var t := i * dt
				phase += TAU * (1250.0 - 500.0 * t / seconds) * dt
				var rough := 1.0 + 0.4 * sin(TAU * 45.0 * t)
				x[i] = (sin(phase) + 0.5 * sin(phase * 2.0)) * rough * minf(t * 20.0, 1.0) * exp(-t * 3.0)
		"crickets":
			# Night: pulsing high chirps, slightly out of step with each other.
			for i in count:
				var t := i * dt
				var a := 1.0 if fmod(t * 16.0, 1.0) < 0.5 and fmod(t, 0.9) < 0.35 else 0.0
				var b := 1.0 if fmod(t * 15.0 + 0.3, 1.0) < 0.5 and fmod(t + 0.4, 1.1) < 0.3 else 0.0
				x[i] = sin(TAU * 4200.0 * t) * a * 0.6 + sin(TAU * 3900.0 * t) * b * 0.4
	return x
