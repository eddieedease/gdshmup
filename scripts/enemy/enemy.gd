class_name Enemy
extends Node2D
## A data-driven enemy.
##
## Everything an enemy does comes from a spec dictionary (see EnemyDefs):
## one movement behaviour plus a list of scheduled attacks, each attack being a
## Patterns spec with its own timing. That keeps wave authoring declarative and
## makes new enemy types cheap to add.

signal died(enemy: Enemy)
signal damaged(enemy: Enemy, amount: float)

const DEG := PI / 180.0

var spec: Dictionary = {}
var alive := true
var hittable := true
var hp := 10.0
var max_hp := 10.0
var hit_radius := 20.0
var score := 100
var age := 0.0

## Injected by the spawner.
var bullets: BulletManager
var fx: FxLayer
var player: Node2D

var vel := Vector2.ZERO
var _sprite: Sprite2D
var _move: Dictionary = {}
var _attacks: Array = []
var _flash := 0.0
var _face := "down"
var _bank := 1
var _cull_grace := 1.0
var _hold_target := Vector2.ZERO
var _start := Vector2.ZERO
var _dive_dir := Vector2.DOWN
var _fire_scale := 1.0   ## Stage-driven difficulty multiplier on fire rate.
var _spd_scale := 1.0


func setup(s: Dictionary, at: Vector2, difficulty: Dictionary = {}) -> void:
	spec = s
	position = at
	_start = at
	z_index = int(s.get("z", Cfg.Z_ENEMY))

	_fire_scale = float(difficulty.get("fire_rate", 1.0))
	_spd_scale = float(difficulty.get("speed", 1.0))
	var hp_scale := float(difficulty.get("hp", 1.0))

	max_hp = float(s.get("hp", 10)) * hp_scale
	hp = max_hp
	hit_radius = float(s.get("radius", 22.0))
	score = int(s.get("score", 100))
	_face = String(s.get("face", "down"))
	_cull_grace = float(s.get("cull_grace", 1.2))

	_sprite = Sprite2D.new()
	_sprite.centered = true
	Art.apply_ship(_sprite, Art.ENEMIES[int(s.get("tex", 0))])
	_sprite.scale = Vector2.ONE * float(s.get("scale", 0.24))
	if s.has("tint"):
		_sprite.modulate = s.tint
	add_child(_sprite)

	_move = s.get("move", {"type": "line", "dir": 90.0, "speed": 180.0}).duplicate()
	_attacks = []
	for a in s.get("attacks", []):
		var rt: Dictionary = a.duplicate()
		rt["_t"] = 0.0
		rt["_idx"] = 0
		rt["_next"] = float(a.get("start", 0.8))
		_attacks.append(rt)

	_init_move()


func _init_move() -> void:
	match String(_move.get("type", "line")):
		"enter_hold_exit":
			var tx: Variant = _move.get("hold_at", null)
			_hold_target = tx if tx != null else Vector2(position.x, 220.0)
		"dive":
			_dive_dir = Vector2.DOWN
	if _move.has("speed"):
		_move["speed"] = float(_move["speed"]) * _spd_scale


func _process(dt: float) -> void:
	if not alive:
		return
	age += dt
	_step_move(dt)
	_step_attacks(dt)
	_step_visual(dt)

	if age > _cull_grace and not Cfg.in_field(position, Cfg.CULL_MARGIN):
		_despawn()


# --- Movement ----------------------------------------------------------------

func _step_move(dt: float) -> void:
	var m := _move
	match String(m.get("type", "line")):
		"line":
			var a := float(m.get("dir", 90.0)) * DEG
			vel = Vector2.from_angle(a) * float(m.get("speed", 180.0))
			position += vel * dt

		"sine":
			var a2 := float(m.get("dir", 90.0)) * DEG
			var fwd := Vector2.from_angle(a2) * float(m.get("speed", 160.0))
			var amp := float(m.get("amp", 120.0))
			var freq := float(m.get("freq", 2.0))
			var lateral := Vector2.from_angle(a2 + PI * 0.5) * cos(age * freq) * amp * freq
			vel = fwd + lateral
			position += vel * dt

		"enter_hold_exit":
			var enter := float(m.get("enter", 1.2))
			var hold := float(m.get("hold", 3.0))
			if age < enter:
				var t: float = clampf(age / enter, 0.0, 1.0)
				var e: float = 1.0 - pow(1.0 - t, 3.0)
				var np := _start.lerp(_hold_target, e)
				vel = (np - position) / maxf(dt, 0.0001)
				position = np
			elif age < enter + hold:
				var bob := float(m.get("bob", 14.0))
				vel = Vector2.ZERO
				position = _hold_target + Vector2(
					sin(age * 1.7) * bob, cos(age * 2.3) * bob * 0.5)
			else:
				var ea := float(m.get("exit_dir", 90.0)) * DEG
				var es := float(m.get("exit_speed", 260.0))
				var t2: float = clampf((age - enter - hold) / 0.6, 0.0, 1.0)
				vel = Vector2.from_angle(ea) * es * t2
				position += vel * dt

		"dive":
			# Accelerates toward wherever the player was when the dive began.
			var accel := float(m.get("accel", 520.0))
			var top := float(m.get("speed", 520.0))
			if age < float(m.get("lock", 0.55)) and is_instance_valid(player):
				_dive_dir = (player.position - position).normalized()
			vel = vel.move_toward(_dive_dir * top, accel * dt)
			position += vel * dt

		"drift":
			# Slow descent that leans toward the player's column.
			var down := float(m.get("speed", 90.0))
			var track := float(m.get("track", 70.0))
			var dx := 0.0
			if is_instance_valid(player):
				dx = signf(player.position.x - position.x) * track
			vel = Vector2(dx, down)
			position += vel * dt

		"arc":
			var r := float(m.get("radius", 200.0))
			var w := float(m.get("omega", 1.1))
			var cx: Vector2 = m.get("centre", Vector2(Cfg.FIELD_W * 0.5, 260.0))
			var a3 := float(m.get("phase", 0.0)) * DEG + age * w
			var np2 := cx + Vector2.from_angle(a3) * r
			vel = (np2 - position) / maxf(dt, 0.0001)
			position = np2

		"sway":
			# Lissajous drift around a fixed anchor. The bread and butter of
			# boss movement: readable, never leaves the arena.
			var c: Vector2 = m.get("centre", Vector2(Cfg.FIELD_W * 0.5, 250.0))
			var ax := float(m.get("amp_x", 220.0))
			var ay := float(m.get("amp_y", 60.0))
			var wx := float(m.get("freq_x", 0.75))
			var wy := float(m.get("freq_y", 1.3))
			var np3 := c + Vector2(sin(age * wx) * ax, sin(age * wy) * ay)
			vel = (np3 - position) / maxf(dt, 0.0001)
			position = np3

		"approach":
			# Ease from the spawn point to an anchor and stop there.
			var to: Vector2 = m.get("to", Vector2(Cfg.FIELD_W * 0.5, 250.0))
			var dur := float(m.get("time", 2.0))
			var t3: float = clampf(age / dur, 0.0, 1.0)
			var e3: float = 1.0 - pow(1.0 - t3, 3.0)
			var np4 := _start.lerp(to, e3)
			vel = (np4 - position) / maxf(dt, 0.0001)
			position = np4

		"path":
			_step_path(dt)

		"static":
			vel = Vector2.ZERO


