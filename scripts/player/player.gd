class_name Player
extends Node2D
## The player ship.
##
## Two weapons share one body, DoDonPachi style, and the pair you are holding
## depends on the weapon mode (swapped in the field by a W pickup):
##
##   VULCAN   SHOT  (J) - rapid spread bullets, full speed, bits fanned wide
##            LASER (K) - continuous piercing beam, ~40% speed, bits tucked in
##   TRACKER  SHOT  (J) - homing laser segments; weaker per hit, but they land
##            LASER (K) - hold to paint targets inside a ring, release to fire
##                        a heavy missile at each one
##
## Holding both favours the laser button in either mode, since the slow speed is
## the trade-off that makes precise dodging possible.

signal life_lost
signal bomb_fired
signal hyper_started
signal hyper_ended
signal damage_dealt(enemy: Node2D, amount: float, at: Vector2)

enum State { ALIVE, DYING, RESPAWNING }
enum Weapon { VULCAN, TRACKER }

const WEAPON_NAMES := ["VULCAN", "TRACKER"]

## Seconds between acquisitions while the lock ring is held. Quick: the cost of
## a salvo is the focus-speed movement and the ring's reach, not the wait.
const LOCK_INTERVAL := 0.055
## The ring opens at this fraction of its full radius and widens while K is held,
## so holding longer buys both more targets and more reach. Both the opening and
## the full size come from the ship's per-power lock_radius, so a powered-up
## lock is visibly a wider net. Growth is in pixels per second.
const LOCK_RADIUS_START_FRAC := 0.42
const LOCK_GROW := 430.0
## Dead time after a salvo before the ring can paint anything again. Without it,
## tapping K fires a one-missile salvo every tap - free damage, and a pile of
## launch whooshes layered on top of each other.
const LOCK_REFIRE := 0.35
## Fire-rate multiplier for the tracking beam while K is painting a lock and J
## is not held. Higher is slower.
const LOCK_FIRE_SLOW := 1.5

const RESPAWN_DELAY := 0.85
const INVULN_TIME := 2.6
const BOMB_TIME := 2.3
const BOMB_INVULN := 0.6
## Damage per second applied to everything on screen while a bomb burns.
const BOMB_DPS := 300.0
## With twelve power levels a single step back barely registers, so a death
## costs a little more.
const DEATH_POWER_LOSS := 2

## Option bits share one damage budget: this is their combined contribution as a
## fraction of the main beam, split between however many bits are active. A
## third and fourth bit therefore widen coverage instead of multiplying damage.
const OPT_BEAM_TOTAL := 0.90

## Power at which the shot gains its wide secondary volley, and its rear pair.
const WIDE_SHOT_POWER := 5
const WING_SHOT_POWER := 9

## Above this line every item on screen is magnetised, rewarding aggression.
const AUTO_COLLECT_Y := 260.0

var ship: Dictionary
var ship_index := 0
var colour := Color.WHITE

var power := 1
## Chips banked toward the next power level; see Cfg.POWER_CHIP_COST.
var power_chips := 0
var bombs := Cfg.MAX_BOMBS
var weapon: int = Weapon.VULCAN
var state: int = State.ALIVE

var invuln := 0.0
var bomb_time := 0.0

var laser_held := false
var shot_held := false

## Hyper: charge accrues through play, fires itself at full, then drains.
var hyper_charge := 0.0
var hyper_time := 0.0

## Wired up by the game scene. `bullets` is the player's own pool; the bomb and
## hyper absorb need the enemy pool, which is a different manager entirely.
var bullets: BulletManager
var enemy_bullets: BulletManager
var fx: FxLayer
var enemies: Array = []
var option_root: Node2D

