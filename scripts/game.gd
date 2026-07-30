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
## Hyper absorb feedback.
const ABSORB_COL := Color(1.0, 0.55, 0.95)
const ABSORB_POPUP_EVERY := 6
## Every N chained kills gets a callout, so the combo system is visible in the
## field rather than only as a sidebar number.
const CHAIN_MILESTONE := 25

var enemies: Array = []
var items: Array[Item] = []

var score := 0
var graze := 0
var chain := 0
var chain_time := 0.0
var stage := 0
## Endless only: how many times the stage list has been completed.
var loop := 0
## Endless only: best score reached on any single credit this run. Continues
## wipe `score`, so this is what the leaderboard actually cares about.
var best_score := 0
var over := false
var cleared := false
var lives_left := 2

var _field: Node2D
var _terrain: Terrain
var _dust: SpeedDust
var _dust_near: SpeedDust
var _tunnel: Tunnel
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
var _absorbed := 0
## Guards overlapping dilations: only the most recent one restores the clock.
var _dilate_token := 0
var _pause_menu: PauseMenu
var _boss: Boss = null


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

	_dust = SpeedDust.new()
	_field.add_child(_dust)
	_dust_near = SpeedDust.new()
	_dust_near.foreground = true
	_field.add_child(_dust_near)

	_tunnel = Tunnel.new()
	_field.add_child(_tunnel)

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
	_player.enemy_bullets = _ebm
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

	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(func(): toggle_pause())
	_pause_menu.quit_requested.connect(quit_to_title)

	var watcher := PauseWatcher.new()
	watcher.game = self
	watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(watcher)

	# Signal wiring.
	_ebm.player_hit.connect(_on_player_hit)
	_ebm.player_grazed.connect(_on_graze)
	_ebm.bullet_cleared.connect(_on_bullet_cleared)
	_pbm.enemy_hit.connect(_on_enemy_hit)
	_player.damage_dealt.connect(_on_damage_dealt)
	_player.life_lost.connect(_on_life_lost)
	_player.bomb_fired.connect(_on_bomb)
	_player.hyper_ended.connect(func(): _absorbed = 0)
	_player.hyper_started.connect(func():
		_hud.flash(0.35)
		_shake = maxf(_shake, 8.0)
		_hud.banner("", "HYPER ENGAGED", 1.6))
	_director.wants_banner.connect(func(t, s, d): _hud.banner(t, s, d))
	_director.wants_warning.connect(func():
		_hud.warning()
		AU.play("warning"))
	_director.boss_spawned.connect(_on_boss_spawned)
	_director.boss_cleared.connect(_on_boss_cleared)

	get_viewport().size_changed.connect(_layout)
	_layout()
	_next_extend = 0


## Briefly slows the whole simulation. The restore timer ignores time_scale, so
## a heavy slowdown cannot stretch its own recovery.
func time_dilate(scale: float, duration: float) -> void:
	_dilate_token += 1
	var token := _dilate_token
	Engine.time_scale = scale
	await get_tree().create_timer(duration, false, false, true).timeout
	if token == _dilate_token:
		Engine.time_scale = 1.0


# --- Boss presentation -------------------------------------------------------

func _on_boss_spawned(b: Boss) -> void:
	_boss = b
	_hud.set_boss(b)
	b.phase_changed.connect(func(_i):
		_hud.flash(0.45)
		_shake = maxf(_shake, 12.0))
	# The kill is the moment of the stage; let it land.
	b.death_started.connect(func():
		time_dilate(0.32, 1.2)
		_hud.flash(0.6)
		_shake = maxf(_shake, 16.0))


func _on_boss_cleared() -> void:
	_boss = null
	_hud.set_boss(null)
	AU.set_drone(false)


## Ramps the alert dressing with the boss's remaining health, so the fight
## visibly and audibly tightens as it goes.
func _update_boss_mood() -> void:
	if not is_instance_valid(_boss) or _boss.dying:
		if _boss != null:
			AU.set_drone(false)
			_hud.set_alert(0.0)
			_boss = null
		return
	var pressure: float = 1.0 - _boss.hp_fraction()
	_hud.set_alert(0.35 + 0.65 * pressure)
	AU.set_drone(true, pressure)


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
	_dilate_token += 1
	Engine.time_scale = 1.0
	_tunnel.intensity = 0.0
	_shutting_down = true
	over = true
	_director.stop()
	if _paused:
		_paused = false
		get_tree().paused = false
	AU.set_drone(false)
	AU.set_laser(false)
	_field.visible = false
	_hud.visible = false
	_pause_menu.visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


