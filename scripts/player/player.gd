class_name Player
extends Node2D
## The player ship.
##
## Two weapons share one body, DoDonPachi style:
##   SHOT  (J) - rapid spread bullets, full speed, bits fanned wide
##   LASER (K) - continuous piercing beam, ~40% speed, bits tucked in tight
## Holding both favours the laser, since the slow speed is the trade-off that
## makes precise dodging possible.

signal life_lost
signal bomb_fired
signal damage_dealt(enemy: Node2D, amount: float, at: Vector2)

enum State { ALIVE, DYING, RESPAWNING }

const RESPAWN_DELAY := 0.85
const INVULN_TIME := 2.6
const BOMB_TIME := 2.3
const BOMB_INVULN := 0.6
## Damage per second applied to everything on screen while a bomb burns.
const BOMB_DPS := 300.0
const DEATH_POWER_LOSS := 1

## Above this line every item on screen is magnetised, rewarding aggression.
const AUTO_COLLECT_Y := 260.0

var ship: Dictionary
var ship_index := 0
var colour := Color.WHITE

var power := 1
var bombs := 3
var state: int = State.ALIVE

var invuln := 0.0
var bomb_time := 0.0

var laser_held := false
var shot_held := false

## Wired up by the game scene.
var bullets: BulletManager
var fx: FxLayer
var enemies: Array = []
var option_root: Node2D

var _sprite: Sprite2D
var _beam: Beam
var _shield: Sprite2D
var _hitbox: Node2D
var _trail: EngineTrail
var _options: Array[OptionBit] = []
var _shot_cd := 0.0
var _opt_cd := 0.0
var _beam_spark_cd := 0.0
var _t := 0.0
var _dead_timer := 0.0
var _bank := 1


func setup(index: int) -> void:
	ship_index = index
	ship = ShipDefs.get_ship(index)
	colour = ship.color
	z_index = Cfg.Z_PLAYER

	_sprite = Sprite2D.new()
	_sprite.centered = true
	Art.apply_ship(_sprite, Art.PLAYER_SHIPS[ship.tex])
	_sprite.scale = Vector2.ONE * 0.26
	add_child(_sprite)

	_beam = Beam.new()
	_beam.z_index = -2
	add_child(_beam)

	_shield = Sprite2D.new()
	_shield.centered = true
	Art.apply_sheet(_shield, "shield", true)
	_shield.scale = Vector2.ONE * 0.42
	_shield.modulate = Color(colour.r, colour.g, colour.b, 0.75)
	_shield.visible = false
	_shield.z_index = 2
	add_child(_shield)

	_hitbox = HitboxDot.new()
	_hitbox.z_index = 3
	add_child(_hitbox)

	_trail = EngineTrail.new()
	_trail.colour = colour
	_trail.z_index = -3
	add_child(_trail)

	position = Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H - 170.0)
	invuln = INVULN_TIME


## Bits must live outside the ship's transform so they can trail behind it.
func spawn_options(root: Node2D) -> void:
	option_root = root
	for i in 2:
		var o := OptionBit.new()
		o.setup(colour, -1.0 if i == 0 else 1.0)
		root.add_child(o)
		o.position = position
		_options.append(o)
	_refresh_beams()


func _refresh_beams() -> void:
	var w: float = ShipDefs.at_power(ship, "laser_width", power)
	_beam.configure(w, Color(colour.r, colour.g, colour.b, 0.92))
	for o in _options:
		o.beam.configure(w * 0.5, Color(colour.r, colour.g, colour.b, 0.7))


func is_vulnerable() -> bool:
	return state == State.ALIVE and invuln <= 0.0


func is_focused() -> bool:
	return laser_held and state == State.ALIVE


func bomb_active() -> bool:
	return bomb_time > 0.0


func add_power(n: int = 1) -> bool:
	if power >= Cfg.MAX_POWER:
		return false
	power = mini(Cfg.MAX_POWER, power + n)
	_refresh_beams()
	return true


func _exit_tree() -> void:
	AU.set_laser(false)


func _process(dt: float) -> void:
	_t += dt
	if invuln > 0.0:
		invuln -= dt

	match state:
		State.ALIVE:
			_alive(dt)
		State.DYING:
			_dead_timer -= dt
			if _dead_timer <= 0.0:
				_begin_respawn()
		State.RESPAWNING:
			_respawn_move(dt)

	_update_bomb(dt)
	_update_visuals(dt)


# --- Alive ---------------------------------------------------------------