var _sprite: Sprite2D
var _beam: Beam
var _lock_ring: LockRing
## Enemies painted by the current lock, in acquisition order.
var _locks: Array = []
var _lock_cd := 0.0
var _locking := false
## Current ring radius, which grows while K is held. Reset via _lock_reset(),
## which needs `ship`, so this initial value only covers construction.
var _lock_r := 120.0
var _shield: Sprite2D
var _hitbox: Node2D
var _trail: EngineTrail
var _aura: Sprite2D
var _options: Array[OptionBit] = []
var _shot_cd := 0.0
var _opt_cd := 0.0
## Alternates each tracking segment to one side of the nose, so the stream
## weaves instead of stacking on a single line.
var _track_side := 1.0
var _beam_spark_cd := 0.0
var _beam_hyper := false
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

	_lock_ring = LockRing.new()
	_lock_ring.col = Cfg.TRACK_TINT.lerp(Color.WHITE, 0.25)
	_lock_ring.z_index = 4
	_lock_ring.visible = false
	add_child(_lock_ring)

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

	_aura = Sprite2D.new()
	_aura.centered = true
	Art.apply_sheet(_aura, "shield", true)
	_aura.scale = Vector2.ONE * 0.85
	_aura.modulate = Color(1.0, 0.55, 0.9, 0.55)
	_aura.visible = false
	_aura.z_index = -1
	add_child(_aura)

	_trail = EngineTrail.new()
	_trail.colour = colour
	_trail.z_index = -3
	add_child(_trail)

	position = Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H - 170.0)
	invuln = INVULN_TIME


## Bits must live outside the ship's transform so they can trail behind it.
func spawn_options(root: Node2D) -> void:
	option_root = root
	# Four bits exist from the start; opt_count decides how many are shown.
	# Sides alternate so each new pair is symmetric.
	for i in 4:
		var o := OptionBit.new()
		o.setup(colour, -1.0 if i % 2 == 0 else 1.0)
		root.add_child(o)
		o.position = position
		_options.append(o)
	_refresh_beams()


func _refresh_beams() -> void:
	var w: float = ShipDefs.at_power(ship, "laser_width", power)
	_beam.configure(w, Color(colour.r, colour.g, colour.b, 0.92))
	var count: int = ShipDefs.at_power(ship, "opt_count", power)
	var share := OPT_BEAM_TOTAL / float(maxi(count, 1))
	for o in _options:
		o.beam.configure(w * 0.45, Color(colour.r, colour.g, colour.b, 0.7))
		o.beam_share = share


func is_vulnerable() -> bool:
	# Hyper eats bullets rather than taking them, so it reads as immunity here.
	return state == State.ALIVE and invuln <= 0.0 and hyper_time <= 0.0


func is_hyper() -> bool:
	return hyper_time > 0.0


## Feeds the hyper meter. Auto-fires the moment it tops out.
func add_charge(amount: float) -> void:
	if hyper_time > 0.0 or state != State.ALIVE:
		return
	hyper_charge = clampf(hyper_charge + amount, 0.0, 1.0)
	if hyper_charge >= 1.0:
		_start_hyper()


func _start_hyper() -> void:
	hyper_time = Cfg.HYPER_TIME
	hyper_charge = 1.0
	fx.shockwave(position, 420.0, Color(1.0, 0.55, 0.9), 0.8, 14.0)
	fx.popup(position + Vector2(0, -70), "HYPER", Color(1.0, 0.55, 0.9), 34)
	AU.play("extend")
	hyper_started.emit()


func _update_hyper(dt: float) -> void:
	if hyper_time <= 0.0:
		return
	hyper_time -= dt
	hyper_charge = clampf(hyper_time / Cfg.HYPER_TIME, 0.0, 1.0)
	# Absorb, rather than merely survive: bullets near the hull are eaten and
	# scored, which is what makes hyper feel like a reward instead of a shield.
	enemy_bullets.clear_radius(position, Cfg.HYPER_ABSORB_RADIUS, true)
	if hyper_time <= 0.0:
		hyper_time = 0.0
		hyper_charge = 0.0
		hyper_ended.emit()


func is_focused() -> bool:
	return laser_held and state == State.ALIVE


func bomb_active() -> bool:
	return bomb_time > 0.0


