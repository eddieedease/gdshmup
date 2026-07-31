class_name BulletManager
extends Node2D
## Fixed-size pool that owns, updates and collision-tests every bullet.
##
## One manager exists per team. Iterating a flat array of live bullets once per
## frame keeps the whole bullet-hell in a single tight loop.

enum { TEAM_ENEMY, TEAM_PLAYER }

signal player_hit(bullet: Bullet)
signal player_grazed(bullet: Bullet)
signal enemy_hit(enemy: Node2D, bullet: Bullet)
signal bullet_cleared(pos: Vector2)

var team := TEAM_ENEMY

## Assigned by the game scene. `enemies` is shared by reference, so it must be
## mutated in place rather than reassigned.
var player: Node2D = null
var enemies: Array = []

var _pool: Array[Bullet] = []
var _free: Array[Bullet] = []
var _live: Array[Bullet] = []

var _target := Vector2(Cfg.FIELD_W * 0.5, Cfg.FIELD_H * 0.8)
var _trails: TrailLayer


## Draws the streaks for every live bullet that asked for one. A single pass
## here is far cheaper than giving each bullet its own trail node.
class TrailLayer:
	extends Node2D
	var owner_mgr: BulletManager

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array()
		pts.resize(4)
		var cols := PackedColorArray()
		cols.resize(4)
		for b in owner_mgr.live_bullets():
			if b.trail_len <= 0.0 or b.delay > 0.0:
				continue
			var back := -Vector2.from_angle(b.dir) * b.trail_len
			var side := Vector2.from_angle(b.dir + PI * 0.5) * (b.radius * 0.55)
			var head: Color = b.modulate
			head.a = 0.5
			var tail := Color(head.r, head.g, head.b, 0.0)
			pts[0] = b.position + side
			pts[1] = b.position - side
			pts[2] = b.position + back - side * 0.25
			pts[3] = b.position + back + side * 0.25
			cols[0] = head
			cols[1] = head
			cols[2] = tail
			cols[3] = tail
			draw_polygon(pts, cols)


func setup(which: int, capacity: int) -> void:
	team = which
	# Drawn under the bullets so a streak never hides its own head.
	_trails = TrailLayer.new()
	_trails.owner_mgr = self
	_trails.z_index = -1
	add_child(_trails)
	_pool.resize(0)
	for i in capacity:
		var b := Bullet.new()
		b.visible = false
		b.alive = false
		b.centered = true
		add_child(b)
		_pool.append(b)
		_free.append(b)


func live_count() -> int:
	return _live.size()


## Live bullets, for the trail layer. Read-only by convention.
func live_bullets() -> Array[Bullet]:
	return _live


## Grabs a bullet from the pool and points it along `heading`.
## Returns null when the pool is exhausted (the hell is already full enough).
func spawn(pos: Vector2, heading: float, speed: float, style: String,
		color: Color = Color.WHITE, scale_mul: float = 1.0) -> Bullet:
	if _free.is_empty():
		return null
	var b: Bullet = _free.pop_back()
	b.reset()
	b.position = pos
	b.dir = heading
	b.speed = speed
	b.rotation = heading + Bullet.ART_OFFSET
	b.modulate = color
	_style(b, style, scale_mul)
	b.base_scale = b.scale
	b.base_color = color
	_live.append(b)
	return b