func _alive(dt: float) -> void:
	shot_held = Input.is_action_pressed("p_shot")
	laser_held = Input.is_action_pressed("p_laser")

	var dir := Input.get_vector("p_left", "p_right", "p_up", "p_down")
	if dir.length() > 1.0:
		dir = dir.normalized()
	var speed: float = ship.speed_laser if laser_held else ship.speed_shot
	position = Cfg.clamp_to_field(position + dir * speed * dt, 26.0)
	_bank = Art.bank_row(dir.x)

	if Input.is_action_just_pressed("p_bomb"):
		_try_bomb()

	_update_options(dt)

	AU.set_laser(laser_held)
	if laser_held:
		_fire_laser(dt)
	else:
		_beam.visible = false
		for o in _options:
			o.beam.visible = false
		if shot_held:
			_fire_shot(dt)
		else:
			_shot_cd = 0.0
			_opt_cd = 0.0


func _update_options(dt: float) -> void:
	var count: int = ShipDefs.at_power(ship, "opt_count", power)
	var spread: Array = ship.opt_spread
	var tight: Array = ship.opt_tight
	for i in _options.size():
		var o := _options[i]
		o.visible = i < count
		if not o.visible:
			continue
		var lane := 0 if count == 1 else i
		var dx: float = float(tight[lane]) if laser_held else float(spread[lane])
		var dy := 26.0 if laser_held else 14.0
		o.follow(position, Vector2(o.side * dx, dy), dt)


func _fire_shot(dt: float) -> void:
	_shot_cd -= dt
	if _shot_cd <= 0.0:
		_shot_cd += float(ship.shot_rate)
		var n: int = ShipDefs.at_power(ship, "shot_n", power)
		var dmg: int = ShipDefs.at_power(ship, "shot_damage", power)
		var spread: float = float(ship.shot_spread) * PI / 180.0
		var spd: float = ship.shot_speed
		var nose := position + Vector2(0, -30)
		for i in n:
			var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5
			var a := -PI * 0.5 + t * spread
			var b := bullets.spawn(nose, a, spd, "pshot", colour)
			if b:
				b.damage = dmg
				b.life = 2.5
		fx.muzzle(nose, -PI * 0.5, colour, 0.14)
		AU.play("shot", 0.07)

	_opt_cd -= dt
	if _opt_cd <= 0.0:
		_opt_cd += float(ship.opt_rate)
		var odmg: int = ShipDefs.at_power(ship, "opt_damage", power)
		var count: int = ShipDefs.at_power(ship, "opt_count", power)
		for i in mini(count, _options.size()):
			var o := _options[i]
			if String(ship.opt_mode) == "missile":
				var m := bullets.spawn(o.position, -PI * 0.5 + o.side * 0.5, 420.0,
					"pmissile", Color(1, 0.9, 0.6))
				if m:
					m.damage = odmg
					m.homing = 300.0 * PI / 180.0
					m.homing_time = 2.0
					m.accel = 900.0
					m.speed_max = 1150.0
					m.life = 2.6
			else:
				var b := bullets.spawn(o.position, -PI * 0.5, float(ship.shot_speed) * 0.9,
					"pspread", colour.lightened(0.2))
				if b:
					b.damage = odmg
					b.life = 2.5


## The laser is a persistent column: everything in the strip above the emitter
## takes damage every frame.
func _fire_laser(dt: float) -> void:
	var dps: float = ShipDefs.at_power(ship, "laser_dps", power)
	var width: float = ShipDefs.at_power(ship, "laser_width", power)

	_beam.visible = true
	_beam.set_length(position.y + 80.0)
	_damage_column(position.x, position.y, width, dps * dt, dt)

	var count: int = ShipDefs.at_power(ship, "opt_count", power)
	for i in _options.size():
		var o := _options[i]
		var on := i < count
		o.beam.visible = on
		if not on:
			continue
		o.beam.set_length(o.position.y + 80.0)
		_damage_column(o.position.x, o.position.y, width * 0.5, dps * 0.45 * dt, dt)

	_beam_spark_cd -= dt


func _damage_column(x: float, y: float, half_w: float, dmg: float, dt: float) -> void:
	var hw := half_w * 0.5 + 6.0
	# Reverse index: damaging an enemy can kill it, which erases it from
	# `enemies` mid-loop, and a forward iterator would then skip its neighbour.
	var i := enemies.size() - 1
	while i >= 0:
		var e = enemies[i]
		i -= 1
		if not e.alive or not e.hittable:
			continue
		if e.position.y > y:
			continue
		if absf(e.position.x - x) > hw + e.hit_radius:
			continue
		damage_dealt.emit(e, dmg, Vector2(x, e.position.y))
		if _beam_spark_cd <= 0.0:
			fx.spark(Vector2(x, e.position.y + e.hit_radius * 0.5),
				colour.lightened(0.4), 0.13)
	if _beam_spark_cd <= 0.0:
		_beam_spark_cd = 0.05


# --- Bomb ----------------------------------------------------------------

