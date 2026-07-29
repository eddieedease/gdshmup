class_name Game
extends Node2D
## The playing scene: builds the field, runs the three stages, keeps the score.
##
## Everything gameplay-related lives under `_field`, a Node2D shifted to the
## left edge of the 810px playfield so all gameplay code can work in a clean
## 0..810 x 0..1080 coordinate space regardless of the real window size.

signal finished(cleared: bool)

const CHAIN_MULT_CAP := 6.0
const GRAZE_SCORE := 60
const CLEARED_BULLET_SCORE := 120
const STAR_DROP_CHANCE := 0.06

var enemies: Array = []
var items: Array[Item] = []

var score := 0
var graze := 0
var chain := 0
var chain_time := 0.0
var stage := 0
var over := false
var cleared := false
var lives_left := 2

var _field: Node2D
var _terrain: Terrain
var _fx: FxLayer
var _ebm: BulletManager
var _pbm: BulletManager
var _player: Player
var _hud: Hud
var _director: Director
var _options_root: Node2D
var _shake := 0.0
var _next_extend := 0
var _field_base := Vector2.ZERO
var _paused := false
var _shutting_down := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()
	_start_run()


func _build() -> void:
	_field = Node2D.new()
	add_child(_field)

	_terrain = Terrain.new()
	_field.add_child(_terrain)

	# A dim vignette so bullets and ships read clearly over the ground.
	var wash := ColorRect.new()
	wash.color = Color(0.02, 0.03, 0.07, 0.42)
	wash.size = Vector2(Cfg.FIELD_W, Cfg.FIELD_H)
	wash.z_index = Cfg.Z_DECOR
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(wash)

	_fx = FxLayer.new()
	_field.add_child(_fx)

	_pbm = BulletManager.new()
	_pbm.z_index = Cfg.Z_PBULLET
	_field.add_child(_pbm)
	_pbm.setup(BulletManager.TEAM_PLAYER, Cfg.MAX_PLAYER_BULLETS)
	_pbm.enemies = enemies

	_ebm = BulletManager.new()
	_ebm.z_index = Cfg.Z_EBULLET
	_field.add_child(_ebm)
	_ebm.setup(BulletManager.TEAM_ENEMY, Cfg.MAX_ENEMY_BULLETS)

	_options_root = Node2D.new()
	_field.add_child(_options_root)

	_player = Player.new()
	_player.setup(GS.ship_index)
	_player.bullets = _pbm
	_player.fx = _fx
	_player.enemies = enemies
	_field.add_child(_player)
	_player.spawn_options(_options_root)

	_ebm.player = _player
	_pbm.player = _player

	_hud = Hud.new()
	_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_hud)
	_hud.set_ship(_player.ship)

	# Not a child: Director is a RefCounted so suspended stage coroutines stay
	# valid even after this scene is torn down.
	_director = Director.new()
	_director.game = self

	var watcher := PauseWatcher.new()
	watcher.game = self
	watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(watcher)

	# Signal wiring.
	_ebm.player_hit.connect(_on_player_hit)
	_ebm.player_grazed.connect(_on_graze)
	_ebm.bullet_cleared.connect(_on_bullet_cleared)
	_pbm.enemy_hit.connect(_on_enemy_hit)
	_player.beam_tick.connect(_on_beam_tick)
	_player.life_lost.connect(_on_life_lost)
	_player.bomb_fired.connect(_on_bomb)
	_director.wants_banner.connect(func(t, s, d): _hud.banner(t, s, d))
	_director.wants_warning.connect(func():
		_hud.warning()
		AU.play("warning"))
	_director.boss_spawned.connect(func(b): _hud.set_boss(b))
	_director.boss_cleared.connect(func(): _hud.set_boss(null))

	get_viewport().size_changed.connect(_layout)
	_layout()
	_next_extend = 0


func _layout() -> void:
	_field_base = Vector2(Cfg.field_x(get_viewport().get_visible_rect().size), 0.0)
	_field.position = _field_base


# --- Run flow ----------------------------------------------------------------

func _start_run() -> void:
	stage = GS.start_level
	await _run_stages()
	# Every stage coroutine has unwound, so nothing can resume into a dangling
	# reference. Only now is it safe to disappear.
	if _shutting_down:
		queue_free()


## Called by Main when this run is being replaced. The scene stops and hides
## immediately but frees itself once _start_run() finishes unwinding.
func shutdown() -> void:
	_shutting_down = true
	over = true
	_director.stop()
	if _paused:
		_paused = false
		get_tree().paused = false
	_field.visible = false
	_hud.visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _run_stages() -> void:
	while stage < LevelDefs.count() and not over:
		var meta := LevelDefs.meta(stage)
		_terrain.set_stage(int(meta.terrain), 1000 + stage * 977)
		AU.play_music("level%d" % (stage + 1))
		_director.difficulty = meta.difficulty
		_hud.set_stage(stage, LevelDefs.count(), String(meta.name))

		if GS.boss_rush:
			await _director.boss(BossDefs.get_boss(stage))
		else:
			var script: RefCounted = LevelDefs.script_for(stage)
			await script.run(_director)
		if over:
			return

		await _stage_clear()
		stage += 1

	if not over:
		_all_clear()


