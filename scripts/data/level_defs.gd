class_name LevelDefs
extends RefCounted
## Stage metadata: which script runs, which terrain palette to scroll, and how
## hard the enemies hit. Difficulty is applied uniformly by Director.

const STAGES := [
	{
		"title": "STAGE 1",
		"name": "VERDANT COAST",
		"terrain": 0,
		"difficulty": {"hp": 1.0, "fire_rate": 1.0, "speed": 1.0},
	},
	{
		"title": "STAGE 2",
		"name": "SCORCHED FLATS",
		"terrain": 1,
		"difficulty": {"hp": 1.7, "fire_rate": 1.22, "speed": 1.1},
	},
	{
		"title": "FINAL STAGE",
		"name": "GLACIER CORE",
		"terrain": 2,
		"difficulty": {"hp": 2.6, "fire_rate": 1.45, "speed": 1.2},
	},
]


static func count() -> int:
	return STAGES.size()


static func meta(i: int) -> Dictionary:
	return STAGES[clampi(i, 0, STAGES.size() - 1)]


static func script_for(i: int) -> RefCounted:
	match i:
		0:
			return Level1.new()
		1:
			return Level2.new()
		_:
			return Level3.new()
