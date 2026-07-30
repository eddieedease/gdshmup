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


func setup(which: int, capacity: int) -> void:
	team = which
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
			b.scale = Vector2.ONE * 0.108 * mul
			b.radius = 6.8 * mul
		"small":
			b.frames = Art.apply_sheet(b, "enemyshot", true)
			b.scale = Vector2.ONE * 0.158 * mul
			b.radius = 9.6 * mul
		"orb":
			b.frames = Art.apply_sheet(b, "plasma", true)
			b.scale = Vector2.ONE * 0.215 * mul
			b.radius = 13.4 * mul
		"bigorb":
			b.frames = Art.apply_sheet(b, "plasma", true)
			b.scale = Vector2.ONE * 0.30 * mul
			b.radius = 21.0 * mul
		"needle":
			b.frames = Art.apply_sheet(b, "laser", true)
			b.scale = Vector2(0.115, 0.26) * mul
			b.radius = 7.9 * mul
		"wave":
			b.frames = Art.apply_sheet(b, "wavebeam", true)
			b.scale = Vector2.ONE * 0.2 * mul
			b.radius = 11.2 * mul
		"missile":
			b.frames = Art.apply_sheet(b, "missile", true)
			b.scale = Vector2.ONE * 0.21 * mul
			b.radius = 11.2 * mul
		"bolt":
			b.frames = Art.apply_sheet(b, "bolt", true)
			b.scale = Vector2.ONE * 0.2 * mul
			b.radius = 10.1 * mul
		"pshot":
			b.frames = Art.apply_sheet(b, "bolt", true)
			b.scale = Vector2(0.19, 0.28) * mul
			b.radius = 14.0 * mul
		"pspread":
			b.frames = Art.apply_sheet(b, "spread", true)
			b.scale = Vector2.ONE * 0.21 * mul
			b.radius = 17.0 * mul
		"pmissile":
			b.frames = Art.apply_sheet(b, "missile", true)
			b.scale = Vector2.ONE * 0.24 * mul
			b.radius = 18.0 * mul
		_:
			b.frames = Art.apply_sheet(b, "enemyshot", true)
			b.scale = Vector2.ONE * 0.158 * mul
			b.radius = 9.6 * mul
	b.anim_fps = 14.0


func _process(dt: float) -> void:
	if is_instance_valid(player):
		_target = player.position
	if team == TEAM_ENEMY:
		_update_enemy_team(dt)
	else:
		_update_player_team(dt)


func _update_enemy_team(dt: float) -> void:
	var can_hit: bool = is_instance_valid(player) and player.is_vulnerable()
	var hit_r: float = Cfg.PLAYER_HITBOX
	var graze_r: float = Cfg.GRAZE_RADIUS
	var ppos := _target

	var i := _live.size() - 1
	while i >= 0:
		var b: Bullet = _live[i]
		var keep := b.step(dt, ppos)
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
		var b: Bullet = _live[i]
		var keep := b.step(dt, _nearest_enemy(b.position))
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
		var b: Bullet = _live[i]
		if b.position.distance_squared_to(centre) < r2:
			if convert and not b.scored:
				bullet_cleared.emit(b.position)
			_retire(i, b)
		i -= 1