func _stage_clear() -> void:
	_ebm.clear_all(false)
	var bonus := 50_000 * (stage + 1) + lives_left * 100_000 + _player.bombs * 40_000
	_add_score(bonus)
	_hud.banner("STAGE CLEAR", "BONUS  %s" % Cfg.fmt_score(bonus), 3.4)
	AU.play("stage_clear")
	await get_tree().create_timer(4.0, false).timeout


func _all_clear() -> void:
	cleared = true
	over = true
	_director.stop()
	_ebm.clear_all(false)
	GS.submit_score(score)
	AU.stop_music(1.5)
	AU.play("stage_clear")
	_hud.set_message("ALL CLEAR", "FINAL SCORE  %s" % Cfg.fmt_score(score))
	await get_tree().create_timer(1.0, false).timeout
	_finish()


func _game_over() -> void:
	if over:
		return
	over = true
	_director.stop()
	GS.submit_score(score)
	AU.stop_music(1.2)
	_hud.set_message("GAME OVER", "PRESS START TO RETURN")
	await get_tree().create_timer(1.0, false).timeout
	_finish()


func _finish() -> void:
	# Wait for a fresh press so the death input does not skip the screen.
	while not Input.is_action_just_pressed("p_start") \
			and not Input.is_action_just_pressed("p_back"):
		await get_tree().process_frame
	GS.last_run_score = score
	GS.last_run_stage = stage
	GS.last_run_cleared = cleared
	finished.emit(cleared)


# --- Spawning ----------------------------------------------------------------

func add_enemy(e: Enemy) -> void:
	e.bullets = _ebm
	e.fx = _fx
	e.player = _player
	e.died.connect(_on_enemy_died)
	enemies.append(e)
	_field.add_child(e)


func _spawn_item(kind: int, at: Vector2, launch: Vector2 = Vector2.ZERO) -> void:
	if items.size() > 120:
		return
	var it := Item.new()
	it.setup(kind, at, launch)
	items.append(it)
	_field.add_child(it)


# --- Gameplay events ---------------------------------------------------------

func _on_enemy_hit(enemy: Node2D, bullet: Bullet) -> void:
	_fx.spark(bullet.position, Color(1, 0.95, 0.8), 0.12)
	AU.play("hit", 0.1)
	enemy.take_damage(float(bullet.damage), bullet.position)
	_touch_chain()


func _on_beam_tick(enemy: Node2D, damage: float, at: Vector2) -> void:
	enemy.take_damage(damage, at)
	_touch_chain()


func _on_enemy_died(e: Enemy) -> void:
	enemies.erase(e)
	chain += 1
	chain_time = Cfg.CHAIN_TIMEOUT
	var gained := int(round(e.score * _chain_multiplier()))
	_add_score(gained)
	if e.score >= 500:
		_fx.popup(e.position, Cfg.fmt_score(gained), Cfg.UI_GOLD, 24)
	_shake = maxf(_shake, clampf(e.score / 3000.0, 0.6, 9.0))
	_drop_for(e)


func _drop_for(e: Enemy) -> void:
	var kind := String(e.spec.get("drop", "star"))
	var p: Vector2 = e.position
	match kind:
		"power":
			_spawn_item(Item.Kind.POWER, p, Vector2(randf_range(-70, 70), -150))
			_spawn_item(Item.Kind.STAR, p, Vector2(randf_range(-120, 120), -110))
		"bomb":
			_spawn_item(Item.Kind.BOMB, p, Vector2(randf_range(-60, 60), -160))
			for i in 3:
				_spawn_item(Item.Kind.STAR, p,
					Vector2(randf_range(-160, 160), randf_range(-170, -60)))
		"star":
			_spawn_item(Item.Kind.STAR, p,
				Vector2(randf_range(-100, 100), randf_range(-150, -60)))
		_:
			pass

	if e is Boss:
		for i in 12:
			_spawn_item(Item.Kind.BIG_STAR, p,
				Vector2(randf_range(-260, 260), randf_range(-260, -60)))
		_spawn_item(Item.Kind.POWER, p, Vector2(-90, -180))
		_spawn_item(Item.Kind.POWER, p, Vector2(90, -180))
		_spawn_item(Item.Kind.BOMB, p, Vector2(0, -210))
		_hud.flash(0.8)
		_shake = 16.0


func _on_player_hit(_b: Bullet) -> void:
	_player.hit()


func _on_graze(_b: Bullet) -> void:
	graze += 1
	_add_score(GRAZE_SCORE)
	AU.play("graze", 0.1)


func _on_bullet_cleared(pos: Vector2) -> void:
	_add_score(CLEARED_BULLET_SCORE)
	if randf() < STAR_DROP_CHANCE:
		_spawn_item(Item.Kind.STAR, pos, Vector2(randf_range(-60, 60), -60))


func _on_bomb() -> void:
	_hud.flash(0.7)
	_shake = 14.0


