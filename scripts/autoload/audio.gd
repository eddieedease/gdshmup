extends Node
## Music playback and a small synthesised sound-effect bank.
##
## The project ships music but no SFX samples, so every effect here is generated
## as a 16-bit PCM buffer at startup: swept oscillators plus white noise, in the
## spirit of the 16-bit hardware the art is imitating. Building them in code
## also means they are tuned in one readable table rather than a folder of wavs.

const SR := 22050          ## Sample rate for generated effects.
const POOL := 24           ## Simultaneous effect voices.

const MUSIC_DB := -9.0
const SFX_DB := -7.0

## Every track starts with roughly this much silence. Skipped on both the
## initial play and the loop point, so a stage never opens (or re-opens) on a
## dead couple of seconds. Adjust if a future track has a different lead-in.
const MUSIC_INTRO_SKIP := 2.0

enum Wave { SINE, SQUARE, SAW, TRI, NOISE }

## name -> array of segments played back to back. Segment keys:
##   f0/f1   start and end frequency (Hz)
##   dur     seconds
##   wave    Wave enum
##   noise   0..1 blend toward white noise
##   vol     0..1 peak amplitude
##   decay   envelope exponent; higher = snappier
##   sweep   pitch-sweep curve exponent
##   vib     vibrato depth in Hz (with vib_hz for rate)
const BANK := {
	# Fired constantly, so it has to be short, soft and low in the mix.
	"shot": [{
		"f0": 1050.0, "f1": 330.0, "dur": 0.055, "wave": Wave.SQUARE,
		"noise": 0.18, "vol": 0.22, "decay": 3.0, "sweep": 0.5,
	}],
	# Popcorn: the little dry pop of a small enemy bursting.
	"pop": [{
		"f0": 760.0, "f1": 130.0, "dur": 0.13, "wave": Wave.SQUARE,
		"noise": 0.75, "vol": 0.5, "decay": 2.2, "sweep": 0.6,
	}],
	# Bigger enemies get body to the explosion.
	"boom": [{
		"f0": 260.0, "f1": 45.0, "dur": 0.45, "wave": Wave.TRI,
		"noise": 0.85, "vol": 0.62, "decay": 1.5, "sweep": 0.7,
	}],
	"boom_big": [{
		"f0": 180.0, "f1": 28.0, "dur": 1.1, "wave": Wave.TRI,
		"noise": 0.9, "vol": 0.85, "decay": 1.1, "sweep": 0.8,
	}],
	# Rising arpeggio: unmistakably "you got something good".
	"powerup": [
		{"f0": 660.0, "f1": 660.0, "dur": 0.055, "wave": Wave.SQUARE,
			"vol": 0.34, "decay": 0.8},
		{"f0": 880.0, "f1": 880.0, "dur": 0.055, "wave": Wave.SQUARE,
			"vol": 0.34, "decay": 0.8},
		{"f0": 1320.0, "f1": 1320.0, "dur": 0.14, "wave": Wave.SQUARE,
			"vol": 0.38, "decay": 2.2},
	],
	"item": [{
		"f0": 1500.0, "f1": 2100.0, "dur": 0.06, "wave": Wave.SINE,
		"vol": 0.24, "decay": 2.4,
	}],
	"extend": [
		{"f0": 523.0, "f1": 523.0, "dur": 0.09, "wave": Wave.SQUARE,
			"vol": 0.36, "decay": 0.7},
		{"f0": 659.0, "f1": 659.0, "dur": 0.09, "wave": Wave.SQUARE,
			"vol": 0.36, "decay": 0.7},
		{"f0": 784.0, "f1": 784.0, "dur": 0.09, "wave": Wave.SQUARE,
			"vol": 0.36, "decay": 0.7},
		{"f0": 1046.0, "f1": 1046.0, "dur": 0.30, "wave": Wave.SQUARE,
			"vol": 0.42, "decay": 1.6},
	],
	"bomb": [{
		"f0": 900.0, "f1": 40.0, "dur": 1.0, "wave": Wave.SAW,
		"noise": 0.55, "vol": 0.8, "decay": 1.2, "sweep": 1.8,
	}],
	"death": [{
		"f0": 520.0, "f1": 55.0, "dur": 0.75, "wave": Wave.SQUARE,
		"noise": 0.35, "vol": 0.6, "decay": 1.3, "sweep": 1.4,
	}],
	# Very quiet tick so a wall of hits reads as texture, not noise.
	"hit": [{
		"f0": 1400.0, "f1": 1000.0, "dur": 0.028, "wave": Wave.SQUARE,
		"noise": 0.4, "vol": 0.13, "decay": 3.0,
	}],
	"graze": [{
		"f0": 2600.0, "f1": 3200.0, "dur": 0.03, "wave": Wave.SINE,
		"vol": 0.16, "decay": 3.0,
	}],
	"warning": [
		{"f0": 880.0, "f1": 880.0, "dur": 0.13, "wave": Wave.SQUARE,
			"vol": 0.3, "decay": 0.5},
		{"f0": 660.0, "f1": 660.0, "dur": 0.13, "wave": Wave.SQUARE,
			"vol": 0.3, "decay": 0.5},
	],
	"menu_move": [{
		"f0": 620.0, "f1": 780.0, "dur": 0.05, "wave": Wave.SQUARE,
		"vol": 0.24, "decay": 2.0,
	}],
	"menu_select": [
		{"f0": 780.0, "f1": 780.0, "dur": 0.05, "wave": Wave.SQUARE,
			"vol": 0.3, "decay": 0.8},
		{"f0": 1170.0, "f1": 1170.0, "dur": 0.16, "wave": Wave.SQUARE,
			"vol": 0.32, "decay": 2.0},
	],
	"chain": [
		{"f0": 880.0, "f1": 880.0, "dur": 0.05, "wave": Wave.SQUARE,
			"vol": 0.28, "decay": 0.8},
		{"f0": 1320.0, "f1": 1760.0, "dur": 0.16, "wave": Wave.SQUARE,
			"vol": 0.32, "decay": 2.0},
	],
	"boss_phase": [{
		"f0": 140.0, "f1": 320.0, "dur": 0.5, "wave": Wave.SAW,
		"noise": 0.3, "vol": 0.55, "decay": 1.4, "sweep": 1.6,
	}],
	"stage_clear": [
		{"f0": 523.0, "f1": 523.0, "dur": 0.11, "wave": Wave.SQUARE,
			"vol": 0.34, "decay": 0.6},
		{"f0": 784.0, "f1": 784.0, "dur": 0.11, "wave": Wave.SQUARE,
			"vol": 0.34, "decay": 0.6},
		{"f0": 1046.0, "f1": 1046.0, "dur": 0.11, "wave": Wave.SQUARE,
			"vol": 0.34, "decay": 0.6},
		{"f0": 1318.0, "f1": 1318.0, "dur": 0.45, "wave": Wave.SQUARE,
			"vol": 0.4, "decay": 1.4},
	],
}

