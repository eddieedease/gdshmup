class_name DemoDriver
extends Node
## Development aid: synthesises player input so the game can be watched (or
## screenshotted) without someone holding the keys. Enabled with `--demo`.
##
## Not part of the game loop - Main only creates this when the flag is present.

var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(dt: float) -> void:
	_t += dt

	# Alternate weapons every few seconds so both are exercised.
	var laser := fmod(_t, 6.0) > 3.0
	_hold("p_laser", laser)
	_hold("p_shot", not laser)

	# Weave across the lower third of the playfield, where a player would sit.
	var x := sin(_t * 0.9)
	_hold("p_left", x < -0.2)
	_hold("p_right", x > 0.2)
	var host := get_parent() as Game
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
