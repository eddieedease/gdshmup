class_name DemoDriver
extends Node
## Development aid: synthesises player input so the game can be watched (or
## screenshotted) without someone holding the keys. Enabled with `--demo`.
##
## Not part of the game loop - Main only creates this when the flag is present.

## When >= 0, taps pause once at this many seconds in (for capturing the menu).
var pause_after := -1.0
## When >= 0, fills the hyper meter once at this many seconds in.
var hyper_after := -1.0
## When >= 0, fires a stage transition once, for inspecting the tunnel.
var tunnel_after := -1.0
## When >= 0, swaps weapon mode once, as if a W item had been collected.
var weapon_after := -1.0
## When > 0, jumps the ship straight to this power level on the first frame,
## for looking at a weapon the way it fires late in a run.
var power_level := 0
## Fly at the nearest enemy instead of loitering along the bottom.
var hunt := false

var _t := 0.0
var _paused_once := false
var _hypered_once := false
var _tunnelled_once := false
var _swapped_once := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(dt: float) -> void:
	_t += dt
	var host := get_parent() as Game
	if power_level > 0 and host:
		host._player.power = clampi(power_level, 1, Cfg.MAX_POWER)
		host._player._refresh_beams()
		power_level = 0
	# Called directly rather than synthesised as a keypress: this driver runs
	# after the game's pause watcher has already polled input for the frame, so
	# a press here would be released again before anything ever sees it.
	if pause_after >= 0.0 and not _paused_once and _t >= pause_after and host:
		_paused_once = true
		host.toggle_pause()
		return

	if hyper_after >= 0.0 and not _hypered_once and _t >= hyper_after and host:
		_hypered_once = true
		host._player.add_charge(1.0)

	if weapon_after >= 0.0 and not _swapped_once and _t >= weapon_after and host:
		_swapped_once = true
		host._player.cycle_weapon()

	if tunnel_after >= 0.0 and not _tunnelled_once and _t >= tunnel_after and host:
		_tunnelled_once = true
		host._transition((host.stage + 1) % LevelDefs.count(), false)

	# Alternate weapons every few seconds so both are exercised.
	var laser := fmod(_t, 6.0) > 3.0
	_hold("p_laser", laser)
	_hold("p_shot", not laser)

	if hunt and host != null and _chase(host):
		return

	# Weave across the lower third of the playfield, where a player would sit.
	var x := sin(_t * 0.9)
	_hold("p_left", x < -0.2)
	_hold("p_right", x > 0.2)
	var y: float = host._player.position.y if host != null else 800.0
	_hold("p_up", y > 880.0)
	_hold("p_down", y < 700.0)


## Flies at the nearest enemy instead of loitering. The default weave never gets
## close enough to exercise anything range-limited (the tracker's lock ring), so
## this is how those get driven without a human on the stick.
func _chase(host: Game) -> bool:
	var p: Vector2 = host._player.position
	var best := Vector2.INF
	var best_d := INF
	for e in host.enemies:
		if not e.alive or not e.hittable:
			continue
		var d: float = p.distance_squared_to(e.position)
		if d < best_d:
			best_d = d
			best = e.position
	if best == Vector2.INF:
		return false
	# Sit a little below the target rather than inside it, so the ship is not
	# constantly ramming what it is shooting at.
	var want := best + Vector2(0, 150.0)
	_hold("p_left", p.x - want.x > 12.0)
	_hold("p_right", want.x - p.x > 12.0)
	_hold("p_up", p.y - want.y > 12.0)
	_hold("p_down", want.y - p.y > 12.0)
	return true


func _hold(action: String, down: bool) -> void:
	if down:
		if not Input.is_action_pressed(action):
			Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _exit_tree() -> void:
	for a in ["p_shot", "p_laser", "p_left", "p_right", "p_up", "p_down"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)
