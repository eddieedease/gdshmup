class_name Terrain
extends Node2D
## Endlessly scrolling ground built from the 256px terrain tiles.
##
## A ring buffer of tile rows is recycled as the world scrolls, so the node
## count stays fixed. Tile choice comes from layered noise, which gives each
## stage coherent regions (water channels, rock outcrops) instead of static.

const TILE := 90.0                        ## 810 / 9 columns.
const COLS := 9
const ROWS := 14                          ## Enough to cover 1080px plus slack.

## The ground is scenery, never a read. Everything is pushed dark and low
## contrast so bullets and ships stay legible on top of it.
const BRIGHTNESS := 0.46

## Per-stage palettes: noise thresholds are walked top-down until one matches.
const PALETTES := [
	{
		"name": "VERDANT COAST",
		"tint": Color(0.66, 0.86, 0.76),
		"bands": [
			[-1.00, "water"], [-0.30, "sand"], [-0.16, "grass"],
			[0.32, "dirt"], [0.58, "stone"],
		],
		"decor": ["wood", "stone"],
		"speed": 92.0,
	},
	{
		"name": "SCORCHED FLATS",
		"tint": Color(0.98, 0.80, 0.58),
		"bands": [
			[-1.00, "stone"], [-0.44, "cobble"], [-0.18, "sand"],
			[0.38, "dirt"], [0.64, "swamp"],
		],
		"decor": ["cobble", "stone"],
		"speed": 118.0,
	},
	{
		"name": "GLACIER CORE",
		"tint": Color(0.70, 0.82, 1.0),
		"bands": [
			[-1.00, "water"], [-0.32, "snow"], [0.16, "stone"],
			[0.46, "cobble"], [0.70, "wood"],
		],
		"decor": ["stone", "wood"],
		"speed": 148.0,
	},
]

var speed := 92.0

var _tiles: Array[Sprite2D] = []
var _row_id: PackedInt32Array = PackedInt32Array()
var _scroll := 0.0
var _noise := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _palette: Dictionary = PALETTES[0]
var _decor: Array[Sprite2D] = []
var _decor_y: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	z_index = Cfg.Z_TERRAIN
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.075
	_noise.fractal_octaves = 3
	_detail.noise_type = FastNoiseLite.TYPE_VALUE
	_detail.frequency = 0.85

	var s := TILE / Art.FRAME
	for i in ROWS * COLS:
		var t := Sprite2D.new()
		t.centered = true
		t.scale = Vector2(s, s)
		add_child(t)
		_tiles.append(t)
	_row_id.resize(ROWS)
	for i in ROWS:
		_row_id[i] = -99999

	# Sparse silhouettes scrolling faster, for a hint of parallax depth.
	for i in 10:
		var d := Sprite2D.new()
		d.centered = true
		d.z_index = 1
		d.modulate = Color(0, 0, 0, 0.16)
		add_child(d)
		_decor.append(d)
		_decor_y.append(0.0)


func set_stage(index: int, seed_value: int) -> void:
	_palette = PALETTES[clampi(index, 0, PALETTES.size() - 1)]
	speed = _palette.speed
	_noise.seed = seed_value
	_detail.seed = seed_value * 7 + 13
	for i in ROWS:
		_row_id[i] = -99999
	var decor_pool: Array = _palette.decor
	for i in _decor.size():
		var d := _decor[i]
		d.texture = Art.TERRAIN[decor_pool[i % decor_pool.size()]]
		var sc := randf_range(0.18, 0.38)
		d.scale = Vector2(sc, sc * randf_range(0.6, 1.4))
		d.position.x = randf_range(0.0, Cfg.FIELD_W)
		_decor_y[i] = randf_range(-Cfg.FIELD_H, Cfg.FIELD_H)
		d.rotation = 0.0


func _process(dt: float) -> void:
	_scroll += speed * dt
	_refresh()
	var dspeed := speed * 1.65
	for i in _decor.size():
		_decor_y[i] += dspeed * dt
		if _decor_y[i] > Cfg.FIELD_H + 200.0:
			_decor_y[i] = randf_range(-600.0, -200.0)
			_decor[i].position.x = randf_range(0.0, Cfg.FIELD_W)
		_decor[i].position.y = _decor_y[i]


func _refresh() -> void:
	var first := floori((_scroll - TILE) / TILE)
	for k in ROWS:
		var r := first + k
		var slot := posmod(r, ROWS)
		if _row_id[slot] != r:
			_row_id[slot] = r
			_fill_row(slot, r)
		var y := float(r) * TILE - _scroll + TILE * 0.5
		for c in COLS:
			_tiles[slot * COLS + c].position = Vector2(TILE * (c + 0.5), y)


func _fill_row(slot: int, world_row: int) -> void:
	var tint: Color = _palette.tint
	var bands: Array = _palette.bands
	for c in COLS:
		var t := _tiles[slot * COLS + c]
		# Negative row index so the world reads as scrolling toward the player.
		var n := _noise.get_noise_2d(float(c) * 1.0, float(-world_row) * 1.0)
		var name: String = bands[0][1]
		for b in bands:
			if n >= float(b[0]):
				name = String(b[1])
		t.texture = Art.TERRAIN[name]
		var shade := BRIGHTNESS * (1.0
			+ _detail.get_noise_2d(c * 3.0, -world_row * 3.0) * 0.22)
		t.modulate = Color(tint.r * shade, tint.g * shade, tint.b * shade, 1.0)
		t.flip_h = absi(world_row * 7 + c * 3) % 2 == 0
		t.flip_v = absi(world_row * 5 + c) % 3 == 0


func stage_name() -> String:
	return String(_palette.name)
