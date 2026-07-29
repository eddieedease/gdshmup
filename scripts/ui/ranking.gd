class_name Ranking
extends Cabinet
## The high-score table, shown after a run and from the title menu.

signal done()

const AUTO_ADVANCE := 14.0

## Rank to highlight (the run that just finished), or -1 for none.
var highlight := -1
## When false the screen waits for input instead of timing out.
var auto_advance := true

var _table: Table
var _anim := 0.0
var _ready_input := 0.35
var _countdown := AUTO_ADVANCE


func _ready() -> void:
	build(0)
	label("HIGH SCORES", 120.0, 56, Cfg.UI_ACCENT)

	_table = Table.new()
	_table.rows = GS.scores
	_table.highlight = highlight
	_table.position = Vector2(40.0, 240.0)
	_table.size = Vector2(Cfg.FIELD_W - 80.0, 620.0)
	content.add_child(_table)

	label("PRESS START", Cfg.FIELD_H - 190.0, 28, Cfg.UI_TEXT).name = "Prompt"
	if highlight >= 0:
		label("YOUR RUN IS RANKED %d" % (highlight + 1),
			Cfg.FIELD_H - 140.0, 20, Cfg.UI_GOLD)


func _process(dt: float) -> void:
	super._process(dt)
	_anim += dt
	_table.blink = _anim
	_table.queue_redraw()

	var prompt := content.get_node_or_null(^"Prompt") as Label
	if prompt:
		prompt.modulate.a = 0.35 + 0.65 * absf(sin(_anim * 3.2))

	if _ready_input > 0.0:
		_ready_input -= dt
		return
	if auto_advance:
		_countdown -= dt
		if _countdown <= 0.0:
			done.emit()
			return
	if Input.is_action_just_pressed("p_start") \
			or Input.is_action_just_pressed("p_back"):
		AU.play("menu_select")
		done.emit()


class Table:
	extends Control
	var rows: Array = []
	var highlight := -1
	var blink := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f := ThemeDB.fallback_font
		var y := 0.0
		var row_h := 66.0

		# Column header.
		draw_string(f, Vector2(10, 22), "RANK", HORIZONTAL_ALIGNMENT_LEFT, -1,
			18, Cfg.UI_DIM)
		draw_string(f, Vector2(120, 22), "NAME", HORIZONTAL_ALIGNMENT_LEFT, -1,
			18, Cfg.UI_DIM)
		draw_string(f, Vector2(270, 22), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1,
			18, Cfg.UI_DIM)
		draw_string(f, Vector2(560, 22), "REACHED", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 18, Cfg.UI_DIM)
		draw_rect(Rect2(Vector2(0, 34), Vector2(size.x, 2)),
			Color(Cfg.UI_LINE.r, Cfg.UI_LINE.g, Cfg.UI_LINE.b, 0.8))
		y = 52.0

		for i in rows.size():
			var e: Dictionary = rows[i]
			var is_new := i == highlight
			var col := Cfg.UI_TEXT
			if is_new:
				# Pulse the fresh entry so it is obvious which row is yours.
				var a: float = 0.55 + 0.45 * absf(sin(blink * 4.5))
				draw_rect(Rect2(Vector2(-8, y - 6), Vector2(size.x + 16, row_h - 8)),
					Color(Cfg.UI_GOLD.r, Cfg.UI_GOLD.g, Cfg.UI_GOLD.b, 0.16 * a))
				col = Cfg.UI_GOLD
			elif i == 0:
				col = Cfg.UI_ACCENT

			var base := y + 34.0
			draw_string(f, Vector2(10, base), "%d" % (i + 1),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
			draw_string(f, Vector2(120, base), String(e.get("name", "---")),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 34, col)

			var score_text := Cfg.fmt_score(int(e.get("score", 0)))
			var sw := f.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 30).x
			draw_string(f, Vector2(530 - sw, base), score_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)

			var reached := "ALL CLEAR" if bool(e.get("cleared", false)) \
				else "STAGE %d" % (int(e.get("stage", 0)) + 1)
			draw_string(f, Vector2(560, base), reached,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Cfg.UI_DIM if not is_new else col)

			var ship := ShipDefs.get_ship(int(e.get("ship", 0)))
			draw_string(f, Vector2(560, base + 22), String(ship.code),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ship.color)
			y += row_h
