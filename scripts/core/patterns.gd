class_name Patterns
extends RefCounted
## The danmaku vocabulary.
##
## Every attack in the game is a dictionary describing one of these patterns.
## `emit()` is called once per volley with an incrementing `idx`, which is what
## lets spirals rotate, fans sweep and streams accelerate over successive shots.
##
## Shared keys (all optional):
##   n           bullet count for the volley
##   speed       muzzle speed in px/s
##   spread      total arc of the volley in degrees
##   base        fixed heading in degrees (90 = straight down)
##   aim         true to aim at the player instead of using `base`
##   offset      extra rotation in degrees applied to the whole volley
##   rot         degrees the volley rotates per shot index
##   style       bullet art: tiny/small/orb/bigorb/needle/wave/missile/bolt
##   color       key into Cfg.BULLET_COLORS
##   accel       speed change per second
##   speed_min / speed_max   clamps for `accel`
##   curve       turn rate in degrees/s (curving bullets)
##   delay       seconds the bullet hangs before launching
##   wave        lateral oscillation amplitude
##   wave_freq   oscillation rate
##   homing      steering rate in degrees/s
##   homing_time how long homing lasts
##   scale       art scale multiplier
##   life        seconds before self-destruct

const DEG := PI / 180.0


static func emit(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	match String(s.get("pattern", "aimed")):
		"aimed":
			_aimed(bm, s, origin, idx, target)
		"nway":
			_nway(bm, s, origin, idx, target)
		"ring":
			_ring(bm, s, origin, idx, target)
		"spiral":
			_spiral(bm, s, origin, idx, target)
		"dual_spiral":
			_dual_spiral(bm, s, origin, idx, target)
		"fan":
			_fan(bm, s, origin, idx, target)
		"wall":
			_wall(bm, s, origin, idx, target)
		"spray":
			_spray(bm, s, origin, idx, target)
		"bloom":
			_bloom(bm, s, origin, idx, target)
		"flower":
			_flower(bm, s, origin, idx, target)
		"cross":
			_cross(bm, s, origin, idx, target)
		"whip":
			_whip(bm, s, origin, idx, target)
		"homing":
			_homing(bm, s, origin, idx, target)
		"petal":
			_petal(bm, s, origin, idx, target)
		"arc_wall":
			_arc_wall(bm, s, origin, idx, target)
		"rain":
			_rain(bm, s, origin, idx, target)
		"shotgun":
			_shotgun(bm, s, origin, idx, target)
		"lockon":
			_lockon(bm, s, origin, idx, target)
		"vortex":
			_vortex(bm, s, origin, idx, target)
		"gatling":
			_gatling(bm, s, origin, idx, target)
		"helix":
			_helix(bm, s, origin, idx, target)
		"scatter":
			_scatter(bm, s, origin, idx, target)
		"unfurl":
			_unfurl(bm, s, origin, idx, target)
		"sniper":
			_sniper(bm, s, origin, idx, target)
		"minefield":
			_minefield(bm, s, origin, idx, target)
		"wave_wall":
			_wave_wall(bm, s, origin, idx, target)
		"pinwheel":
			_pinwheel(bm, s, origin, idx, target)
		_:
			_aimed(bm, s, origin, idx, target)


# --- Spawning helper ---------------------------------------------------------

static func _mk(bm: BulletManager, s: Dictionary, origin: Vector2, ang: float,
		spd: float) -> Bullet:
	var b := bm.spawn(
		origin, ang, spd,
		String(s.get("style", "small")),
		Cfg.color_of(String(s.get("color", "pink"))),
		float(s.get("scale", 1.0))
	)
	if b == null:
		return null
	b.accel = float(s.get("accel", 0.0))
	b.speed_min = float(s.get("speed_min", -4000.0))
	b.speed_max = float(s.get("speed_max", 4000.0))
	b.ang_vel = float(s.get("curve", 0.0)) * DEG
	b.delay = float(s.get("delay", 0.0))
	b.wave_amp = float(s.get("wave", 0.0))
	b.wave_freq = float(s.get("wave_freq", 6.0))
	b.life = float(s.get("life", Bullet.DEFAULT_LIFE))
	var hom := float(s.get("homing", 0.0))
	if hom > 0.0:
		b.homing = hom * DEG
		b.homing_time = float(s.get("homing_time", 1.2))
	if s.has("spin"):
		b.face_dir = false
		b.spin = float(s.spin) * DEG
	return b


## Base heading for a volley: either aimed at the player or a fixed angle,
## plus a constant offset and an index-driven rotation.
static func _base_angle(s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> float:
	var a: float
	if bool(s.get("aim", true)):
		a = (target - origin).angle()
	else:
		a = float(s.get("base", 90.0)) * DEG
	a += float(s.get("offset", 0.0)) * DEG
	a += float(s.get("rot", 0.0)) * DEG * idx
	return a


# --- Patterns ----------------------------------------------------------------

## N bullets in a cone centred on the player.
static func _aimed(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 1))
	var spread := float(s.get("spread", 0.0)) * DEG
	var spd := float(s.get("speed", 260.0))
	var a := _base_angle(s, origin, idx, target)
	for i in n:
		var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5
		_mk(bm, s, origin, a + t * spread, spd)


## Same as aimed but defaults to a fixed heading.
static func _nway(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var s2 := s.duplicate()
	if not s2.has("aim"):
		s2["aim"] = false
	if not s2.has("spread"):
		s2["spread"] = 60.0
	_aimed(bm, s2, origin, idx, target)


## Full circle. `rot` spins the ring between shots.
static func _ring(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 12))
	var spd := float(s.get("speed", 200.0))
	var a := _base_angle(s, origin, idx, target)
	for i in n:
		_mk(bm, s, origin, a + TAU * float(i) / float(n), spd)


## Rotating arms that trace a spiral as `idx` advances.
static func _spiral(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var arms := int(s.get("n", 3))
	var spd := float(s.get("speed", 210.0))
	var a := _base_angle(s, origin, idx, target)
	if not s.has("rot"):
		a += 13.0 * DEG * idx
	for i in arms:
		_mk(bm, s, origin, a + TAU * float(i) / float(arms), spd)


## Two spirals turning in opposite directions — reads as a woven mesh.
static func _dual_spiral(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var arms := int(s.get("n", 3))
	var spd := float(s.get("speed", 200.0))
	var step := float(s.get("rot", 11.0)) * DEG * idx
	var base := float(s.get("base", 90.0)) * DEG + float(s.get("offset", 0.0)) * DEG
	for i in arms:
		var o := TAU * float(i) / float(arms)
		_mk(bm, s, origin, base + o + step, spd)
		_mk(bm, s, origin, base + o - step, spd)


## A cone that sweeps back and forth like a windscreen wiper.
static func _fan(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 5))
	var spread := float(s.get("spread", 50.0)) * DEG
	var swing := float(s.get("swing", 55.0)) * DEG
	var rate := float(s.get("swing_rate", 0.25))
	var spd := float(s.get("speed", 240.0))
	var a := _base_angle(s, origin, idx, target) + sin(idx * rate) * swing
	for i in n:
		var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5
		_mk(bm, s, origin, a + t * spread, spd)


## A horizontal curtain spanning the playfield with a gap to slip through.
static func _wall(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 16))
	var spd := float(s.get("speed", 200.0))
	var gap := int(s.get("gap", 3))
	var gap_at := int(s.get("gap_at", -1))
	if gap_at < 0:
		# Centre the gap on the player so the wall is always survivable.
		gap_at = clampi(int(target.x / Cfg.FIELD_W * n) - gap / 2, 0, n - gap)
	var a := float(s.get("base", 90.0)) * DEG + float(s.get("offset", 0.0)) * DEG
	var y := origin.y
	for i in n:
		if i >= gap_at and i < gap_at + gap:
			continue
		var x := Cfg.FIELD_W * (float(i) + 0.5) / float(n)
		_mk(bm, s, Vector2(x, y), a, spd)


## Scattered fire inside a cone, with speed jitter.
static func _spray(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 5))
	var spread := float(s.get("spread", 70.0)) * DEG
	var spd := float(s.get("speed", 230.0))
	var jitter := float(s.get("jitter", 0.35))
	var a := _base_angle(s, origin, idx, target)
	for i in n:
		_mk(bm, s, origin, a + randf_range(-0.5, 0.5) * spread,
			spd * randf_range(1.0 - jitter, 1.0 + jitter))