## Banks `n` chips and levels up whenever the current bar's cost is met.
## Returns true if a level was actually gained.
func add_power(n: int = 1) -> bool:
	if power >= Cfg.MAX_POWER:
		return false
	power_chips += n
	var gained := false
	while power < Cfg.MAX_POWER and power_chips >= Cfg.chip_cost(power):
		power_chips -= Cfg.chip_cost(power)
		power += 1
		gained = true
	if power >= Cfg.MAX_POWER:
		power_chips = 0
	if gained:
		_refresh_beams()
	return gained


## Progress toward the next level, 0..1, for the HUD.
func chip_fraction() -> float:
	if power >= Cfg.MAX_POWER:
		return 1.0
	return clampf(float(power_chips) / float(Cfg.chip_cost(power)), 0.0, 1.0)


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
	_update_hyper(dt)
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

	if weapon == Weapon.TRACKER:
		_tracker(dt)
	else:
		_vulcan(dt)


## The original pair: continuous beam on K, spread on J.
func _vulcan(dt: float) -> void:
	AU.set_laser(laser_held)
	if laser_held:
		_fire_laser(dt)
		return
	_hide_beams()
	if shot_held:
		_fire_shot(dt)
	else:
		_shot_cd = 0.0
		_opt_cd = 0.0


## Homing stream on J, lock-and-release missiles on K. Beams and bits are both
## idle in this mode; K still slows you, so it reads as "focus" either way.
##
## Either button keeps the beam firing. Painting a lock is an overlay on the
## ship's gun, not a replacement for it: having K stop the stream outright left
## the screen with no fire on it at all for the second or two a big rack takes
## to fill, which is the one thing a shmup must never do. Lock-only fire is
## slower, so J is still the choice when all you want is damage.
func _tracker(dt: float) -> void:
	AU.set_laser(false)
	_hide_beams()
	_update_locks(dt)
	if shot_held or laser_held:
		_fire_track(dt, 1.0 if shot_held else LOCK_FIRE_SLOW)
	else:
		_shot_cd = 0.0


func _hide_beams() -> void:
	_beam.visible = false
	for o in _options:
		o.beam.visible = false


func _update_options(dt: float) -> void:
	# The bits are vulcan hardware. TRACKER fires one beam out of the ship and
	# nothing else, so they dock and go dark - but they keep following, or they
	# would snap back across the screen when you switch weapons.
	var count: int = 0 if weapon == Weapon.TRACKER \
		else int(ShipDefs.at_power(ship, "opt_count", power))
	var spread: Array = ship.opt_spread
	var tight: Array = ship.opt_tight
	for i in _options.size():
		var o := _options[i]
		o.visible = i < count
		var lane: int = mini(i, spread.size() - 1) if count > 1 else 0
		var dx: float = float(tight[lane]) if laser_held else float(spread[lane])
		var dy := 26.0 if laser_held else 14.0
		o.follow(position, Vector2(o.side * dx, dy), dt)