## Bullet art sizes. Visuals were bumped ~25% for legibility while hitboxes
## grew only ~12%, so bullets read bigger without dodging getting stricter.
func _style(b: Bullet, style: String, mul: float) -> void:
	match style:
		"tiny":
			b.frames = Art.apply_sheet(b, "enemyshot", true)
			b.scale = Vector2.ONE * 0.13 * mul
			b.radius = 7.4 * mul
		"small":
			b.frames = Art.apply_sheet(b, "enemyshot", true)
			b.scale = Vector2.ONE * 0.19 * mul
			b.radius = 10.4 * mul
		"orb":
			b.frames = Art.apply_sheet(b, "plasma", true)
			b.scale = Vector2.ONE * 0.255 * mul
			b.radius = 14.4 * mul
		"bigorb":
			b.frames = Art.apply_sheet(b, "plasma", true)
			b.scale = Vector2.ONE * 0.30 * mul
			b.radius = 21.0 * mul
		"needle":
			b.frames = Art.apply_sheet(b, "laser", true)
			b.scale = Vector2(0.145, 0.31) * mul
			b.radius = 8.5 * mul
		"wave":
			b.frames = Art.apply_sheet(b, "wavebeam", true)
			b.scale = Vector2.ONE * 0.235 * mul
			b.radius = 12.0 * mul
		"missile":
			b.frames = Art.apply_sheet(b, "missile", true)
			b.scale = Vector2.ONE * 0.25 * mul
			b.radius = 12.0 * mul
		"bolt":
			b.frames = Art.apply_sheet(b, "bolt", true)
			b.scale = Vector2.ONE * 0.235 * mul
			b.radius = 10.9 * mul
		"spread":
			b.frames = Art.apply_sheet(b, "spread", true)
			b.scale = Vector2.ONE * 0.20 * mul
			b.radius = 13.0 * mul
		"shard":
			b.frames = Art.apply_sheet(b, "bolt", true)
			b.scale = Vector2(0.13, 0.24) * mul
			b.radius = 9.0 * mul
		"comet":
			# Big soft head; pair with a `trail` for a proper streaking comet.
			b.frames = Art.apply_sheet(b, "plasma", true)
			b.scale = Vector2.ONE * 0.24 * mul
			b.radius = 14.0 * mul
		"star":
			# Non-directional and spinning: reads as ornament, not a dart.
			b.frames = Art.apply_sheet(b, "spread", true)
			b.scale = Vector2.ONE * 0.24 * mul
			b.radius = 14.0 * mul
		"seed":
			# Carrier for scatter patterns: fat and slow so the split reads.
			b.frames = Art.apply_sheet(b, "plasma", true)
			b.scale = Vector2.ONE * 0.30 * mul
			b.radius = 15.0 * mul
		"pshot":
			b.frames = Art.apply_sheet(b, "bolt", true)
			b.scale = Vector2(0.19, 0.28) * mul
			b.radius = 14.0 * mul
		"pspread":
			b.frames = Art.apply_sheet(b, "spread", true)
			b.scale = Vector2.ONE * 0.25 * mul
			b.radius = 17.0 * mul
		"pmissile":
			b.frames = Art.apply_sheet(b, "missile", true)
			b.scale = Vector2.ONE * 0.24 * mul
			b.radius = 18.0 * mul
		"ptrack":
			# Short wave segments: fired in a stream they read as one snaking
			# laser rather than as a line of separate shots.
			#
			# Kept deliberately stubby. Each segment is a straight stick that
			# rotates to face its heading, so a long one turning through a
			# homing curve reads as a kink rather than a bend - the beam looked
			# like a run of angled sticks instead of a rope. Short segments at a
			# high fire rate keep the same coverage and curve smoothly.
			b.frames = Art.apply_sheet(b, "wavebeam", true)
			b.scale = Vector2(0.11, 0.26) * mul
			b.radius = 12.0 * mul
		"plock":
			# Lean and long rather than fat: these cross the screen at close to
			# 2500px/s, so they need to read as darts, not as drifting rockets.
			b.frames = Art.apply_sheet(b, "missile", true)
			b.scale = Vector2(0.20, 0.38) * mul
			b.radius = 17.0 * mul
		_:
			b.frames = Art.apply_sheet(b, "enemyshot", true)
			b.scale = Vector2.ONE * 0.19 * mul
			b.radius = 10.4 * mul
	b.anim_fps = 14.0


func _process(dt: float) -> void:
	if is_instance_valid(player):
		_target = player.position
	if team == TEAM_ENEMY:
		_update_enemy_team(dt)
	else:
		_update_player_team(dt)


## These loops emit signals, and a handler can reach straight back into this
## manager and mutate `_live` - a player_hit that ends the run clears every
## bullet, a scatter split spawns more. Re-clamping the cursor each iteration
## keeps the walk valid however the array was rewritten underneath it.
func _clamp_cursor(i: int) -> int:
	return mini(i, _live.size() - 1)


