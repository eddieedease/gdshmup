class_name Level2
extends RefCounted
## Stage 2 - SCORCHED FLATS.
## Denser formations, overlapping attack types and the first real curtains.

const W := Cfg.FIELD_W


func run(d: Director) -> void:
	d.banner("STAGE 2", "SCORCHED FLATS")
	await d.wait(3.2)

	# 1. Double ranks arriving from opposite ends at once.
	d.row("POPCORN", 6, 0.11, 80.0, W - 80.0)
	await d.wait(0.35)
	await d.row("POPCORN", 6, 0.11, W - 80.0, 80.0)
	await d.wait(2.0)

	# 2. Scouts that fire spreads instead of single shots.
	await d.row("SCOUT", 6, 0.18, 120.0, W - 120.0, {
		"hp": 22,
		"attacks": [{"pattern": "aimed", "n": 3, "spread": 24.0, "speed": 270.0,
			"style": "small", "color": "ember", "start": 0.6, "interval": 1.2}],
	})
	await d.wait(2.6)

	# 3. Interlocking snakes.
	d.snake("WEAVER", 4, 0.20, true)
	await d.wait(0.9)
	await d.snake("WEAVER", 4, 0.20, false)
	await d.wait(3.0)

	# 4. Three turrets in a triangle, each ringing on a different beat.
	var slots := [Vector2(W * 0.5, 190.0), Vector2(W * 0.22, 300.0),
		Vector2(W * 0.78, 300.0)]
	for i in slots.size():
		var p: Vector2 = slots[i]
		d.one("TURRET", Vector2(p.x, Cfg.SPAWN_Y), {
			"hp": 80,
			"move": {"type": "enter_hold_exit", "enter": 1.2, "hold": 7.0,
				"hold_at": p, "exit_dir": 90.0, "exit_speed": 300.0},
			"attacks": [{"pattern": "ring", "n": 12, "speed": 200.0,
				"rot": 15.0 + i * 7.0, "style": "small",
				"color": ["blue", "violet", "cyan"][i], "aim": false,
				"start": 1.4 + i * 0.4, "interval": 1.4}],
		})
		await d.wait(0.5)
	await d.wait(2.5)
	await d.row("POPCORN", 8, 0.1, 100.0, W - 100.0)
	await d.wait_until_under(2, 12.0)
	await d.wait(1.2)

	# 5. Divers with a curtain underneath them.
	d.one("BOMBER", Vector2(W * 0.35, Cfg.SPAWN_Y), {
		"attacks": [{"pattern": "wall", "n": 16, "gap": 3, "speed": 215.0,
			"style": "small", "color": "ember", "start": 1.0, "interval": 1.7}],
	})
	await d.wait(1.4)
	await d.row("HUNTER", 4, 0.16, 140.0, W - 140.0)
	await d.wait(2.6)
	await d.row("HUNTER", 4, 0.16, W - 140.0, 140.0)
	await d.wait_until_under(2, 14.0)
	await d.wait(1.4)

	# 5b. Stinger pairs crossing over a slow bomber.
	d.one("BOMBER", Vector2(W * 0.62, Cfg.SPAWN_Y))
	await d.wait(0.8)
	await d.snake("STINGER", 5, 0.22, true)
	await d.wait(1.2)
	await d.snake("STINGER", 5, 0.22, false)
	await d.wait_until_under(2, 14.0)
	await d.wait(1.4)

	# 6. Counter-rotating carousels.
	d.carousel("SCOUT", 7, 250.0, 1.15, {
		"hp": 24,
		"attacks": [{"pattern": "aimed", "n": 2, "spread": 14.0, "speed": 285.0,
			"style": "small", "color": "pink", "start": 1.0, "interval": 1.3}],
	})
	await d.wait(1.0)
	d.carousel("SCOUT", 5, 150.0, -1.5, {"hp": 24})
	await d.wait(8.0)
	await d.wait_clear(9.0)
	await d.wait(1.2)

	# 7. Spinner wall - three spirals braiding together.
	for i in 3:
		d.one("SPINNER", Vector2(W * (0.25 + 0.25 * i), Cfg.SPAWN_Y), {
			"hp": 95,
			"move": {"type": "enter_hold_exit", "enter": 1.3, "hold": 7.5,
				"hold_at": Vector2(W * (0.25 + 0.25 * i), 210.0 + 40.0 * (i % 2)),
				"exit_dir": 90.0, "exit_speed": 280.0},
			"attacks": [{"pattern": "spiral", "n": 2, "speed": 215.0,
				"rot": 17.0 * (1.0 if i != 1 else -1.0), "style": "tiny",
				"color": "violet", "aim": false, "flash": false,
				"start": 1.5, "interval": 0.10, "until": 8.5}],
		})
		await d.wait(0.45)
	await d.wait(3.0)
	await d.crossfire("LANCER", 3, 0.50, 360.0, 620.0)
	await d.wait_until_under(2, 14.0)
	await d.wait(1.6)

	# 7b. Weaver tide with scouts filling the gaps.
	for i in 3:
		d.row("WEAVER", 4, 0.22, 140.0, W - 140.0)
		await d.wait(1.1)
		await d.row("SCOUT", 4, 0.20, W - 180.0, 180.0)
		await d.wait(1.6)
	await d.wait_until_under(2, 14.0)
	await d.wait(1.4)

	# 8. Missile pressure.
	d.one("SEEKER", Vector2(W * 0.2, Cfg.SPAWN_Y))
	d.one("SEEKER", Vector2(W * 0.5, Cfg.SPAWN_Y))
	d.one("SEEKER", Vector2(W * 0.8, Cfg.SPAWN_Y))
	await d.wait(1.0)
	await d.snake("POPCORN", 6, 0.14, true)
	await d.wait_until_under(2, 14.0)
	await d.wait(1.6)

	# 9. Twin wardens.
	d.banner("", "TWIN WARDEN ESCORT", 2.0)
	d.one("WARDEN", Vector2(W * 0.3, Cfg.SPAWN_Y), {
		"hp": 1100,
		"move": {"type": "enter_hold_exit", "enter": 1.6, "hold": 14.0,
			"hold_at": Vector2(W * 0.3, 240.0), "exit_dir": 90.0,
			"exit_speed": 240.0, "bob": 20.0},
	})
	d.one("WARDEN", Vector2(W * 0.7, Cfg.SPAWN_Y), {
		"hp": 1100,
		"move": {"type": "enter_hold_exit", "enter": 1.9, "hold": 14.0,
			"hold_at": Vector2(W * 0.7, 240.0), "exit_dir": 90.0,
			"exit_speed": 240.0, "bob": 20.0},
		"attacks": [
			{"pattern": "petal", "n": 12, "speed": 215.0, "curve": -55.0,
				"style": "small", "color": "cyan", "start": 2.0, "interval": 1.5},
			{"pattern": "fan", "n": 4, "spread": 26.0, "swing": 55.0,
				"swing_rate": 0.4, "speed": 300.0, "style": "needle",
				"color": "white", "flash": false, "start": 3.2, "interval": 0.3},
		],
	})
	await d.wait(3.0)
	await d.row("POPCORN", 6, 0.18, 120.0, W - 120.0)
	await d.wait_clear(30.0)
	await d.wait(2.0)

	# 9b. Hunter waves either side of a turret pair.
	d.one("TURRET", Vector2(W * 0.24, Cfg.SPAWN_Y), {"hp": 90})
	d.one("TURRET", Vector2(W * 0.76, Cfg.SPAWN_Y), {"hp": 90})
	await d.wait(1.6)
	await d.row("HUNTER", 4, 0.16, 130.0, W - 130.0)
	await d.wait(2.4)
	await d.row("HUNTER", 4, 0.16, W - 130.0, 130.0)
	await d.wait_until_under(2, 16.0)
	await d.wait(1.6)

	# 10. Guard gauntlet before the boss.
	d.one("GUARD", Vector2(W * 0.5, Cfg.SPAWN_Y), {
		"move": {"type": "enter_hold_exit", "enter": 1.4, "hold": 7.0,
			"hold_at": Vector2(W * 0.5, 240.0), "exit_dir": 90.0,
			"exit_speed": 260.0},
	})
	await d.wait(1.2)
	await d.crossfire("LANCER", 4, 0.44, 380.0, 160.0)
	await d.wait_until_under(2, 14.0)
	await d.wait(2.2)

	await d.boss(BossDefs.get_boss(1))