func _fire_shot(dt: float) -> void:
	_shot_cd -= dt
	if _shot_cd <= 0.0:
		var rate := float(ship.shot_rate)
		if is_hyper():
			rate *= Cfg.HYPER_FIRE_BOOST
		_shot_cd += rate

		var n: int = ShipDefs.at_power(ship, "shot_n", power)
		var dmg: int = ShipDefs.at_power(ship, "shot_damage", power)
		var pierce: int = ShipDefs.at_power(ship, "shot_pierce", power)
		var spread: float = float(ship.shot_spread) * PI / 180.0
		var spd: float = ship.shot_speed * _shot_speed_mul()
		var mul := _shot_scale_mul()
		var col := _shot_colour()
		var nose := position + Vector2(0, -30)
		for i in n:
			var t := 0.0 if n == 1 else float(i) / float(n - 1) - 0.5
			var a := -PI * 0.5 + t * spread
			var b := bullets.spawn(nose, a, spd, "pshot", col, mul)
			if b:
				b.damage = dmg
				b.pierce = pierce
				b.life = 2.5

		# Bar two adds a wide secondary pair, bar three a swept-back pair, so
		# each new bar visibly changes the shape of your fire.
		if power >= WIDE_SHOT_POWER:
			_extra_pair(nose, spread * 1.6, spd * 0.92, dmg, pierce, "pspread")
		if power >= WING_SHOT_POWER:
			_extra_pair(nose, spread * 2.8 + 0.5, spd * 0.85, dmg, pierce, "pspread")
		if is_hyper():
			_extra_pair(nose, 0.16, spd * 1.1, dmg, pierce + 1, "pshot")

		fx.muzzle(nose, -PI * 0.5, col, 0.14 * mul)
		AU.play("shot", 0.07)

	_opt_cd -= dt
	if _opt_cd <= 0.0:
		_opt_cd += float(ship.opt_rate)
		var odmg: int = ShipDefs.at_power(ship, "opt_damage", power)
		var count: int = ShipDefs.at_power(ship, "opt_count", power)
		for i in mini(count, _options.size()):
			var o := _options[i]
			if String(ship.opt_mode) == "missile":
				var m := bullets.spawn(o.position, -PI * 0.5 + o.side * 0.5,
					420.0 * _shot_speed_mul(), "pmissile",
					_shot_colour().lightened(0.25), _shot_scale_mul())
				if m:
					m.damage = odmg
					m.homing = 300.0 * PI / 180.0
					m.homing_time = 2.0
					m.accel = 900.0
					m.speed_max = 1150.0
					m.life = 2.6
			else:
				var b := bullets.spawn(o.position, -PI * 0.5,
					float(ship.shot_speed) * 0.9 * _shot_speed_mul(),
					"pspread", _shot_colour().lightened(0.2), _shot_scale_mul())
				if b:
					b.damage = odmg
					b.life = 2.5


# --- Tracker -----------------------------------------------------------------

## One stream, straight off the nose. Segments launch slowly and are reeled in
## by their own homing, so the beam snakes onto a target instead of flying at it
## in a straight line, and consecutive segments overlap into a continuous rope.
##
## Power makes this beam *bigger* rather than adding more of it: the bits stay
## dark in this mode, so everything the tracker does comes out of the ship.
func _fire_track(dt: float, rate_mul: float = 1.0) -> void:
	_shot_cd -= dt
	if _shot_cd <= 0.0:
		var rate := float(ship.track_rate) * rate_mul
		if is_hyper():
			rate *= Cfg.HYPER_FIRE_BOOST
		_shot_cd += rate

		var dmg: int = ShipDefs.at_power(ship, "track_damage", power)
		var turn: float = float(ship.track_turn) * PI / 180.0
		var col := _track_colour()
		var mul := _track_scale_mul()
		var nose := position + Vector2(0, -30)
		# A slight alternating kick keeps the rope weaving rather than laying
		# every segment down the same line.
		_track_side = -_track_side
		var b := bullets.spawn(nose, -PI * 0.5 + _track_side * 0.22,
			420.0 * _shot_speed_mul(), "ptrack", col, mul)
		if b != null:
			b.damage = dmg
			b.homing = turn
			b.homing_time = 2.0
			b.accel = 1500.0
			b.speed_max = 1450.0 * _shot_speed_mul()
			b.life = 1.8
			b.trail_len = 20.0 * mul
		fx.muzzle(nose, -PI * 0.5, col, 0.11 * mul)
		AU.play("track", 0.09)


## Paints targets while K is held; the salvo goes out on release.
func _update_locks(dt: float) -> void:
	var was_locking := _locking
	_locking = laser_held
	_prune_locks()

	if not _locking:
		_lock_ring.visible = false
		_lock_reset()
		if was_locking:
			_fire_locks()
		return

	_lock_r = minf(_lock_r + LOCK_GROW * dt, lock_radius())

	var cap: int = ShipDefs.at_power(ship, "lock_max", power)
	_lock_cd -= dt
	if _lock_cd <= 0.0 and _locks.size() < cap:
		var t := _next_lock_target()
		if t != null:
			# Only a *new* target ticks. Stacking three missiles on one enemy
			# (or a whole rack on a boss) is one acquisition as far as the ear
			# is concerned; ticking per missile piled them into a machine-gun.
			var fresh := not _locks.has(t)
			_locks.append(t)
			_lock_cd = LOCK_INTERVAL
			if fresh:
				# Steps up with each target painted, so a filling rack is
				# audible without having to watch the counter. Capped, or a
				# twelve-slot Goliath lock climbs into a whistle.
				AU.play("lock", 0.02, 0.0,
					1.0 + 0.05 * float(mini(_distinct_locks() - 1, 6)))

	_lock_ring.visible = true
	_lock_ring.origin = position
	_lock_ring.radius = _lock_r
	_lock_ring.targets = _locks
	_lock_ring.full = _locks.size() >= cap