func _on_life_lost() -> void:
	chain = 0
	chain_time = 0.0
	_shake = 18.0
	_hud.flash(0.35)
	lives_left -= 1
	if lives_left < 0:
		_player.set_process(false)
		_player.visible = false
		_game_over()


# --- Score / chain -----------------------------------------------------------

func _chain_multiplier() -> float:
	return clampf(1.0 + float(chain) * 0.02, 1.0, CHAIN_MULT_CAP)


func _touch_chain() -> void:
	chain_time = Cfg.CHAIN_TIMEOUT


func _add_score(n: int) -> void:
	score += n
	while _next_extend < Cfg.EXTEND_SCORES.size() \
			and score >= Cfg.EXTEND_SCORES[_next_extend]:
		_next_extend += 1
		lives_left += 1
		AU.play("extend")
		_hud.banner("EXTEND", "1UP", 1.8)
		_fx.popup(_player.position + Vector2(0, -60), "1UP", Color(0.5, 1, 0.6), 34)


# --- Frame -------------------------------------------------------------------

func _process(dt: float) -> void:
	_prune_enemies()
	_check_collisions()
	_update_items(dt)

	if chain_time > 0.0:
		chain_time -= dt
		if chain_time <= 0.0:
			chain = 0

	if _shake > 0.05:
		_shake = maxf(0.0, _shake - dt * 34.0)
		_field.position = _field_base + Vector2(
			randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		_field.position = _field_base

	_hud.set_scores(score, maxi(GS.hi_score, score))
	_hud.set_chain(chain, clampf(chain_time / Cfg.CHAIN_TIMEOUT, 0.0, 1.0),
		_chain_multiplier())
	_hud.set_status(_player.power, maxi(lives_left, 0), _player.bombs, graze,
		_ebm.live_count())


## Ramming an enemy hull is fatal. The hull box is deliberately smaller than the
## sprite so near-misses stay near-misses.
func _check_collisions() -> void:
	if not _player.is_vulnerable():
		return
	var p: Vector2 = _player.position
	for e in enemies:
		if not e.alive or not e.hittable:
			continue
		var r: float = e.hit_radius * 0.62 + Cfg.PLAYER_HITBOX
		if p.distance_squared_to(e.position) < r * r:
			_player.hit()
			return


func _prune_enemies() -> void:
	var i := enemies.size() - 1
	while i >= 0:
		var e = enemies[i]
		if not is_instance_valid(e) or not e.alive:
			if not (is_instance_valid(e) and e is Boss and e.dying):
				enemies.remove_at(i)
		i -= 1


func _update_items(dt: float) -> void:
	var magnet_all: bool = _player.bomb_active() \
		or _player.position.y < Player.AUTO_COLLECT_Y
	var i := items.size() - 1
	while i >= 0:
		var it := items[i]
		if not is_instance_valid(it):
			items.remove_at(i)
			i -= 1
			continue
		it.step(dt, _player.position, magnet_all)
		if not it.alive:
			_collect(it)
			items.remove_at(i)
			it.queue_free()
		i -= 1


func _collect(it: Item) -> void:
	# Items that fall off the bottom are simply lost.
	if it.position.y > Cfg.FIELD_H + 40.0:
		return
	match it.kind:
		Item.Kind.POWER:
			AU.play("powerup")
			if _player.add_power(1):
				_fx.popup(it.position, "POWER UP", Color(1, 0.6, 0.35), 22)
			else:
				_add_score(10_000)
				_fx.popup(it.position, "10,000", Cfg.UI_GOLD, 20)
		Item.Kind.BOMB:
			AU.play("powerup", 0.05)
			if _player.bombs < 8:
				_player.bombs += 1
				_fx.popup(it.position, "BOMB", Color(0.5, 0.8, 1.0), 22)
			else:
				_add_score(20_000)
		Item.Kind.EXTEND:
			lives_left += 1
			_fx.popup(it.position, "1UP", Color(0.5, 1, 0.6), 26)
		_:
			AU.play("item", 0.12)
			_add_score(int(it.value * _chain_multiplier()))


# --- Pause -------------------------------------------------------------------

func toggle_pause() -> void:
	if over:
		return
	_paused = not _paused
	get_tree().paused = _paused
	if _paused:
		AU.set_laser(false)
		_hud.set_message("PAUSED", "ESC TO RESUME")
	else:
		_hud.set_message("")


func quit_to_title() -> void:
	if _paused:
		_paused = false
		get_tree().paused = false
	over = true
	_director.stop()
	GS.submit_score(score)
	GS.last_run_score = score
	GS.last_run_stage = stage
	GS.last_run_cleared = false
	finished.emit(false)


## Runs outside the pause tree so ESC still reaches the game while frozen.
class PauseWatcher:
	extends Node
	var game: Game
	var _held := 0.0

	func _process(dt: float) -> void:
		if game == null or game.over:
			return
		if Input.is_action_just_pressed("p_pause"):
			game.toggle_pause()
		# Holding ESC while paused abandons the run.
		if game._paused and Input.is_action_pressed("p_back"):
			_held += dt
			if _held > 1.0:
				game.quit_to_title()
		else:
			_held = 0.0