## Ring that decelerates to a standstill then accelerates outward — the classic
## "blooming flower" that reshapes mid-flight.
static func _bloom(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 18))
	var spd := float(s.get("speed", 420.0))
	var a := _base_angle(s, origin, idx, target)
	for i in n:
		var b := _mk(bm, s, origin, a + TAU * float(i) / float(n), spd)
		if b:
			b.accel = float(s.get("accel", -520.0))
			b.speed_min = float(s.get("speed_min", -180.0))


## Ring whose speed varies sinusoidally by index, forming petal lobes.
static func _flower(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 24))
	var petals := int(s.get("petals", 5))
	var spd := float(s.get("speed", 200.0))
	var var_amt := float(s.get("variance", 0.45))
	var a := _base_angle(s, origin, idx, target)
	for i in n:
		var ang := a + TAU * float(i) / float(n)
		var k := 1.0 + sin(float(i) / float(n) * TAU * petals) * var_amt
		_mk(bm, s, origin, ang, spd * k)


## Four (or `arms`) tight clusters, rotating.
static func _cross(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var arms := int(s.get("arms", 4))
	var per := int(s.get("n", 3))
	var spread := float(s.get("spread", 10.0)) * DEG
	var spd := float(s.get("speed", 260.0))
	var a := _base_angle(s, origin, idx, target)
	for i in arms:
		var o := a + TAU * float(i) / float(arms)
		for j in per:
			var t := 0.0 if per == 1 else float(j) / float(per - 1) - 0.5
			_mk(bm, s, origin, o + t * spread, spd)


## A stream of single shots whose speed ramps across the volley, so the line
## stretches into a whip that cracks past the player.
static func _whip(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 1))
	var spd := float(s.get("speed", 240.0))
	var ramp := float(s.get("ramp", 22.0))
	var cycle := int(s.get("cycle", 8))
	var a := _base_angle(s, origin, idx, target)
	var k := spd + ramp * float(idx % cycle)
	for i in n:
		var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5
		_mk(bm, s, origin, a + t * float(s.get("spread", 8.0)) * DEG, k)