## Endless multiplies every stage's difficulty again on each lap, so lap three
## of stage one is meaningfully harder than the first time you saw it.
func _loop_difficulty(base: Dictionary) -> Dictionary:
	if loop <= 0:
		return base
	var f := pow(1.35, loop)
	return {
		"hp": float(base.hp) * f,
		"fire_rate": float(base.fire_rate) * pow(1.12, loop),
		"speed": float(base.speed) * pow(1.06, loop),
	}


## Everything that changes when a stage begins. Called once up front, then
## again from inside the transition flash so the swap is never seen.
func _apply_stage(idx: int) -> void:
	var meta := LevelDefs.meta(idx)
	_terrain.set_stage(int(meta.terrain), 1000 + stage * 977)
	for d in [_dust, _dust_near]:
		d.speed = _terrain.speed * 1.7
		d.tint = _terrain.stage_tint().lightened(0.45)
	_tunnel.tint = _terrain.stage_tint().lightened(0.35)
	AU.play_music("level%d" % (idx + 1))
	_director.difficulty = _loop_difficulty(meta.difficulty)
	_hud.set_stage(idx, LevelDefs.count(), String(meta.name), loop)


func _run_stages() -> void:
	var endless: bool = GS.mode == GS.Mode.ENDLESS
	_apply_stage(stage % LevelDefs.count())
	while not over:
		var idx := stage % LevelDefs.count()

		if GS.boss_rush:
			await _director.boss(BossDefs.get_boss(idx))
		else:
			var script: RefCounted = LevelDefs.script_for(idx)
			await script.run(_director)
		if over:
			return

		await _stage_clear()
		stage += 1

		var wrapped := stage % LevelDefs.count() == 0
		if wrapped and not endless:
			break
		if wrapped:
			loop += 1
		if over:
			return
		await _transition(stage % LevelDefs.count(), wrapped)

	if not over:
		_all_clear()


## Flies through a tunnel into the next stage: accelerate, punch through on a
## flash (which is where the stage actually swaps), then decelerate out.
func _transition(idx: int, wrapped: bool) -> void:
	const IN := 1.3
	const OUT := 1.6

	var t := 0.0
	while t < IN and not over:
		var k: float = t / IN
		var e: float = k * k
		_tunnel.intensity = e
		_dust.warp = 1.0 + 8.0 * e
		_dust_near.warp = 1.0 + 8.0 * e
		_terrain.warp = 1.0 + 3.5 * e
		await get_tree().process_frame
		t += get_process_delta_time()
	if over:
		return

	# Punch-through: the swap happens under a full-screen flash.
	_hud.flash(0.85)
	_shake = maxf(_shake, 10.0)
	AU.play("boss_phase", 0.1)
	_apply_stage(idx)
	if wrapped:
		_hud.banner("LOOP %d" % (loop + 1), "THE PRESSURE RISES", 2.6)

	t = 0.0
	while t < OUT and not over:
		var k: float = 1.0 - (t / OUT)
		var e: float = k * k
		_tunnel.intensity = e
		_dust.warp = 1.0 + 8.0 * e
		_dust_near.warp = 1.0 + 8.0 * e
		_terrain.warp = 1.0 + 3.5 * e
		await get_tree().process_frame
		t += get_process_delta_time()

	_tunnel.intensity = 0.0
	_dust.warp = 1.0
	_dust_near.warp = 1.0
	_terrain.warp = 1.0


func _stage_clear() -> void:
	_ebm.clear_all(false)
	var bonus := 50_000 * (stage + 1) + lives_left * 100_000 + _player.bombs * 40_000
	_add_score(bonus)
	_hud.banner("STAGE CLEAR", "BONUS  %s" % Cfg.fmt_score(bonus), 2.8)
	AU.play("stage_clear")
	await get_tree().create_timer(3.0, false).timeout


func _all_clear() -> void:
	cleared = true
	over = true
	_director.stop()
	_ebm.clear_all(false)
	AU.stop_music(1.5)
	AU.play("stage_clear")
	_hud.set_message("ALL CLEAR", "FINAL SCORE  %s" % Cfg.fmt_score(score))
	await get_tree().create_timer(1.0, false).timeout
	_finish()


