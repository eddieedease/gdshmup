class_name Director
extends RefCounted
## Runs a stage script.
##
## Level scripts are coroutines that read like a shooting-game storyboard:
##
##     await d.wait(2.0)
##     await d.row("SCOUT", 6, 0.12)
##     await d.wait_clear()
##     await d.boss(BossDefs.get_boss(0))
##
## All spawning funnels through here so difficulty scaling, cancellation and
## bookkeeping live in one place.
##
## This is a RefCounted rather than a Node on purpose: a suspended coroutine
## keeps a reference alive, so a stage script that is mid-`await` when the run
## ends still has a valid `self` to resume into. It simply sees `stopped` and
## returns instead of touching a freed scene.

signal wants_banner(title: String, subtitle: String, duration: float)
signal wants_warning()
signal boss_spawned(boss: Boss)
signal boss_cleared()

var game: Node = null            ## The game scene; provides add_enemy().
var difficulty: Dictionary = {"hp": 1.0, "fire_rate": 1.0, "speed": 1.0}
var stopped := false


func stop() -> void:
	stopped = true


func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


# --- Timing ------------------------------------------------------------------

func wait(seconds: float) -> void:
	if stopped or seconds <= 0.0:
		return
	# process_always = false so the stage script freezes with the pause menu.
	await _tree().create_timer(seconds, false).timeout


## Blocks until every spawned enemy is gone (or `timeout` elapses).
func wait_clear(timeout: float = 26.0) -> void:
	var elapsed := 0.0
	while not stopped and elapsed < timeout:
		if game.enemies.is_empty():
			return
		await _tree().create_timer(0.15, false).timeout
		elapsed += 0.15


## Blocks until fewer than `n` enemies remain.
func wait_until_under(n: int, timeout: float = 20.0) -> void:
	var elapsed := 0.0
	while not stopped and elapsed < timeout:
		if game.enemies.size() < n:
			return
		await _tree().create_timer(0.15, false).timeout
		elapsed += 0.15


# --- Spawning ----------------------------------------------------------------

func spawn(spec: Dictionary, at: Vector2) -> Enemy:
	if stopped or game == null:
		return null
	var e := Enemy.new()
	e.setup(spec, at, difficulty)
	game.add_enemy(e)
	return e


## `type_name` may be an EnemyDefs key or a full spec dictionary.
func _resolve(type_name: Variant, overrides: Dictionary) -> Dictionary:
	if type_name is Dictionary:
		if overrides.is_empty():
			return type_name
		var d: Dictionary = type_name.duplicate(true)
		for k in overrides:
			d[k] = overrides[k]
		return d
	return EnemyDefs.make(String(type_name), overrides)


func one(type_name: Variant, at: Vector2, overrides: Dictionary = {}) -> Enemy:
	return spawn(_resolve(type_name, overrides), at)


## A horizontal rank sweeping in from the top, one enemy every `gap` seconds.
func row(type_name: Variant, count: int, gap: float = 0.14,
		x0: float = 90.0, x1: float = Cfg.FIELD_W - 90.0,
		overrides: Dictionary = {}) -> void:
	var spec := _resolve(type_name, overrides)
	for i in count:
		if stopped:
			return
		var t := 0.0 if count == 1 else float(i) / float(count - 1)
		spawn(spec, Vector2(lerpf(x0, x1, t), Cfg.SPAWN_Y))
		if gap > 0.0:
			await wait(gap)


## A V formation, point first.
func vee(type_name: Variant, per_wing: int, x: float = Cfg.FIELD_W * 0.5,
		spacing: float = 74.0, depth: float = 52.0,
		overrides: Dictionary = {}) -> void:
	var spec := _resolve(type_name, overrides)
	spawn(spec, Vector2(x, Cfg.SPAWN_Y))
	for i in range(1, per_wing + 1):
		if stopped:
			return
		var dx := spacing * i
		var dy := -depth * i
		spawn(spec, Vector2(x - dx, Cfg.SPAWN_Y + dy))
		spawn(spec, Vector2(x + dx, Cfg.SPAWN_Y + dy))
		await wait(0.09)


## A single-file column pouring in from one column of the screen.
func column(type_name: Variant, count: int, x: float, gap: float = 0.30,
		overrides: Dictionary = {}) -> void:
	var spec := _resolve(type_name, overrides)
	for i in count:
		if stopped:
			return
		spawn(spec, Vector2(x, Cfg.SPAWN_Y))
		await wait(gap)


## Two mirrored streams that cross in the middle of the screen.
func crossfire(type_name: Variant, count: int, gap: float = 0.35,
		speed: float = 300.0, y: float = 120.0,
		overrides: Dictionary = {}) -> void:
	for i in count:
		if stopped:
			return
		var l := _resolve(type_name, overrides)
		l["move"] = {"type": "line", "dir": 34.0, "speed": speed}
		l["face"] = "vel"
		spawn(l, Vector2(-60.0, y + i * 26.0))
		var r := _resolve(type_name, overrides)
		r["move"] = {"type": "line", "dir": 146.0, "speed": speed}
		r["face"] = "vel"
		spawn(r, Vector2(Cfg.FIELD_W + 60.0, y + i * 26.0))
		await wait(gap)


## Enemies that slalom down the screen following a zig-zag path.
func snake(type_name: Variant, count: int, gap: float = 0.18,
		from_left: bool = true, overrides: Dictionary = {}) -> void:
	var w := Cfg.FIELD_W
	var pts: Array = [
		Vector2(w * (0.82 if from_left else 0.18), 200.0),
		Vector2(w * (0.18 if from_left else 0.82), 380.0),
		Vector2(w * (0.72 if from_left else 0.28), 560.0),
		Vector2(w * (0.28 if from_left else 0.72), 720.0),
	]
	var o := overrides.duplicate()
	o["move"] = {
		"type": "path", "seg_time": 0.72, "points": pts,
		"exit_dir": 90.0, "exit_speed": 340.0,
	}
	o["face"] = "vel"
	var spec := _resolve(type_name, o)
	var x := w * (0.15 if from_left else 0.85)
	for i in count:
		if stopped:
			return
		spawn(spec, Vector2(x, Cfg.SPAWN_Y))
		await wait(gap)


## A ring of enemies that sweeps in an arc across the top of the field.
func carousel(type_name: Variant, count: int, radius: float = 230.0,
		omega: float = 0.9, overrides: Dictionary = {}) -> void:
	var centre := Vector2(Cfg.FIELD_W * 0.5, 250.0)
	for i in count:
		if stopped:
			return
		var o := overrides.duplicate()
		o["move"] = {
			"type": "arc", "centre": centre, "radius": radius,
			"omega": omega, "phase": 360.0 * float(i) / float(count),
		}
		spawn(_resolve(type_name, o), centre)


# --- Presentation ------------------------------------------------------------

func banner(title: String, subtitle: String = "", duration: float = 2.6) -> void:
	if stopped:
		return
	wants_banner.emit(title, subtitle, duration)


func warning() -> void:
	if stopped:
		return
	wants_warning.emit()


## Spawns the stage boss and blocks until it dies.
func boss(def: Dictionary) -> void:
	if stopped or game == null:
		return
	warning()
	await wait(2.6)
	if stopped:
		return
	var b := Boss.new()
	b.setup_boss(def, difficulty)
	game.add_enemy(b)
	boss_spawned.emit(b)

	var done := [false]
	b.defeated.connect(func(_x): done[0] = true)
	while not stopped and not done[0] and is_instance_valid(b):
		await _tree().create_timer(0.1, false).timeout
	boss_cleared.emit()