## Missiles that steer toward the player for a while, then fly straight.
static func _homing(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 2))
	var spd := float(s.get("speed", 150.0))
	var spread := float(s.get("spread", 120.0)) * DEG
	var a := _base_angle(s, origin, idx, target)
	for i in n:
		var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5
		var b := _mk(bm, s, origin, a + t * spread, spd)
		if b:
			b.homing = float(s.get("homing", 150.0)) * DEG
			b.homing_time = float(s.get("homing_time", 1.6))
			b.accel = float(s.get("accel", 140.0))
			b.speed_max = float(s.get("speed_max", 400.0))


## Ring of curving bullets — each arm bends the same way, drawing petals.
static func _petal(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 10))
	var spd := float(s.get("speed", 220.0))
	var curve := float(s.get("curve", 60.0))
	var a := _base_angle(s, origin, idx, target)
	var sign_flip: float = -1.0 if (idx % 2 == 1 and bool(s.get("alternate", true))) else 1.0
	for i in n:
		var b := _mk(bm, s, origin, a + TAU * float(i) / float(n), spd)
		if b:
			b.ang_vel = curve * DEG * sign_flip


## Bullets released along an arc with a staggered delay, so the wall appears to
## unzip across the screen before launching.
static func _arc_wall(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 14))
	var spread := float(s.get("spread", 160.0)) * DEG
	var spd := float(s.get("speed", 190.0))
	var stagger := float(s.get("stagger", 0.045))
	var a := _base_angle(s, origin, idx, target) - spread * 0.5
	for i in n:
		var b := _mk(bm, s, origin, a + spread * float(i) / float(n - 1), spd)
		if b:
			b.delay = float(s.get("delay", 0.35)) + stagger * i


## Bullets falling from above the playfield at random columns.
static func _rain(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 4))
	var spd := float(s.get("speed", 260.0))
	for i in n:
		var x := randf_range(20.0, Cfg.FIELD_W - 20.0)
		_mk(bm, s, Vector2(x, -30.0), PI * 0.5 + randf_range(-0.12, 0.12), spd)


## Dense short-range cone. Nasty up close, harmless at range.
static func _shotgun(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 9))
	var spread := float(s.get("spread", 26.0)) * DEG
	var spd := float(s.get("speed", 300.0))
	var a := _base_angle(s, origin, idx, target)
	for i in n:
		var t := randf_range(-0.5, 0.5)
		_mk(bm, s, origin, a + t * spread, spd * randf_range(0.7, 1.25))


## Bullets that materialise around the player and pause before converging.
static func _lockon(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 8))
	var r := float(s.get("radius", 260.0))
	var spd := float(s.get("speed", 300.0))
	var a0 := randf() * TAU
	for i in n:
		var ang := a0 + TAU * float(i) / float(n)
		var p := target + Vector2.from_angle(ang) * r
		if not Cfg.in_field(p, 40.0):
			continue
		var b := _mk(bm, s, p, ang + PI, spd)
		if b:
			b.delay = float(s.get("delay", 0.6)) + 0.03 * i