## The nearest lockable enemy, preferring ones nothing is aimed at yet: every
## target in the ring gets a first missile before any target gets a second.
## A boss will happily take the whole rack; ordinary enemies cap out low so one
## popcorn ship cannot swallow a salvo meant for the wave around it.
func _next_lock_target() -> Node2D:
	var r := _lock_r
	var cap := lock_cap()
	var best: Node2D = null
	var best_key := INF
	for e in enemies:
		if not e.alive or not e.hittable:
			continue
		var d: float = position.distance_to(e.position)
		if d > r:
			continue
		var stacked := _lock_count(e)
		if stacked >= (cap if e is Boss else Cfg.LOCK_STACK_MAX):
			continue
		var key := float(stacked) * 100000.0 + d
		if key < best_key:
			best_key = key
			best = e
	return best


func _lock_count(e: Node2D) -> int:
	var n := 0
	for l in _locks:
		if l == e:
			n += 1
	return n


## How many separate enemies are painted, as opposed to missiles committed.
func _distinct_locks() -> int:
	var seen: Array = []
	for l in _locks:
		if not seen.has(l):
			seen.append(l)
	return seen.size()


func _prune_locks() -> void:
	var i := _locks.size() - 1
	while i >= 0:
		var e = _locks[i]
		if not is_instance_valid(e) or not e.alive or not e.hittable:
			_locks.remove_at(i)
		i -= 1


func _fire_locks() -> void:
	if _locks.is_empty():
		return
	var dmg: int = ShipDefs.at_power(ship, "lock_damage", power)
	# Turns hard enough to stay on a target at 2500px/s, which is the whole
	# reason these are worth the focus-speed movement it took to paint them.
	var turn := 900.0 * PI / 180.0
	var col := _track_colour().lightened(0.15)
	var fired := 0
	for i in _locks.size():
		var e = _locks[i]
		if not is_instance_valid(e) or not e.alive:
			continue
		# Fan the launch angles so a salvo blooms outward and curves back in
		# rather than leaving as one indistinguishable column.
		var t := 0.0 if _locks.size() == 1 \
			else float(i) / float(_locks.size() - 1) - 0.5
		var m := bullets.spawn(position + Vector2(0, -18),
			-PI * 0.5 + t * 1.7, 620.0 * _shot_speed_mul(), "plock",
			col, _shot_scale_mul())
		if m == null:
			break
		m.seek = e
		m.damage = dmg
		m.homing = turn
		m.homing_time = 3.0
		m.accel = 5200.0
		m.speed_max = 2500.0
		m.life = 2.0
		m.trail_len = 64.0
		fired += 1
	_locks.clear()
	if fired == 0:
		return
	# Persists across the release, so the next hold cannot paint until it
	# expires - the ring itself is the cooldown indicator.
	_lock_cd = LOCK_REFIRE
	fx.shockwave(position, 130.0, col, 0.35, 6.0)
	AU.play("missile", 0.08)


## Shrinks the ring back to its opening size for the next hold.
func _lock_reset() -> void:
	_lock_r = lock_radius() * LOCK_RADIUS_START_FRAC


func _clear_locks() -> void:
	_locks.clear()
	_locking = false
	_lock_cd = 0.0
	_lock_reset()
	if _lock_ring != null:
		_lock_ring.visible = false


## Tracking fire carries the mode's tint over the ship's own colour, so which
## weapon is up is obvious from the projectiles alone.
## The mode's colour leads and the hull's follows, rather than the other way
## round: which gun you are holding has to be readable from the fire itself.
func _track_colour() -> Color:
	var c := Cfg.TRACK_TINT.lerp(colour, 0.22)
	return c.lerp(Cfg.HYPER_TINT, 0.4) if is_hyper() else c


