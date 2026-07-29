extends Node
## Root scene. Owns exactly one screen at a time and swaps between them.
##
## Screens are built in code rather than loaded from .tscn files, which keeps
## the whole game in scripts and makes the flow readable in one place.

var _current: Node = null
var _screen := "title"
var _demo := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_cli()
	match _screen:
		"game":
			_show_game()
		"select":
			_show_select()
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			_show_title()


## Dev switches, passed after `--`:
##   --screen=title|select|game   start on a given screen
##   --stage=N                    begin at stage N (1-3)
##   --ship=N                     preselect ship N (1-3)
##   --boss                       boss rush: skip the waves in every stage
##   --demo                       drive the ship automatically
func _apply_cli() -> void:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--screen="):
			_screen = arg.split("=", true, 1)[1]
		elif arg.begins_with("--stage="):
			GS.start_level = clampi(int(arg.split("=")[1]) - 1, 0,
				LevelDefs.count() - 1)
		elif arg.begins_with("--ship="):
			GS.ship_index = clampi(int(arg.split("=")[1]) - 1, 0,
				ShipDefs.count() - 1)
		elif arg == "--boss":
			GS.boss_rush = true
		elif arg == "--demo":
			_demo = true


func _swap(node: Node) -> void:
	if is_instance_valid(_current):
		if _current is Game:
			# The game frees itself once its stage coroutines have unwound.
			_current.shutdown()
		else:
			_current.queue_free()
	_current = node
	add_child(node)


func _show_title() -> void:
	get_tree().paused = false
	AU.play_music("title")
	var t := TitleScreen.new()
	t.start_pressed.connect(_show_select)
	t.quit_pressed.connect(func(): get_tree().quit())
	_swap(t)


func _show_select() -> void:
	var s := ShipSelect.new()
	s.confirmed.connect(func(_i): _show_game())
	s.cancelled.connect(_show_title)
	_swap(s)


func _show_game() -> void:
	var g := Game.new()
	g.finished.connect(func(_cleared): _show_title())
	_swap(g)
	if _demo:
		g.add_child(DemoDriver.new())
