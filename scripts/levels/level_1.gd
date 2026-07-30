class_name Level1
extends RefCounted
## Stage 1 - VERDANT COAST.
## Teaches the vocabulary: ranks, weavers, emplacements, then a first boss.

const W := Cfg.FIELD_W


func run(d: Director) -> void:
	d.banner("STAGE 1", "VERDANT COAST")
	await d.wait(3.2)

	# 1. Warm-up ranks, alternating direction so the player sweeps the field.
	await d.row("POPCORN", 7, 0.13, 110.0, W - 110.0)
	await d.wait(1.1)
	await d.row("POPCORN", 7, 0.13, W - 110.0, 110.0)
	await d.wait(1.6)

	# 2. First shooters.
	await d.vee("SCOUT", 2, W * 0.5)
	await d.wait(2.4)
	await d.row("SCOUT", 5, 0.22, 150.0, W - 150.0)
	await d.wait(2.8)

	# 3. Weavers slaloming past.
	await d.snake("WEAVER", 4, 0.22, true)
	await d.wait(1.4)
	await d.snake("WEAVER", 4, 0.22, false)
	await d.wait(2.6)

	# 4. Two emplacements: the player must pick a side.
	d.one("TURRET", Vector2(W * 0.27, Cfg.SPAWN_Y), {
		"move": {"type": "enter_hold_exit", "enter": 1.1, "hold": 5.0,
			"hold_at": Vector2(W * 0.27, 230.0), "exit_dir": 90.0,
			"exit_speed": 300.0},
	})
	d.one("TURRET", Vector2(W * 0.73, Cfg.SPAWN_Y), {
		"move": {"type": "enter_hold_exit", "enter": 1.1, "hold": 5.0,
			"hold_at": Vector2(W * 0.73, 230.0), "exit_dir": 90.0,
			"exit_speed": 300.0},
	})
	await d.wait(1.0)
	await d.row("POPCORN", 6, 0.16, 200.0, W - 200.0)
	await d.wait_until_under(2, 9.0)
	await d.wait(1.2)

	# 5. Diagonal interceptors from both wings.
	await d.crossfire("LANCER", 3, 0.55, 300.0, 150.0)
	await d.wait(3.0)

	# 6. A slow bomber under escort.
	d.one("BOMBER", Vector2(W * 0.5, Cfg.SPAWN_Y))
	await d.wait(0.7)
	await d.column("POPCORN", 4, W * 0.2, 0.25)
	await d.column("POPCORN", 4, W * 0.8, 0.25)
	await d.wait_until_under(2, 12.0)
	await d.wait(1.4)

	# 7. Carousel: a rotating ring of scouts.
	d.carousel("SCOUT", 6, 215.0, 1.0, {
		"attacks": [{"pattern": "aimed", "n": 1, "speed": 265.0,
			"style": "small", "color": "pink", "start": 1.2, "interval": 1.6}],
	})
	await d.wait(7.5)
	await d.wait_clear(8.0)

	# 8. Divers.
	for i in 3:
		await d.row("HUNTER", 3, 0.20, 160.0, W - 160.0)
		await d.wait(2.2)
	await d.wait(1.6)

	# 9. Spinner pair with popcorn pressure.
	d.one("SPINNER", Vector2(W * 0.35, Cfg.SPAWN_Y), {
		"move": {"type": "enter_hold_exit", "enter": 1.2, "hold": 6.0,
			"hold_at": Vector2(W * 0.35, 260.0), "exit_dir": 90.0,
			"exit_speed": 280.0},
	})
	d.one("SPINNER", Vector2(W * 0.65, Cfg.SPAWN_Y), {
		"move": {"type": "enter_hold_exit", "enter": 1.2, "hold": 6.0,
			"hold_at": Vector2(W * 0.65, 260.0), "exit_dir": 90.0,
			"exit_speed": 280.0},
	})
	await d.wait(2.0)
	await d.snake("POPCORN", 5, 0.16, true)
	await d.wait_until_under(2, 12.0)
	await d.wait(1.8)

	# 9b. Stinger slalom threaded through popcorn ranks.
	await d.snake("STINGER", 4, 0.26, false)
	await d.wait(1.6)
	await d.row("POPCORN", 7, 0.12, 130.0, W - 130.0)
	await d.wait(1.5)
	await d.snake("STINGER", 4, 0.26, true)
	await d.wait_until_under(2, 12.0)
	await d.wait(1.4)

	# 9c. Turret trio holding a line, with a bomber closing in behind them.
	for i in 3:
		d.one("TURRET", Vector2(W * (0.28 + 0.22 * i), Cfg.SPAWN_Y), {
			"move": {"type": "enter_hold_exit", "enter": 1.1, "hold": 5.5,
				"hold_at": Vector2(W * (0.28 + 0.22 * i), 200.0 + 40.0 * (i % 2)),
				"exit_dir": 90.0, "exit_speed": 300.0},
		})
		await d.wait(0.4)
	await d.wait(1.8)
	d.one("BOMBER", Vector2(W * 0.5, Cfg.SPAWN_Y))
	await d.wait_until_under(2, 14.0)
	await d.wait(1.8)

	# 10. Mid-stage heavy.
	d.banner("", "WARDEN CLASS APPROACHING", 2.0)
	d.one("WARDEN", Vector2(W * 0.5, Cfg.SPAWN_Y), {
		"move": {"type": "enter_hold_exit", "enter": 1.6, "hold": 13.0,
			"hold_at": Vector2(W * 0.5, 250.0), "exit_dir": 90.0,
			"exit_speed": 240.0, "bob": 24.0},
	})
	await d.wait(2.5)
	await d.row("POPCORN", 5, 0.2, 120.0, W - 120.0)
	await d.wait_clear(26.0)
	await d.wait(2.0)

	# 10b. Breather, then a guard with escorts.
	await d.row("POPCORN", 8, 0.11, 100.0, W - 100.0)
	await d.wait(1.4)
	d.one("GUARD", Vector2(W * 0.5, Cfg.SPAWN_Y), {
		"move": {"type": "enter_hold_exit", "enter": 1.4, "hold": 6.5,
			"hold_at": Vector2(W * 0.5, 230.0), "exit_dir": 90.0,
			"exit_speed": 260.0},
	})
	await d.wait(1.2)
	await d.snake("WEAVER", 4, 0.24, true)
	await d.wait_until_under(2, 14.0)
	await d.wait(1.6)

	# 11. Final push before the boss.
	await d.row("WEAVER", 4, 0.3, 140.0, W - 140.0)
	await d.wait(1.2)
	await d.crossfire("LANCER", 3, 0.48, 340.0, 130.0)
	await d.wait(2.0)
	d.one("SEEKER", Vector2(W * 0.3, Cfg.SPAWN_Y))
	d.one("SEEKER", Vector2(W * 0.7, Cfg.SPAWN_Y))
	await d.wait_until_under(2, 12.0)
	await d.wait(2.2)

	await d.boss(BossDefs.get_boss(0))
