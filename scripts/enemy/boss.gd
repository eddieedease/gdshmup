class_name Boss
extends Enemy
## A multi-phase stage boss.
##
## A boss is an Enemy whose movement and attack list are swapped out each time
## its health bar empties. Re-initialising the inherited `age`, `_move` and
## `_attacks` is enough to restart the base behaviour for the new phase, so all
## the pattern machinery is reused unchanged.

signal phase_changed(index: int)
signal death_started
signal defeated(boss: Boss)

const INTRO_TIME := 2.4
const DEATH_TIME := 2.6

var boss_name := "UNKNOWN"
var phases: Array = []
var phase := -1
var dying := false

var _phase_hp: PackedFloat32Array = PackedFloat32Array()
var _total_hp := 0.0
var _intro := true
var _intro_t := 0.0
var _death_t := 0.0
var _guard := 0.0   ## Brief invulnerability while a phase transition plays.
var _spark_cd := 0.0


## `difficulty` is accepted for symmetry with Enemy but deliberately ignored.
## Those multipliers exist to scale the reusable enemy archetypes across stages;
## a boss has hand-authored health and patterns per stage, so compounding the
## two made stage 3 a 109,000 HP wall - four minutes of holding the trigger.
func setup_boss(def: Dictionary, _difficulty: Dictionary = {}) -> void:
	boss_name = String(def.get("name", "BOSS"))
	phases = def.get("phases", [])

	_phase_hp.resize(phases.size())
	_total_hp = 0.0
	for i in phases.size():
		var h := float(phases[i].get("hp", 500))
		_phase_hp[i] = h
		_total_hp += h

	var base := {
		"tex": int(def.get("tex", 7)),
		"hp": _phase_hp[0] if phases.size() > 0 else 1000.0,
		"scale": float(def.get("scale", 0.95)),
		"radius": float(def.get("radius", 78.0)),
		"score": int(def.get("score", 100000)),
		"face": "down",
		"cull_grace": 99999.0,
		"no_reveal": true,
		"z": Cfg.Z_ENEMY + 1,
		"move": {"type": "approach", "to": def.get("anchor",
			Vector2(Cfg.FIELD_W * 0.5, 260.0)), "time": INTRO_TIME},
		"attacks": [],
		"drop_extend": bool(def.get("drop_extend", false)),
	}
	if def.has("tint"):
		base["tint"] = def.tint

	setup(base, def.get("spawn_at", Vector2(Cfg.FIELD_W * 0.5, -220.0)),
		{"hp": 1.0, "fire_rate": 1.0, "speed": 1.0})
	hittable = false
	_intro = true
	_intro_t = 0.0


func hp_fraction() -> float:
	if _total_hp <= 0.0:
		return 0.0
	var remaining := maxf(hp, 0.0)
	for i in range(phase + 1, _phase_hp.size()):
		remaining += _phase_hp[i]
	return clampf(remaining / _total_hp, 0.0, 1.0)


func phase_fraction() -> float:
	return clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)


func _process(dt: float) -> void:
	if dying:
		_run_death(dt)
		return
	if _intro:
		_intro_t += dt
		super._process(dt)
		if _intro_t >= INTRO_TIME:
			_intro = false
			hittable = true
			_enter_phase(0)
		return
	if _spark_cd > 0.0:
		_spark_cd -= dt
	if _guard > 0.0:
		_guard -= dt
		hittable = _guard <= 0.0
	super._process(dt)


func _enter_phase(i: int) -> void:
	phase = i
	var p: Dictionary = phases[i]
	max_hp = _phase_hp[i]
	hp = max_hp
	age = 0.0
	_start = position

	_move = p.get("move", {
		"type": "sway", "centre": Vector2(Cfg.FIELD_W * 0.5, 250.0),
		"amp_x": 210.0, "amp_y": 45.0,
	}).duplicate()
	_init_move()

	_attacks = []
	for a in p.get("attacks", []):
		var rt: Dictionary = a.duplicate()
		rt["_t"] = 0.0
		rt["_idx"] = 0
		rt["_next"] = float(a.get("start", 0.6))
		_attacks.append(rt)

	phase_changed.emit(i)


func take_damage(amount: float, at: Vector2 = Vector2.ZERO) -> void:
	if dying or _intro or not hittable:
		return
	hp -= amount
	if _flash <= FLASH_TIME * FLASH_REARM:
		_flash = FLASH_TIME
		if at != Vector2.ZERO:
			# Half throw: a hull this size should barely budge.
			_flinch = (position - at).normalized() * FLINCH_DIST * 0.5
	# A hull this big needs impact sparks, not just a tint change.
	if _spark_cd <= 0.0:
		_spark_cd = 0.05
		fx.spark(at if at != Vector2.ZERO else position,
			Color(1, 0.92, 0.7), 0.20)
	damaged.emit(self, amount)
	if hp <= 0.0:
		if phase + 1 < phases.size():
			_advance_phase()
		else:
			_begin_death()


func _advance_phase() -> void:
	hittable = false
	_guard = 1.0
	_attacks.clear()
	bullets.clear_all(true)
	for i in 7:
		fx.explode(position + Vector2(randf_range(-90, 90), randf_range(-60, 60)),
			1.5, Color(1, 0.8, 0.4))
	fx.shockwave(position, 340.0, Color(1, 0.9, 0.6), 0.7, 12.0)
	AU.play("boss_phase")
	_enter_phase(phase + 1)


func _begin_death() -> void:
	death_started.emit()
	dying = true
	alive = false
	hittable = false
	_attacks.clear()
	_death_t = 0.0
	bullets.clear_all(true)


func _run_death(dt: float) -> void:
	_death_t += dt
	position.y += 22.0 * dt
	if randf() < dt * 16.0:
		fx.explode(position + Vector2(randf_range(-130, 130), randf_range(-95, 95)),
			randf_range(1.2, 2.4), Color(1, 0.72, 0.35))
		AU.play("boom", 0.2)
	if _death_t >= DEATH_TIME:
		fx.explode(position, 4.5, Color(1, 0.95, 0.75))
		fx.shockwave(position, 900.0, Color.WHITE, 1.1, 16.0)
		AU.play("boom_big")
		defeated.emit(self)
		died.emit(self)
		queue_free()