## Minimum seconds between repeats, for effects that can fire every frame.
const THROTTLE := {
	"shot": 0.05,
	"hit": 0.045,
	"graze": 0.07,
	"item": 0.05,
	"pop": 0.03,
}

## Tracks are resolved at runtime rather than preloaded so a stage can ship
## before its music does: drop `level4.mp3` into assets/music and it is picked
## up with no code change. Missing tracks fall back per MUSIC_FALLBACK.
const MUSIC_PATHS := {
	"title": "res://assets/music/title_screen.mp3",
	"level1": "res://assets/music/level1.mp3",
	"level2": "res://assets/music/level2.mp3",
	"level3": "res://assets/music/level3.mp3",
	"level4": "res://assets/music/level4.mp3",
	"level5": "res://assets/music/level5.mp3",
}

## Reuse an earlier stage's track when a later one is not present yet.
const MUSIC_FALLBACK := {
	"level4": "level2",
	"level5": "level3",
}

var _bank: Dictionary = {}
var _laser_stream: AudioStreamWAV
var _pool: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _last: Dictionary = {}
var _music: AudioStreamPlayer
var _laser: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _music_cache: Dictionary = {}
var _music_key := ""
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for name in BANK:
		_bank[name] = _build(BANK[name])
	_laser_stream = _build_laser()

	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_DB
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)

	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music)

	_laser = AudioStreamPlayer.new()
	_laser.stream = _laser_stream
	_laser.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_laser)

	_drone = AudioStreamPlayer.new()
	_drone.stream = _build_drone()
	_drone.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_drone)

	apply_volumes()


## Low menacing bed played under boss fights. `intensity` lifts the pitch as
## the fight gets more desperate.
func set_drone(active: bool, intensity: float = 0.0) -> void:
	if not active or GS.sfx_volume <= 0.001:
		if _drone.playing:
			_drone.stop()
		return
	_drone.pitch_scale = 1.0 + intensity * 0.30
	if not _drone.playing:
		_drone.play()


# --- Playback ----------------------------------------------------------------

