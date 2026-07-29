extends SceneTree
## One-off analysis: works out which way each ship sheet points.
##
## Each row of a sheet is a 2-frame thruster cycle, so the pixels that differ
## between the two frames in a row *are* the exhaust flame. The vertical centre
## of that difference tells us where the tail is, and therefore which way the
## hull faces. Run with:
##   godot --headless --path . --script res://tools/orientation_probe.gd

const FRAME := 256


func _initialize() -> void:
	var files: Array[String] = []
	for i in range(1, 10):
		files.append("res://assets/enemy/enemy_%d.png" % i)
	files.append("res://assets/playership/player_cyanship.png")
	files.append("res://assets/playership/player_redship.png")
	files.append("res://assets/playership/player_yellow.png")

	for f in files:
		var tex: Texture2D = load(f)
		var img := tex.get_image()
		img.decompress()
		img.convert(Image.FORMAT_RGBA8)

		# Row 1 is the "level" pose: frame 2 at (0, 256), frame 3 at (256, 256).
		var mass := 0.0
		var ysum := 0.0
		for y in FRAME:
			for x in FRAME:
				var a := img.get_pixel(x, FRAME + y)
				var b := img.get_pixel(FRAME + x, FRAME + y)
				var d := absf(a.r - b.r) + absf(a.g - b.g) \
					+ absf(a.b - b.b) + absf(a.a - b.a)
				if d > 0.15:
					mass += d
					ysum += d * y
		var cy := ysum / maxf(mass, 0.001)
		var verdict := "faces UP (tail at bottom)" if cy > FRAME * 0.5 \
			else "faces DOWN (tail at top)"
		print("%-26s mass=%7.1f  tail_y=%6.1f  %s"
			% [f.get_file(), mass, cy, verdict])
	quit()