func _update_enemy_team(dt: float) -> void:
	var can_hit: bool = is_instance_valid(player) and player.is_vulnerable()
	var hit_r: float = Cfg.PLAYER_HITBOX
	var graze_r: float = Cfg.GRAZE_RADIUS
	var ppos := _target

	var i := _live.size() - 1
	while i >= 0:
		i = _clamp_cursor(i)
		if i < 0:
			break
		var b: Bullet = _live[i]
		var keep := b.step(dt, ppos)
		if keep and b.split_after > 0.0 and b.age >= b.split_after:
			# Retire the carrier and emit its payload from where it burst.
			var spec := b.split_spec
			var at := b.position
			_retire(i, b)
			Patterns.emit(self, spec, at, 0, ppos)
			i -= 1
			continue
		if keep and is_instance_valid(player) and b.delay <= 0.0:
			var d2 := b.position.distance_squared_to(ppos)
			var rr := hit_r + b.radius
			if can_hit and d2 < rr * rr:
				player_hit.emit(b)
				keep = false
			elif not b.grazed and d2 < (graze_r + b.radius) * (graze_r + b.radius):
				b.grazed = true
				player_grazed.emit(b)
		if not keep:
			_retire(i, b)
		i -= 1


func _update_player_team(dt: float) -> void:
	var i := _live.size() - 1
	while i >= 0:
		i = _clamp_cursor(i)
		if i < 0:
			break
		var b: Bullet = _live[i]
		var keep := b.step(dt, _seek_target(b))
		if keep:
			# Reverse index: enemy_hit can kill the target, which erases it
			# from `enemies` while we are still walking the array.
			var j := enemies.size() - 1
			while j >= 0:
				var e = enemies[j]
				j -= 1
				if not e.alive or not e.hittable:
					continue
				var rr: float = e.hit_radius + b.radius
				if b.position.distance_squared_to(e.position) < rr * rr:
					if b.hits.has(e):
						continue
					enemy_hit.emit(e, b)
					if b.pierce > 0:
						b.pierce -= 1
						b.hits.append(e)
					else:
						keep = false
					break
		if not keep:
			_retire(i, b)
		i -= 1


## What this bullet should steer at: its own locked target while that target is
## still alive, otherwise whatever is nearest. A missile whose target dies keeps
## flying and re-acquires rather than sailing off the top of the screen.
func _seek_target(b: Bullet) -> Vector2:
	if b.seek != null:
		if is_instance_valid(b.seek) and b.seek.alive and b.seek.hittable:
			return b.seek.position
		b.seek = null
	return _nearest_enemy(b.position)


func _nearest_enemy(from: Vector2) -> Vector2:
	var best := from + Vector2(0, -600)
	var best_d := INF
	for e in enemies:
		if not e.alive or not e.hittable:
			continue
		var d: float = from.distance_squared_to(e.position)
		if d < best_d:
			best_d = d
			best = e.position
	return best


func _retire(index: int, b: Bullet) -> void:
	b.kill()
	_live.remove_at(index)
	_free.append(b)


## Wipes the field. Used by bombs and stage transitions; when `convert` is set,
## each cleared bullet reports its position so it can become a score pickup.
func clear_all(convert: bool = false) -> int:
	var n := _live.size()
	for b in _live:
		if convert and not b.scored:
			bullet_cleared.emit(b.position)
		b.kill()
		_free.append(b)
	_live.clear()
	return n


## Clears bullets within `radius` of `centre` (bomb blast expanding outward).
func clear_radius(centre: Vector2, radius: float, convert: bool = true) -> void:
	var r2 := radius * radius
	var i := _live.size() - 1
	while i >= 0:
		i = _clamp_cursor(i)
		if i < 0:
			break
		var b: Bullet = _live[i]
		if b.position.distance_squared_to(centre) < r2:
			if convert and not b.scored:
				bullet_cleared.emit(b.position)
			_retire(i, b)
		i -= 1