func _game_over() -> void:
	if over:
		return
	if GS.mode == GS.Mode.ENDLESS and await _offer_continue():
		return
	over = true
	_director.stop()
	AU.stop_music(1.2)
	AU.set_drone(false)
	_hud.set_message("GAME OVER", "PRESS START TO RETURN")
	await get_tree().create_timer(1.0, false).timeout
	_finish()


## Arcade-style continue: the run keeps its progress but the score goes back to
## zero, so continues buy depth rather than points.
func _offer_continue() -> bool:
	_ebm.clear_all(false)
	AU.set_drone(false)
	get_tree().paused = true

	var left := 10.0
	var taken := false
	while left > 0.0:
		_hud.set_message("CONTINUE?",
			"%d      PRESS START" % maxi(ceili(left), 0))
		if Input.is_action_just_pressed("p_start"):
			taken = true
			break
		if Input.is_action_just_pressed("p_back"):
			break
		await get_tree().process_frame
		left -= get_process_delta_time()

	get_tree().paused = false
	_hud.set_message("")
	if not taken:
		return false

	best_score = maxi(best_score, score)
	score = 0
	chain = 0
	chain_time = 0.0
	lives_left = 2
	_next_extend = 0
	_absorbed = 0
	_player.revive()
	AU.play("menu_select")
	_hud.banner("CONTINUE", "SCORE RESET", 2.4)
	return true


func _finish() -> void:
	_dilate_token += 1
	Engine.time_scale = 1.0
	# Wait for a fresh press so the death input does not skip the screen.
	while not Input.is_action_just_pressed("p_start") \
			and not Input.is_action_just_pressed("p_back"):
		await get_tree().process_frame
	GS.last_run_score = maxi(best_score, score)
	GS.last_run_stage = stage % LevelDefs.count()
	GS.last_run_cleared = cleared
	GS.last_run_ship = _player.ship_index
	GS.last_run_loop = loop
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


func _on_damage_dealt(enemy: Node2D, damage: float, at: Vector2) -> void:
	AU.play("hit", 0.1)
	enemy.take_damage(damage, at)
	_touch_chain()


func _on_enemy_died(e: Enemy) -> void:
	enemies.erase(e)
	chain += 1
	chain_time = Cfg.CHAIN_TIMEOUT
	_player.add_charge(Cfg.HYPER_CHARGE_KILL)
	if chain > 0 and chain % CHAIN_MILESTONE == 0:
		_chain_milestone(e.position)
	var gained := int(round(e.score * _chain_multiplier()))
	_add_score(gained)
	if e.score >= 500:
		_fx.popup(e.position, Cfg.fmt_score(gained), Cfg.UI_GOLD, 24)
	_shake = maxf(_shake, clampf(e.score / 3000.0, 0.6, 9.0))
	_spawn_on_death(e)
	# Visualise the charge this kill fed into the meter. Bigger targets send a
	# small burst, so the payout scales with what you killed.
	if not _player.is_hyper():
		var motes: int = 1 if e.score < 500 else (2 if e.score < 2000 else 4)
		for i in motes:
			_hud.charge_spark(e.position + _field.position)
	_drop_for(e)


## Some enemies leave escorts behind when they burst (see SPLITTER).
func _spawn_on_death(e: Enemy) -> void:
	var spec: Variant = e.spec.get("spawn_on_death", null)
	if not (spec is Dictionary) or over:
		return
	var count := int(spec.get("count", 2))
	var spread := float(spec.get("spread", 150.0))
	for i in count:
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var child := EnemyDefs.make(String(spec.get("type", "POPCORN")), {
			# Already on screen, so skip the reveal grace.
			"no_reveal": true,
			"move": {"type": "line", "dir": 90.0 + t * spread, "speed": 260.0},
		})
		var child_enemy := Enemy.new()
		child_enemy.setup(child, e.position, _director.difficulty)
		add_enemy(child_enemy)