## Swaps weapon mode - what the W pickup does. Returns the new mode's name.
func cycle_weapon() -> String:
	weapon = Weapon.VULCAN if weapon == Weapon.TRACKER else Weapon.TRACKER
	_clear_locks()
	_hide_beams()
	AU.set_laser(false)
	_shot_cd = 0.0
	_opt_cd = 0.0
	fx.shockwave(position, 230.0, _track_colour(), 0.5, 9.0)
	AU.play("weapon")
	return weapon_name()


func weapon_name() -> String:
	return WEAPON_NAMES[weapon]


## The hull's current sheet frame - thruster cycle and bank. The HUD's ship
## portrait plays this back, so the sidebar leans and burns with the real ship.
func sprite_frame() -> int:
	return _sprite.frame if is_instance_valid(_sprite) else 2


## Painted targets and the current ceiling, for the HUD.
func lock_count() -> int:
	return _locks.size()


func lock_cap() -> int:
	return int(ShipDefs.at_power(ship, "lock_max", power))


## The ring's full radius at the current power level.
func lock_radius() -> float:
	return float(ShipDefs.at_power(ship, "lock_radius", power))


## Hyper fattens, accelerates and tints your fire.
func _shot_scale_mul() -> float:
	return Cfg.HYPER_BULLET_SCALE if is_hyper() else 1.0


## The tracking beam's thickness, which is what power buys in this mode. Hyper
## adds to it, but at a gentler rate than it fattens vulcan shots - the beam is
## already large by then.
func _track_scale_mul() -> float:
	var s: float = ShipDefs.at_power(ship, "track_scale", power)
	return s * (1.25 if is_hyper() else 1.0)


func _shot_speed_mul() -> float:
	return Cfg.HYPER_BULLET_SPEED if is_hyper() else 1.0


func _shot_colour() -> Color:
	return colour.lerp(Cfg.HYPER_TINT, 0.4) if is_hyper() else colour


## Two mirrored shots at +/- `half_spread` from straight up.
func _extra_pair(from: Vector2, half_spread: float, spd: float, dmg: int,
		pierce: int, style: String) -> void:
	for sign_ in [-1.0, 1.0]:
		var b := bullets.spawn(from, -PI * 0.5 + sign_ * half_spread, spd,
			style, _shot_colour().lightened(0.15), _shot_scale_mul())
		if b:
			b.damage = dmg
			b.pierce = pierce
			b.life = 2.5


## The laser is a persistent column: everything in the strip above the emitter
## takes damage every frame.
func _fire_laser(dt: float) -> void:
	var dps: float = ShipDefs.at_power(ship, "laser_dps", power)
	var width: float = ShipDefs.at_power(ship, "laser_width", power)
	if is_hyper():
		# Laser players would otherwise get no visible hyper payoff.
		width *= Cfg.HYPER_BULLET_SCALE
		_beam.configure(width, Color(Cfg.HYPER_TINT.r, Cfg.HYPER_TINT.g,
			Cfg.HYPER_TINT.b, 0.92))
	elif _beam_hyper:
		_refresh_beams()
	_beam_hyper = is_hyper()

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
		_damage_column(o.position.x, o.position.y, width * 0.45,
			dps * o.beam_share * dt, dt)

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
	enemy_bullets.clear_all(true)
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
	enemy_bullets.clear_all(true)
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
	_clear_locks()
	for o in _options:
		o.visible = false
		o.beam.visible = false
	fx.explode(position, 2.4, Color(1, 0.6, 0.35))
	fx.shockwave(position, 300.0, Color(1, 0.85, 0.6), 0.6, 10.0)
	AU.set_laser(false)
	AU.play("death")
	power = maxi(1, power - DEATH_POWER_LOSS)
	power_chips = 0
	_refresh_beams()
	life_lost.emit()


