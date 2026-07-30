extends Node
## Root scene. Owns exactly one screen at a time and swaps between them.
##
## Screens are built in code rather than loaded from .tscn files, which keeps
## the whole game in scripts and makes the flow readable in one place.

var _current: Node = null
var _screen := "title"
var _demo := false
var _pause_at := -1.0
var _hyper_at := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_cli()
	match _screen:
		"game":
			_show_game()
		"select":
			_show_select()
		"mode":
			_show_mode()
		"ranking":
			_show_ranking(2, false)
		"name":
			GS.last_run_score = 1_234_500
			GS.last_run_stage = 1
			_after_run()
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			_show_title()


## Dev switches, passed after `--`:
##   --screen=title|mode|select|game|ranking|name   start on a given screen
##   --endless                    play the endless mode
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
		elif arg == "--endless":
			GS.mode = GS.Mode.ENDLESS
		elif arg == "--demo":
			_demo = true
		elif arg.begins_with("--pause-at="):
			_pause_at = float(arg.split("=", true, 1)[1])
		elif arg.begins_with("--hyper-at="):
			_hyper_at = float(arg.split("=", true, 1)[1])


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
	t.start_pressed.connect(_show_mode)
	t.ranking_pressed.connect(func(): _show_ranking(-1, false))
	t.quit_pressed.connect(func(): get_tree().quit())
	_swap(t)


func _show_mode() -> void:
	var m := ModeSelect.new()
	m.confirmed.connect(func(_i): _show_select())
	m.cancelled.connect(_show_title)
	_swap(m)


func _show_select() -> void:
	var s := ShipSelect.new()
	s.confirmed.connect(func(_i): _show_game())
	s.cancelled.connect(_show_mode)
	_swap(s)


func _show_game() -> void:
	var g := Game.new()
	g.finished.connect(func(_cleared): _after_run())
	_swap(g)
	if _demo:
		var d := DemoDriver.new()
		d.pause_after = _pause_at
		d.hyper_after = _hyper_at
		g.add_child(d)


## A finished run goes to initials entry when it placed, then to the table.
func _after_run() -> void:
	AU.play_music("title")
	GS.last_run_rank = -1
	if GS.qualifies(GS.last_run_score):
		var n := NameEntry.new()
		n.rank = GS.provisional_rank(GS.last_run_score)
		n.score = GS.last_run_score
		n.submitted.connect(func(initials: String):
			GS.last_run_rank = GS.insert_score(initials, GS.last_run_score,
				GS.last_run_stage, GS.last_run_ship, GS.last_run_cleared)
			_show_ranking(GS.last_run_rank, true))
		_swap(n)
	else:
		_show_ranking(-1, true)


func _show_ranking(highlight: int, auto: bool) -> void:
	var r := Ranking.new()
	r.highlight = highlight
	r.auto_advance = auto
	r.done.connect(_show_title)
	_swap(r)
