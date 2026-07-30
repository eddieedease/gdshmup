class_name Level3
extends RefCounted
## Stage 3 - GLACIER CORE.
## Everything at once: layered curtains, lock-on volleys, relentless pressure.

const W := Cfg.FIELD_W


func run(d: Director) -> void:
	d.banner("FINAL STAGE", "GLACIER CORE")
	await d.wait(3.2)

	# 1. Immediate pressure - three overlapping ranks.
	d.row("POPCORN", 8, 0.09, 70.0, W - 70.0, {"hp": 14})
	await d.wait(0.5)
	d.row("POPCORN", 8, 0.09, W - 70.0, 70.0, {"hp": 14})
	await d.wait(0.9)
	await d.row("SCOUT", 5, 0.16, 150.0, W - 150.0, {
		"attacks": [{"pattern": "aimed", "n": 3, "spread": 20.0, "speed": 300.0,
			"style": "needle", "color": "cyan", "start": 0.5, "interval": 1.0}],
	})
	await d.wait(2.4)

	# 2. Lancer storm from both wings, two altitudes.
	d.crossfire("LANCER", 3, 0.46, 380.0, 130.0)
	await d.wait(0.8)
	await d.crossfire("LANCER", 3, 0.46, 380.0, 420.0)
	await d.wait(2.8)

	# 3. Turret grid: four emplacements, staggered rings.
	var grid := [
		Vector2(W * 0.18, 190.0), Vector2(W * 0.82, 190.0),
		Vector2(W * 0.34, 330.0), Vector2(W * 0.66, 330.0),
	]
	for i in grid.size():
		var p: Vector2 = grid[i]
		d.one("TURRET", Vector2(p.x, Cfg.SPAWN_Y), {
			"hp": 110,
			"move": {"type": "enter_hold_exit", "enter": 1.1, "hold": 8.0,
				"hold_at": p, "exit_dir": 90.0, "exit_speed": 320.0},
			"attacks": [{"pattern": "petal", "n": 9, "speed": 210.0,
				"curve": 60.0 * (1.0 if i % 2 == 0 else -1.0), "style": "small",
				"color": "blue", "aim": false, "start": 1.2 + 0.3 * i,
				"interval": 1.3}],
		})
		await d.wait(0.35)
	await d.wait(2.0)
	await d.snake("WEAVER", 5, 0.18, true)
	await d.wait_until_under(2, 14.0)
	await d.wait(1.0)

	# 4. Bomber line - three curtains that must be threaded in sequence.
	for i in 3:
		d.one("BOMBER", Vector2(W * (0.25 + 0.25 * i), Cfg.SPAWN_Y), {
			"hp": 130,
			"move": {"type": "line", "dir": 90.0, "speed": 78.0},
			"attacks": [{"pattern": "wall", "n": 17, "gap": 3, "speed": 225.0,
				"style": "small", "color": ["amber", "pink", "green"][i],
				"start": 0.9 + 0.55 * i, "interval": 1.9}],
		})
		await d.wait(0.6)
	await d.wait(2.4)
	await d.row("HUNTER", 5, 0.14, 120.0, W - 120.0)
	await d.wait_until_under(2, 16.0)
	await d.wait(1.2)

	# 4b. Stinger storm from alternating wings.
	for i in 3:
		await d.snake("STINGER", 5, 0.18, i % 2 == 0, {"hp": 55})
		await d.wait(1.3)
	await d.wait_until_under(2, 14.0)
	await d.wait(1.2)

	# 5. Triple carousel.
	d.carousel("SCOUT", 8, 270.0, 1.25, {"hp": 30})
	await d.wait(0.8)
	d.carousel("SCOUT", 6, 180.0, -1.7, {"hp": 30})
	await d.wait(0.8)
	d.carousel("POPCORN", 5, 100.0, 2.4, {"hp": 20})
	await d.wait(9.0)
	await d.wait_clear(9.0)
	await d.wait(1.0)

	# 6. Seeker swarm.
	for i in 5:
		d.one("SEEKER", Vector2(W * (0.15 + 0.175 * i), Cfg.SPAWN_Y), {
			"hp": 60,
			"attacks": [{"pattern": "homing", "n": 2, "spread": 140.0,
				"speed": 140.0, "style": "missile", "color": "amber",
				"homing": 160.0, "homing_time": 2.0, "start": 0.9,
				"interval": 1.8}],
		})
		await d.wait(0.3)
	await d.wait(1.2)
	await d.row("POPCORN", 8, 0.1, 90.0, W - 90.0, {"hp": 14})
	await d.wait_until_under(2, 16.0)
	await d.wait(1.4)

	# 6b. Warden vanguard: one heavy before the real pair.
	d.one("WARDEN", Vector2(W * 0.5, Cfg.SPAWN_Y), {
		"hp": 800,
		"move": {"type": "enter_hold_exit", "enter": 1.5, "hold": 11.0,
			"hold_at": Vector2(W * 0.5, 235.0), "exit_dir": 90.0,
			"exit_speed": 250.0, "bob": 20.0},
	})
	await d.wait(2.2)
	await d.row("POPCORN", 8, 0.11, 90.0, W - 90.0, {"hp": 16})
	await d.wait_clear(22.0)
	await d.wait(1.6)

	# 7. Spinner braid - five spirals, alternating direction.
	for i in 5:
		d.one("SPINNER", Vector2(W * (0.14 + 0.18 * i), Cfg.SPAWN_Y), {
			"hp": 120,
			"move": {"type": "enter_hold_exit", "enter": 1.2, "hold": 8.0,
				"hold_at": Vector2(W * (0.14 + 0.18 * i), 180.0 + 55.0 * (i % 2)),
				"exit_dir": 90.0, "exit_speed": 300.0},
			"attacks": [{"pattern": "spiral", "n": 2, "speed": 220.0,
				"rot": 19.0 * (1.0 if i % 2 == 0 else -1.0), "style": "tiny",
				"color": "violet", "aim": false, "flash": false,
				"start": 1.4, "interval": 0.10, "until": 9.0}],
		})
		await d.wait(0.3)
	await d.wait(4.0)
	await d.crossfire("LANCER", 4, 0.42, 400.0, 640.0)
	await d.wait_until_under(2, 16.0)
	await d.wait(1.6)

	# 8. Guard trio with bloom rings.
	d.banner("", "HEAVY GUARD DETACHMENT", 2.0)
	for i in 3:
		d.one("GUARD", Vector2(W * (0.28 + 0.22 * i), Cfg.SPAWN_Y), {
			"hp": 230,
			"move": {"type": "enter_hold_exit", "enter": 1.4, "hold": 9.0,
				"hold_at": Vector2(W * (0.28 + 0.22 * i), 210.0 + 45.0 * (i % 2)),
				"exit_dir": 90.0, "exit_speed": 260.0},
			"attacks": [
				{"pattern": "bloom", "n": 20, "speed": 450.0, "accel": -570.0,
					"speed_min": -180.0, "style": "orb", "color": "cyan",
					"aim": false, "start": 1.5 + 0.6 * i, "interval": 2.2},
				{"pattern": "aimed", "n": 3, "spread": 18.0, "speed": 320.0,
					"style": "needle", "color": "white", "start": 3.0,
					"interval": 2.4},
			],
		})
		await d.wait(0.5)
	await d.wait(3.0)
	await d.snake("POPCORN", 7, 0.13, false, {"hp": 16})
	await d.wait_clear(22.0)
	await d.wait(1.8)

	# 8b. Bomber and seeker gauntlet, curtains plus missiles at once.
	for i in 2:
		d.one("BOMBER", Vector2(W * (0.32 + 0.36 * i), Cfg.SPAWN_Y), {"hp": 140})
		await d.wait(0.7)
	await d.wait(1.4)
	for i in 3:
		d.one("SEEKER", Vector2(W * (0.22 + 0.28 * i), Cfg.SPAWN_Y), {"hp": 60})
		await d.wait(0.35)
	await d.wait_until_under(2, 18.0)
	await d.wait(1.6)

	# 9. Twin wardens with lock-on support.
	d.one("WARDEN", Vector2(W * 0.28, Cfg.SPAWN_Y), {
		"hp": 950,
		"move": {"type": "enter_hold_exit", "enter": 1.6, "hold": 16.0,
			"hold_at": Vector2(W * 0.28, 250.0), "exit_dir": 90.0,
			"exit_speed": 240.0, "bob": 22.0},
		"attacks": [
			{"pattern": "petal", "n": 13, "speed": 220.0, "curve": 60.0,
				"style": "small", "color": "pink", "start": 1.6, "interval": 1.4},
			{"pattern": "lockon", "n": 6, "radius": 240.0, "speed": 300.0,
				"style": "small", "color": "violet", "delay": 0.6,
				"start": 3.5, "interval": 3.0},
		],
	})
	d.one("WARDEN", Vector2(W * 0.72, Cfg.SPAWN_Y), {
		"hp": 950,
		"move": {"type": "enter_hold_exit", "enter": 2.0, "hold": 16.0,
			"hold_at": Vector2(W * 0.72, 250.0), "exit_dir": 90.0,
			"exit_speed": 240.0, "bob": 22.0},
		"attacks": [
			{"pattern": "vortex", "n": 14, "speed": 115.0, "accel": 120.0,
				"speed_max": 350.0, "curve": -45.0, "style": "small",
				"color": "cyan", "aim": false, "start": 2.0, "interval": 1.6},
			{"pattern": "aimed", "n": 5, "spread": 32.0, "speed": 330.0,
				"style": "needle", "color": "red", "start": 4.0, "interval": 2.2,
				"burst": 2, "burst_gap": 0.12},
		],
	})
	await d.wait(4.0)
	await d.row("HUNTER", 4, 0.18, 150.0, W - 150.0)
	await d.wait_clear(34.0)
	await d.wait(2.4)

	await d.boss(BossDefs.get_boss(2))