## Celebrates a chain crossing a multiple of CHAIN_MILESTONE.
func _chain_milestone(at: Vector2) -> void:
	var tier: float = clampf(float(chain) / 150.0, 0.0, 1.0)
	var col := Cfg.UI_ACCENT.lerp(Cfg.UI_GOLD, tier)
	_fx.shockwave(at, 150.0 + 120.0 * tier, col, 0.6, 7.0)
	_fx.popup(at + Vector2(0, -46), "%d CHAIN" % chain, col, 30)
	_hud.flash(0.10 + 0.12 * tier)
	_shake = maxf(_shake, 5.0 + 5.0 * tier)
	AU.play("chain", 0.05)


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
		# Bosses flagged in BossDefs hand out a spare ship, so a competent run
		# is reliably up a life by the mid-game rather than waiting on score.
		if bool(e.spec.get("drop_extend", false)):
			_spawn_item(Item.Kind.EXTEND, p, Vector2(0, -240))
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
	_player.add_charge(Cfg.HYPER_CHARGE_GRAZE)
	AU.play("graze", 0.1)


func _on_bullet_cleared(pos: Vector2) -> void:
	if _player.is_hyper():
		# Absorbing has to *feel* like scoring, not like bullets vanishing:
		# a spark where it died, a mote flying to the meter, and a running
		# total called out every few so the numbers are legible.
		_add_score(Cfg.HYPER_ABSORB_SCORE)
		_absorbed += 1
		_fx.spark(pos, ABSORB_COL, 0.11)
		_hud.charge_spark(pos + _field.position, ABSORB_COL)
		if _absorbed % ABSORB_POPUP_EVERY == 0:
			_fx.popup(pos, "+%s" % Cfg.fmt_score(
				Cfg.HYPER_ABSORB_SCORE * ABSORB_POPUP_EVERY), ABSORB_COL, 22)
			_hud.flash(0.12)
		return

	_add_score(CLEARED_BULLET_SCORE)
	if randf() < STAR_DROP_CHANCE:
		_spawn_item(Item.Kind.STAR, pos, Vector2(randf_range(-60, 60), -60))


func _on_bomb() -> void:
	_hud.flash(0.7)
	_shake = 14.0


func _on_life_lost() -> void:
	# A short hitch so you can actually see what killed you.
	time_dilate(0.42, 0.45)
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
	best_score = maxi(best_score, score)
	while _next_extend < Cfg.EXTEND_SCORES.size() \
			and score >= Cfg.EXTEND_SCORES[_next_extend]:
		_next_extend += 1
		lives_left += 1
		AU.play("extend")
		_hud.banner("EXTEND", "1UP", 1.8)
		_fx.popup(_player.position + Vector2(0, -60), "1UP", Color(0.5, 1, 0.6), 34)


# --- Frame -------------------------------------------------------------------

func _process(dt: float) -> void:
	_update_boss_mood()
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
	_hud.set_hyper(_player.hyper_charge, _player.is_hyper())
	_hud.set_hyper_active(_player.is_hyper())
	_hud.set_power_progress(_player.chip_fraction())


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
			if _player.power >= Cfg.MAX_POWER:
				_add_score(10_000)
				_fx.popup(it.position, "10,000", Cfg.UI_GOLD, 20)
			elif _player.add_power(1):
				_fx.popup(it.position, "POWER UP", Color(1, 0.6, 0.35), 22)
			else:
				# Chip banked but no level yet - still show it landed.
				_fx.popup(it.position, "+1", Color(1, 0.6, 0.35), 18)
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
			_player.add_charge(Cfg.HYPER_CHARGE_ITEM)
			_add_score(int(it.value * _chain_multiplier()))


# --- Pause -------------------------------------------------------------------

func toggle_pause() -> void:
	if over:
		return
	_paused = not _paused
	get_tree().paused = _paused
	if _paused:
		AU.set_laser(false)
		AU.set_drone(false)
		_pause_menu.open()
	else:
		_pause_menu.close()


func quit_to_title() -> void:
	if _paused:
		_paused = false
		get_tree().paused = false
		_pause_menu.close()
	AU.set_drone(false)
	over = true
	_director.stop()
	GS.last_run_score = maxi(best_score, score)
	GS.last_run_stage = stage % LevelDefs.count()
	GS.last_run_cleared = false
	GS.last_run_ship = _player.ship_index
	GS.last_run_loop = loop
	finished.emit(false)


## Runs outside the pause tree so ESC still reaches the game while frozen.
## Only opens the menu; the menu handles its own navigation and closing.
class PauseWatcher:
	extends Node
	var game: Game

	func _process(_dt: float) -> void:
		if game == null or game.over or game._paused:
			return
		if Input.is_action_just_pressed("p_pause"):
			game.toggle_pause()