## A tight, fast machine-gun stream with just enough jitter to be unpredictable
## without being unreadable. Cheap per volley, meant to be fired often.
static func _gatling(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var spd := float(s.get("speed", 380.0))
	var jitter := float(s.get("spread", 6.0)) * DEG
	var a := _base_angle(s, origin, idx, target)
	_mk(bm, s, origin, a + randf_range(-0.5, 0.5) * jitter, spd)


## Two sine-offset streams running in antiphase, weaving past each other.
static func _helix(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var spd := float(s.get("speed", 230.0))
	var amp := float(s.get("wave", 34.0))
	var freq := float(s.get("wave_freq", 7.0))
	var a := _base_angle(s, origin, idx, target)
	for i in 2:
		var b := _mk(bm, s, origin, a, spd)
		if b:
			b.wave_amp = amp
			b.wave_freq = freq
			b.wave_phase = 0.0 if i == 0 else PI


## Fat slow carriers that burst into a ring partway down the screen. The `burst`
## sub-dictionary is the volley they leave behind.
static func _scatter(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 3))
	var spread := float(s.get("spread", 50.0)) * DEG
	var spd := float(s.get("speed", 210.0))
	var a := _base_angle(s, origin, idx, target)
	var payload: Dictionary = s.get("burst", {
		"pattern": "ring", "n": 8, "speed": 200.0, "style": "small",
		"color": String(s.get("color", "pink")), "aim": false,
	})
	for i in n:
		var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5
		var b := _mk(bm, s, origin, a + t * spread, spd)
		if b:
			b.split_after = float(s.get("fuse", 1.1))
			b.split_spec = payload


## A ring that appears one bullet at a time, unzipping around the circle before
## the whole thing launches.
static func _unfurl(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 18))
	var spd := float(s.get("speed", 220.0))
	var stagger := float(s.get("stagger", 0.035))
	var a := _base_angle(s, origin, idx, target)
	for i in n:
		var b := _mk(bm, s, origin, a + TAU * float(i) / float(n), spd)
		if b:
			b.delay = float(s.get("delay", 0.25)) + stagger * i


## One very fast shot with a long, obvious tell. Punishes standing still.
static func _sniper(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var b := _mk(bm, s, origin, _base_angle(s, origin, idx, target),
		float(s.get("speed", 620.0)))
	if b:
		b.delay = float(s.get("delay", 0.85))


## Bullets parked around the field that sit, then converge. Turns the whole
## playfield into a timed hazard rather than a stream to dodge.
static func _minefield(bm: BulletManager, s: Dictionary, origin: Vector2,
		idx: int, target: Vector2) -> void:
	var n := int(s.get("n", 5))
	var spd := float(s.get("speed", 260.0))
	for i in n:
		var p := Vector2(randf_range(60.0, Cfg.FIELD_W - 60.0),
			randf_range(120.0, Cfg.FIELD_H * 0.62))
		var b := _mk(bm, s, p, (target - p).angle(), spd)
		if b:
			b.delay = float(s.get("delay", 1.2)) + 0.08 * i


## A curtain of sine-weaving bullets: the gaps move, so you cannot just pick a
## column and sit in it.
static func _wave_wall(bm: BulletManager, s: Dictionary, origin: Vector2,
		idx: int, target: Vector2) -> void:
	var n := int(s.get("n", 12))
	var spd := float(s.get("speed", 200.0))
	var a := float(s.get("base", 90.0)) * DEG
	for i in n:
		var x := Cfg.FIELD_W * (float(i) + 0.5) / float(n)
		var b := _mk(bm, s, Vector2(x, origin.y), a, spd)
		if b:
			b.wave_amp = float(s.get("wave", 46.0))
			b.wave_freq = float(s.get("wave_freq", 3.4))
			b.wave_phase = float(i) * PI * 0.5


## Straight arms that rotate as a rigid body, sweeping the field like blades.
static func _pinwheel(bm: BulletManager, s: Dictionary, origin: Vector2,
		idx: int, target: Vector2) -> void:
	var arms := int(s.get("arms", 4))
	var per := int(s.get("n", 5))
	var spd := float(s.get("speed", 240.0))
	var step := float(s.get("arm_gap", 26.0))
	var a := _base_angle(s, origin, idx, target)
	for i in arms:
		var o := a + TAU * float(i) / float(arms)
		for j in per:
			# Later bullets start slower, so the arm stays a straight line.
			var b := _mk(bm, s, origin, o, spd - step * j)
			if b:
				b.life = float(s.get("life", 7.0))


## Ring whose bullets spiral outward on a widening curve.
static func _vortex(bm: BulletManager, s: Dictionary, origin: Vector2, idx: int,
		target: Vector2) -> void:
	var n := int(s.get("n", 16))
	var spd := float(s.get("speed", 120.0))
	var a := _base_angle(s, origin, idx, target)
	for i in n:
		var b := _mk(bm, s, origin, a + TAU * float(i) / float(n), spd)
		if b:
			b.accel = float(s.get("accel", 90.0))
			b.speed_max = float(s.get("speed_max", 340.0))
			b.ang_vel = float(s.get("curve", 45.0)) * DEG
