class_name PixelFont
extends RefCounted
## A 5x7 bitmap font, built into a FontFile at runtime.
##
## The project ships no font assets, and the engine's fallback is a smooth
## proportional face that fights the 16-bit art. Rather than add a dependency,
## the glyphs are authored here as pixel rows and baked into a texture atlas.
##
## Lowercase maps to the uppercase glyphs, which is both cheap and exactly what
## a real arcade ROM did.

const W := 5      ## Glyph width in pixels.
const H := 7      ## Glyph height in pixels.
const PAD := 1    ## Transparent gutter between atlas cells.
const COLS := 16
const BASE := 8   ## Nominal line size the atlas is authored for.

## Each glyph is seven 5-pixel rows, "1" set and "0" clear.
const GLYPHS := {
	"A": "01110/10001/10001/11111/10001/10001/10001",
	"B": "11110/10001/10001/11110/10001/10001/11110",
	"C": "01110/10001/10000/10000/10000/10001/01110",
	"D": "11110/10001/10001/10001/10001/10001/11110",
	"E": "11111/10000/10000/11110/10000/10000/11111",
	"F": "11111/10000/10000/11110/10000/10000/10000",
	"G": "01110/10001/10000/10111/10001/10001/01111",
	"H": "10001/10001/10001/11111/10001/10001/10001",
	"I": "01110/00100/00100/00100/00100/00100/01110",
	"J": "00111/00010/00010/00010/00010/10010/01100",
	"K": "10001/10010/10100/11000/10100/10010/10001",
	"L": "10000/10000/10000/10000/10000/10000/11111",
	"M": "10001/11011/10101/10101/10001/10001/10001",
	"N": "10001/11001/10101/10011/10001/10001/10001",
	"O": "01110/10001/10001/10001/10001/10001/01110",
	"P": "11110/10001/10001/11110/10000/10000/10000",
	"Q": "01110/10001/10001/10001/10101/10010/01101",
	"R": "11110/10001/10001/11110/10100/10010/10001",
	"S": "01111/10000/10000/01110/00001/00001/11110",
	"T": "11111/00100/00100/00100/00100/00100/00100",
	"U": "10001/10001/10001/10001/10001/10001/01110",
	"V": "10001/10001/10001/10001/10001/01010/00100",
	"W": "10001/10001/10001/10101/10101/11011/10001",
	"X": "10001/10001/01010/00100/01010/10001/10001",
	"Y": "10001/10001/01010/00100/00100/00100/00100",
	"Z": "11111/00001/00010/00100/01000/10000/11111",
	"0": "01110/10001/10011/10101/11001/10001/01110",
	"1": "00100/01100/00100/00100/00100/00100/01110",
	"2": "01110/10001/00001/00010/00100/01000/11111",
	"3": "11111/00010/00100/00010/00001/10001/01110",
	"4": "00010/00110/01010/10010/11111/00010/00010",
	"5": "11111/10000/11110/00001/00001/10001/01110",
	"6": "00110/01000/10000/11110/10001/10001/01110",
	"7": "11111/00001/00010/00100/01000/01000/01000",
	"8": "01110/10001/10001/01110/10001/10001/01110",
	"9": "01110/10001/10001/01111/00001/00010/01100",
	" ": "00000/00000/00000/00000/00000/00000/00000",
	".": "00000/00000/00000/00000/00000/01100/01100",
	",": "00000/00000/00000/00000/01100/01100/11000",
	"-": "00000/00000/00000/11111/00000/00000/00000",
	"_": "00000/00000/00000/00000/00000/00000/11111",
	"/": "00001/00010/00010/00100/01000/01000/10000",
	"\\": "10000/01000/01000/00100/00010/00010/00001",
	":": "00000/01100/01100/00000/01100/01100/00000",
	";": "00000/01100/01100/00000/01100/01100/11000",
	"!": "00100/00100/00100/00100/00100/00000/00100",
	"?": "01110/10001/00001/00010/00100/00000/00100",
	"'": "00100/00100/01000/00000/00000/00000/00000",
	"\"": "01010/01010/00000/00000/00000/00000/00000",
	"(": "00010/00100/01000/01000/01000/00100/00010",
	")": "01000/00100/00010/00010/00010/00100/01000",
	"[": "01110/01000/01000/01000/01000/01000/01110",
	"]": "01110/00010/00010/00010/00010/00010/01110",
	"<": "00010/00100/01000/10000/01000/00100/00010",
	">": "01000/00100/00010/00001/00010/00100/01000",
	"+": "00000/00100/00100/11111/00100/00100/00000",
	"=": "00000/00000/11111/00000/11111/00000/00000",
	"*": "00000/10101/01110/11111/01110/10101/00000",
	"%": "11001/11010/00010/00100/01000/01011/10011",
	"#": "01010/11111/01010/01010/01010/11111/01010",
	"&": "01100/10010/10010/01100/10101/10010/01101",
	"@": "01110/10001/10111/10101/10111/10000/01110",
}

static var _font: FontFile = null


## The shared instance; built on first use.
static func get_font() -> FontFile:
	if _font == null:
		_font = _build()
	return _font


static func _build() -> FontFile:
	var keys: Array = GLYPHS.keys()
	var rows := int(ceil(float(keys.size()) / COLS))
	var cell_w := W + PAD
	var cell_h := H + PAD

	var img := Image.create(COLS * cell_w, rows * cell_h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))

	var f := FontFile.new()
	f.fixed_size = BASE
	# Without this the atlas would only ever draw at its authored 8px size.
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
	var size_key := Vector2i(BASE, 0)

	for i in keys.size():
		var ch: String = keys[i]
		var cx := (i % COLS) * cell_w
		var cy := (i / COLS) * cell_h
		var lines: PackedStringArray = String(GLYPHS[ch]).split("/")
		for y in H:
			var line: String = lines[y]
			for x in W:
				if line[x] == "1":
					img.set_pixel(cx + x, cy + y, Color.WHITE)

		# With a bitmap-only FontFile the glyph index is the character code.
		var g := ch.unicode_at(0)
		f.set_glyph_texture_idx(0, size_key, g, 0)
		f.set_glyph_uv_rect(0, size_key, g, Rect2(cx, cy, W, H))
		f.set_glyph_size(0, size_key, g, Vector2(W, H))
		# Glyphs are positioned from the baseline, so lift them by their height.
		f.set_glyph_offset(0, size_key, g, Vector2(0, -H))
		f.set_glyph_advance(0, BASE, g, Vector2(W + 1, 0))

		# Lowercase reuses the same cell: arcade ROMs were uppercase-only.
		var lower := ch.to_lower()
		if lower != ch:
			var gl := lower.unicode_at(0)
			f.set_glyph_texture_idx(0, size_key, gl, 0)
			f.set_glyph_uv_rect(0, size_key, gl, Rect2(cx, cy, W, H))
			f.set_glyph_size(0, size_key, gl, Vector2(W, H))
			f.set_glyph_offset(0, size_key, gl, Vector2(0, -H))
			f.set_glyph_advance(0, BASE, gl, Vector2(W + 1, 0))

	f.set_texture_image(0, size_key, 0, img)
	f.set_cache_ascent(0, BASE, H)
	f.set_cache_descent(0, BASE, 1)
	return f
