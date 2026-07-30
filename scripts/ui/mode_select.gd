class_name ModeSelect
extends Cabinet
## Pick a play mode. Each mode keeps its own ranking table, so the choice is
## also a choice of which leaderboard you are competing on.

signal confirmed(mode: int)
signal cancelled()

const ENTRIES := [
	{
		"name": "ARCADE",
		"tag": "THE WAY THAT GOD INTENDED",
		"lines": [
			"FIVE STAGES. ONE CREDIT.",
			"NO CONTINUES, NO SECOND CHANCES.",
			"CLEAR IT OR DIE TRYING.",
		],
		"col": Cfg.UI_ACCENT,
	},
	{
		"name": "ENDLESS",
		"tag": "HOW DEEP CAN YOU GET",
		"lines": [
			"THE STAGES LOOP FOREVER,",
			"HARDER EVERY TIME AROUND.",
			"CONTINUE AS OFTEN AS YOU LIKE -",
			"BUT EVERY CONTINUE RESETS YOUR SCORE.",
		],
		"col": Color(1.0, 0.55, 0.85),
	},
]

var _sel := 0
var _titles: Array[Label] = []
var _tag: Label
var _body: Label
var _best: Label
var _anim := 0.0
var _ready_input := 0.3


func _ready() -> void:
	build(3)
	_sel = GS.mode

	label("SELECT MODE", 110.0, 48, Cfg.UI_ACCENT)

	for i in ENTRIES.size():
		_titles.append(label(String(ENTRIES[i].name), 250.0 + i * 76.0, 44,
			Cfg.UI_TEXT))

	_tag = label("", 430.0, 22, Cfg.UI_GOLD)
	_body = label("", 500.0, 20, Cfg.UI_TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_OFF
	_body.size = Vector2(Cfg.FIELD_W, 200.0)
	_best = label("", 700.0, 22, Cfg.UI_DIM)

	label("W / S  CHOOSE     J  CONFIRM     ESC  BACK",
		Cfg.FIELD_H - 150.0, 19, Cfg.UI_DIM)
	_refresh()


func _process(dt: float) -> void:
	super._process(dt)
	_anim += dt
	var k := 0.7 + 0.3 * absf(sin(_anim * 4.5))
	for i in _titles.size():
		_titles[i].modulate.a = k if i == _sel else 1.0

	if _ready_input > 0.0:
		_ready_input -= dt
		return

	if Input.is_action_just_pressed("p_up") or Input.is_action_just_pressed("ui_up"):
		_sel = posmod(_sel - 1, ENTRIES.size())
		AU.play("menu_move")
		_refresh()
	if Input.is_action_just_pressed("p_down") or Input.is_action_just_pressed("ui_down"):
		_sel = posmod(_sel + 1, ENTRIES.size())
		AU.play("menu_move")
		_refresh()
	if Input.is_action_just_pressed("p_start"):
		AU.play("menu_select")
		GS.set_mode(_sel)
		confirmed.emit(_sel)
	elif Input.is_action_just_pressed("p_back"):
		cancelled.emit()


func _refresh() -> void:
	var e: Dictionary = ENTRIES[_sel]
	for i in _titles.size():
		var on := i == _sel
		_titles[i].text = ("> %s <" % ENTRIES[i].name) if on \
			else String(ENTRIES[i].name)
		_titles[i].add_theme_color_override("font_color",
			ENTRIES[i].col if on else Cfg.UI_DIM)
		_titles[i].modulate.a = 1.0

	_tag.text = String(e.tag)
	_tag.add_theme_color_override("font_color", e.col)
	_body.text = "\n".join(PackedStringArray(e.lines))

	# Show what you are shooting at on this mode's board.
	var t: Array = GS.table(_sel)
	if t.is_empty():
		_best.text = ""
	else:
		_best.text = "%s BEST   %s   %s" % [String(e.name),
			Cfg.fmt_score(int(t[0].score)), String(t[0].get("name", "---"))]