func _step_path(dt: float) -> void:
	var pts: Array = _move.get("points", [])
	if pts.is_empty():
		return
	var seg := float(_move.get("seg_time", 1.0))
	var total := seg * pts.size()
	var loop := bool(_move.get("loop", false))
	var t := age
	if loop:
		t = fmod(t, total)
	elif t >= total:
		var ea := float(_move.get("exit_dir", 90.0)) * DEG
		vel = Vector2.from_angle(ea) * float(_move.get("exit_speed", 300.0))
		position += vel * dt
		return
	var i := int(t / seg)
	var f: float = clampf(t / seg - i, 0.0, 1.0)
	var a: Vector2 = _start if i == 0 else pts[i - 1]
	var b: Vector2 = pts[mini(i, pts.size() - 1)]
	var e := f * f * (3.0 - 2.0 * f)
	var np := a.lerp(b, e)
	vel = (np - position) / maxf(dt, 0.0001)
	position = np


# --- Attacks -----------------------------------------------------------------

func _step_attacks(dt: float) -> void:
	if bullets == null:
		return
	var target := Vector2(position.x, Cfg.FIELD_H + 100.0)
	if is_instance_valid(player):
		target = player.position

	for a in _attacks:
		a._t += a.get("time_scale", 1.0) * dt
		var count := int(a.get("count", -1))
		if count >= 0 and a._idx >= count:
			continue
		var until := float(a.get("until", -1.0))
		if until > 0.0 and a._t > until:
			continue
		if a._t < a._next:
			continue
		if bool(a.get("only_on_screen", true)) and position.y < -40.0:
			a._next = a._t + 0.1
			continue

		var origin := position + Vector2(
			float(a.get("ox", 0.0)), float(a.get("oy", 0.0)))
		Patterns.emit(bullets, a, origin, a._idx, target)
		if fx and bool(a.get("flash", true)):
			fx.muzzle(origin, PI * 0.5, Cfg.color_of(String(a.get("color", "pink"))), 0.12)

		a._idx += 1
		var burst := int(a.get("burst", 1))
		var gap: float
		if burst > 1 and (a._idx % burst) != 0:
			gap = float(a.get("burst_gap", 0.08))
		else:
			gap = float(a.get("interval", 1.2)) / maxf(_fire_scale, 0.05)
		a._next = a._t + gap


# --- Visuals / damage --------------------------------------------------------

func _step_visual(dt: float) -> void:
	match _face:
		"down":
			_sprite.rotation = PI
		"vel":
			if vel.length_squared() > 1.0:
				_sprite.rotation = vel.angle() - PI * 0.5
		"player":
			if is_instance_valid(player):
				_sprite.rotation = (player.position - position).angle() - PI * 0.5
		_:
			_sprite.rotation = PI

	_bank = Art.bank_row(-signf(vel.x) if absf(vel.x) > 40.0 else 0.0)
	_sprite.frame = _bank * 2 + (int(age * 12.0) % 2)

	if _flash > 0.0:
		_flash -= dt
		var k: float = clampf(_flash / 0.07, 0.0, 1.0)
		_sprite.modulate = Color(1, 1, 1, 1).lerp(_base_tint(), 1.0 - k)
		if _flash <= 0.0:
			_sprite.modulate = _base_tint()


func _base_tint() -> Color:
	return spec.get("tint", Color.WHITE)


func take_damage(amount: float, at: Vector2 = Vector2.ZERO) -> void:
	if not alive or not hittable:
		return
	hp -= amount
	_flash = 0.07
	damaged.emit(self, amount)
	if hp <= 0.0:
		_die(at)


func _die(at: Vector2) -> void:
	alive = false
	var s := float(spec.get("scale", 0.24)) / 0.24
	fx.explode(position, clampf(s, 0.7, 3.0), Color(1, 0.72, 0.35))
	# Small fry pop, heavies boom.
	AU.play("boom" if max_hp >= 90.0 else "pop", 0.12)
	died.emit(self)
	queue_free()


func _despawn() -> void:
	alive = false
	queue_free()