func _try_bomb() -> void:
	if bombs <= 0 or bomb_time > 0.0:
		return
	bombs -= 1
	bomb_time = BOMB_TIME
	invuln = maxf(invuln, BOMB_TIME + BOMB_INVULN)
	# Wipe the screen the instant it goes off - a bomb is a panic button, so
	# it has to pay out immediately rather than as an expanding front.
	bullets.clear_all(true)
	fx.shockwave(position, 520.0, colour, 0.7, 16.0)
	fx.shockwave(position, 900.0, Color(1, 1, 1, 0.9), 1.0, 9.0)
	fx.explode(position, 2.2, colour)
	AU.play("bomb")
	bomb_fired.emit()


func _update_bomb(dt: float) -> void:
	if bomb_time <= 0.0:
		return
	bomb_time -= dt
	# Keep suppressing fire for the whole burn, so anything an enemy launches
	# mid-bomb is swallowed too and the window is genuinely safe.
	bullets.clear_all(true)
	var i := enemies.size() - 1
	while i >= 0:
		var e = enemies[i]
		i -= 1
		if e.alive and e.hittable:
			damage_dealt.emit(e, BOMB_DPS * dt, e.position)
	if randf() < dt * 14.0:
		fx.explode(position + Vector2(randf_range(-260, 260), randf_range(-420, 180)),
			1.2, colour.lightened(0.2))


# --- Death / respawn -----------------------------------------------------

func hit() -> void:
	if not is_vulnerable():
		return
	state = State.DYING
	_dead_timer = RESPAWN_DELAY
	_sprite.visible = false
	_beam.visible = false
	for o in _options:
		o.visible = false
		o.beam.visible = false
	fx.explode(position, 2.4, Color(1, 0.6, 0.35))
	fx.shockwave(position, 300.0, Color(1, 0.85, 0.6), 0.6, 10.0)
	AU.set_laser(false)
	AU.play("death")
	power = maxi(1, power - DEATH_POWER_LOSS)
	_refresh_beams()
	life_lost.emit()


func _begin_respawn() -> void:
	state = State.RESPAWNING
	_sprite.visible = true
	position = Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H + 90.0)
	invuln = INVULN_TIME
	bombs = maxi(bombs, 2)
	for o in _options:
		o.position = position


func _respawn_move(dt: float) -> void:
	var target := Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H - 170.0)
	position = position.move_toward(target, 620.0 * dt)
	_update_options(dt)
	if position.distance_to(target) < 2.0:
		state = State.ALIVE


func _update_visuals(_dt: float) -> void:
	if not is_instance_valid(_sprite):
		return
	_sprite.frame = _bank * 2 + (int(_t * 14.0) % 2)
	var blink: bool = invuln > 0.0 and state != State.DYING
	_sprite.modulate.a = (0.45 + 0.55 * absf(sin(_t * 18.0))) if blink else 1.0
	_shield.visible = blink
	if _shield.visible:
		_shield.frame = int(_t * 10.0) % 4
		_shield.rotation = _t * 1.4
	_hitbox.visible = is_focused()
	if _hitbox.visible:
		_hitbox.queue_redraw()
	_trail.visible = _sprite.visible
	if _trail.visible:
		# A shorter, tighter plume while focused sells the speed difference.
		_trail.push(position, 0.45 if laser_held else 1.0)


## Twin exhaust plumes trailing the thrusters. The points are stored in
## playfield space and converted on draw, so hard turns smear the trail
## sideways instead of rigidly following the hull.
class EngineTrail:
	extends Node2D
	const MAX_POINTS := 16
	const NOZZLES := [-9.0, 9.0]

	var colour := Color.WHITE
	var _pts: Array[Vector2] = []
	var _origin := Vector2.ZERO
	var _intensity := 1.0

	func push(world_pos: Vector2, intensity: float) -> void:
		_origin = world_pos
		_intensity = lerpf(_intensity, intensity, 0.2)
		_pts.push_front(world_pos)
		if _pts.size() > MAX_POINTS:
			_pts.resize(MAX_POINTS)
		queue_redraw()

	func _draw() -> void:
		if _pts.size() < 2:
			return
		var n := _pts.size()
		for nozzle in NOZZLES:
			for i in range(n - 1):
				var t := float(i) / float(n - 1)
				var fade: float = (1.0 - t) * (1.0 - t) * 0.55 * _intensity
				var w: float = lerpf(5.0, 1.0, t) * _intensity
				var off := Vector2(nozzle, 16.0)
				draw_line(
					_pts[i] - _origin + off, _pts[i + 1] - _origin + off,
					Color(colour.r, colour.g, colour.b, fade), w, true)


## The tiny focus dot that shows the real hitbox while the laser is held.
class HitboxDot:
	extends Node2D
	func _draw() -> void:
		draw_circle(Vector2.ZERO, Cfg.PLAYER_HITBOX + 5.0, Color(1, 1, 1, 0.30))
		draw_circle(Vector2.ZERO, Cfg.PLAYER_HITBOX + 1.5, Color(1, 0.3, 0.35, 0.95))
		draw_circle(Vector2.ZERO, Cfg.PLAYER_HITBOX * 0.55, Color(1, 1, 1, 1))
