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

var _t := 0.0
var _paused_once := false
var _hypered_once := false
var _tunnelled_once := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(dt: float) -> void:
	_t += dt
	if pause_after >= 0.0 and not _paused_once and _t >= pause_after:
		_paused_once = true
		Input.action_press("p_pause")
		await get_tree().process_frame
		Input.action_release("p_pause")
		return

	var host := get_parent() as Game
	if hyper_after >= 0.0 and not _hypered_once and _t >= hyper_after and host:
		_hypered_once = true
		host._player.add_charge(1.0)

	if tunnel_after >= 0.0 and not _tunnelled_once and _t >= tunnel_after and host:
		_tunnelled_once = true
		host._transition((host.stage + 1) % LevelDefs.count(), false)

	# Alternate weapons every few seconds so both are exercised.
	var laser := fmod(_t, 6.0) > 3.0
	_hold("p_laser", laser)
	_hold("p_shot", not laser)

	# Weave across the lower third of the playfield, where a player would sit.
	var x := sin(_t * 0.9)
	_hold("p_left", x < -0.2)
	_hold("p_right", x > 0.2)
	var y: float = host._player.position.y if host != null else 800.0
	_hold("p_up", y > 880.0)
	_hold("p_down", y < 700.0)


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