## Plays a bank effect. `pitch_jitter` randomises pitch for variety, which stops
## repeated kills from sounding like a machine.
func play(name: String, pitch_jitter: float = 0.0, db: float = 0.0) -> void:
	if not _bank.has(name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gap := float(THROTTLE.get(name, 0.0))
	if gap > 0.0 and now - float(_last.get(name, -99.0)) < gap:
		return
	_last[name] = now

	if GS.sfx_volume <= 0.001:
		return
	var p := _pool[_next_voice]
	_next_voice = (_next_voice + 1) % _pool.size()
	p.stream = _bank[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = sfx_db(db)
	p.play()


## Mixer helpers. Silence is a hard mute rather than a very small gain, so a
## slider at zero really is off.
func sfx_db(extra: float = 0.0) -> float:
	if GS.sfx_volume <= 0.001:
		return -80.0
	return SFX_DB + extra + linear_to_db(GS.sfx_volume)


func music_db() -> float:
	if GS.music_volume <= 0.001:
		return -80.0
	return MUSIC_DB + linear_to_db(GS.music_volume)


## Re-applies the mixer to anything already playing.
func apply_volumes() -> void:
	if _fade == null or not _fade.is_valid():
		_music.volume_db = music_db()
	_laser.volume_db = sfx_db(-5.0)
	_drone.volume_db = sfx_db(-14.0)
	if GS.sfx_volume <= 0.001:
		_laser.stop()


## Holds or releases the continuous laser hum.
func set_laser(active: bool) -> void:
	if GS.sfx_volume <= 0.001:
		_laser.stop()
		return
	if active and not _laser.playing:
		_laser.play()
	elif not active and _laser.playing:
		_laser.stop()


func play_music(key: String, fade: float = 0.8) -> void:
	if _music_key == key and _music.playing:
		return
	_music_key = key
	var stream := _resolve_music(key)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = true
		# Loop back past the silence too, not just skip it on the first play.
		stream.loop_offset = MUSIC_INTRO_SKIP
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_music.stream = stream
	_music.volume_db = music_db() - 24.0
	_music.play(MUSIC_INTRO_SKIP)
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", music_db(), fade)


## Loads (and caches) a track, walking MUSIC_FALLBACK when the file is absent.
func _resolve_music(key: String) -> AudioStream:
	if _music_cache.has(key):
		return _music_cache[key]
	var k := key
	var hops := 0
	while hops < 4:
		var path := String(MUSIC_PATHS.get(k, ""))
		if path != "" and ResourceLoader.exists(path):
			var res: AudioStream = load(path)
			_music_cache[key] = res
			return res
		if not MUSIC_FALLBACK.has(k):
			break
		k = String(MUSIC_FALLBACK[k])
		hops += 1
	_music_cache[key] = null
	return null


func stop_music(fade: float = 0.6) -> void:
	_music_key = ""
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if fade <= 0.0:
		_music.stop()
		return
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", -80.0, fade)
	_fade.tween_callback(_music.stop)


# --- Synthesis ---------------------------------------------------------------

func _build(segments: Array) -> AudioStreamWAV:
	var frames: PackedFloat32Array = PackedFloat32Array()
	for seg in segments:
		frames.append_array(_render(seg))
	return _to_wav(frames, false)


## A short looping hum for the focused laser.
func _build_laser() -> AudioStreamWAV:
	var frames := _render({
		"f0": 165.0, "f1": 165.0, "dur": 0.25, "wave": Wave.SAW,
		"noise": 0.16, "vol": 0.5, "decay": 0.0,
		"vib": 9.0, "vib_hz": 24.0,
	})
	return _to_wav(frames, true)


## A slow, detuned throb - two close frequencies beating against each other.
func _build_drone() -> AudioStreamWAV:
	var frames := _render({
		"f0": 54.0, "f1": 54.0, "dur": 1.2, "wave": Wave.SAW,
		"noise": 0.05, "vol": 0.55, "decay": 0.0,
		"vib": 1.6, "vib_hz": 3.0,
	})
	return _to_wav(frames, true)


func _render(seg: Dictionary) -> PackedFloat32Array:
	var dur := float(seg.get("dur", 0.1))
	var n := maxi(1, int(dur * SR))
	var f0 := float(seg.get("f0", 440.0))
	var f1 := float(seg.get("f1", f0))
	var kind := int(seg.get("wave", Wave.SQUARE))
	var noise := float(seg.get("noise", 0.0))
	var vol := float(seg.get("vol", 0.5))
	var decay := float(seg.get("decay", 2.0))
	var sweep := float(seg.get("sweep", 1.0))
	var vib := float(seg.get("vib", 0.0))
	var vib_hz := float(seg.get("vib_hz", 6.0))

	# 3ms attack ramp, otherwise every effect starts with a click.
	var attack := maxi(1, int(0.003 * SR))
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0

	for i in n:
		var t := float(i) / float(n)
		var f: float = lerpf(f0, f1, pow(t, sweep))
		if vib > 0.0:
			f += sin(TAU * vib_hz * float(i) / SR) * vib
		phase = fmod(phase + TAU * f / SR, TAU)

		var s := 0.0
		match kind:
			Wave.SINE:
				s = sin(phase)
			Wave.SQUARE:
				s = 1.0 if phase < PI else -1.0
			Wave.SAW:
				s = phase / PI - 1.0
			Wave.TRI:
				s = 1.0 - absf(phase / PI - 1.0) * 2.0
			Wave.NOISE:
				s = randf_range(-1.0, 1.0)
		if noise > 0.0:
			s = lerpf(s, randf_range(-1.0, 1.0), noise)

		var env := 1.0 if decay <= 0.0 else pow(1.0 - t, decay)
		if i < attack:
			env *= float(i) / float(attack)
		out[i] = clampf(s * env * vol, -1.0, 1.0)
	return out


func _to_wav(frames: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(frames.size() * 2)
	for i in frames.size():
		data.encode_s16(i * 2, int(frames[i] * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = frames.size()
	return w