## Full reset for an Endless continue: back to a fresh ship at base power.
func revive() -> void:
	state = State.ALIVE
	_sprite.visible = true
	visible = true
	set_process(true)
	position = Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H - 170.0)
	invuln = INVULN_TIME
	bombs = Cfg.MAX_BOMBS
	power = 1
	power_chips = 0
	weapon = Weapon.VULCAN
	hyper_time = 0.0
	hyper_charge = 0.0
	_clear_locks()
	_refresh_beams()
	for o in _options:
		o.position = position
	fx.shockwave(position, 260.0, colour, 0.6, 9.0)


func _begin_respawn() -> void:
	state = State.RESPAWNING
	_sprite.visible = true
	position = Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H + 90.0)
	invuln = INVULN_TIME
	bombs = clampi(bombs, 2, Cfg.MAX_BOMBS)
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
	_aura.visible = is_hyper()
	if _aura.visible:
		_aura.frame = int(_t * 14.0) % 4
		_aura.rotation = -_t * 2.6
		_aura.scale = Vector2.ONE * (0.85 + 0.06 * sin(_t * 9.0))
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


## The acquisition display for TRACKER's lock: a dashed ring at the ship's lock
## radius plus a bracket on every painted target. Drawn in the player's local
## space, so target positions are offset by `origin` (the ship in field space).
class LockRing:
	extends Node2D
	const SEGMENTS := 40

	var radius := 240.0
	var col := Color.WHITE
	var origin := Vector2.ZERO
	var targets: Array = []
	## True once the ring is holding all the targets this power level allows.
	var full := false

	var _t := 0.0

	func _process(dt: float) -> void:
		if not visible:
			return
		_t += dt
		queue_redraw()

	func _draw() -> void:
		# Dashes rather than a solid circle: a solid ring this size reads as a
		# shield, which is the one thing it must not be mistaken for.
		var spin := _t * 1.6
		var a := 0.55 + (0.45 if full else 0.20) * absf(sin(_t * 6.0))
		for i in range(0, SEGMENTS, 2):
			var a0 := spin + TAU * float(i) / float(SEGMENTS)
			var a1 := spin + TAU * float(i + 1) / float(SEGMENTS)
			draw_line(Vector2.from_angle(a0) * radius,
				Vector2.from_angle(a1) * radius,
				Color(col.r, col.g, col.b, a), 3.0)
		# A faint inner disc edge, so a ring caught mid-growth is legible as
		# "still opening" rather than as a ring that happens to be small.
		draw_arc(Vector2.ZERO, radius * 0.86, 0.0, TAU, 24,
			Color(col.r, col.g, col.b, a * 0.22), 1.5)

		for e in targets:
			if not is_instance_valid(e):
				continue
			_bracket(e.position - origin, maxf(e.hit_radius * 0.9, 18.0))

	## Four corner ticks around a painted target, spun a little so a stack of
	## locks on one enemy is visible as motion rather than a single static box.
	func _bracket(at: Vector2, r: float) -> void:
		var c := Color(col.r, col.g, col.b, 0.85)
		var arm := r * 0.55
		for q in 4:
			var cx: float = -1.0 if q % 2 == 0 else 1.0
			var cy: float = -1.0 if q < 2 else 1.0
			var corner := at + Vector2(cx * r, cy * r)
			draw_line(corner, corner - Vector2(cx * arm, 0.0), c, 2.0)
			draw_line(corner, corner - Vector2(0.0, cy * arm), c, 2.0)
		draw_circle(at, 3.0, Color(col.r, col.g, col.b, 0.55))


## The tiny focus dot that shows the real hitbox while the laser is held.
class HitboxDot:
	extends Node2D
	func _draw() -> void:
		draw_circle(Vector2.ZERO, Cfg.PLAYER_HITBOX + 5.0, Color(1, 1, 1, 0.30))
		draw_circle(Vector2.ZERO, Cfg.PLAYER_HITBOX + 1.5, Color(1, 0.3, 0.35, 0.95))
		draw_circle(Vector2.ZERO, Cfg.PLAYER_HITBOX * 0.55, Color(1, 1, 1, 1))
