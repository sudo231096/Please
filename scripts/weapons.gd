extends RefCounted
class_name Weapons
## Weapon stats table.


static func table() -> Dictionary:
	return {
		"glock": {
			"title": "GLOCK",
			"damage": 18,
			"rpm": 400.0,
			"mag": 12,
			"reserve": 48,
			"reload": 1.4,
			"spread": 0.025,
			"auto": false,
			"color": Color(0.25, 0.28, 0.32),
			"accent": Color(0.7, 0.75, 0.8),
			"length": 0.28,
		},
		"ak": {
			"title": "AK-NEON",
			"damage": 28,
			"rpm": 600.0,
			"mag": 30,
			"reserve": 90,
			"reload": 2.1,
			"spread": 0.035,
			"auto": true,
			"color": Color(0.18, 0.22, 0.18),
			"accent": Color(0.35, 0.9, 0.45),
			"length": 0.55,
		},
		"awp": {
			"title": "AWM",
			"damage": 100,
			"rpm": 50.0,
			"mag": 5,
			"reserve": 20,
			"reload": 2.6,
			"spread": 0.004,
			"auto": false,
			"color": Color(0.12, 0.14, 0.2),
			"accent": Color(0.3, 0.7, 1.0),
			"length": 0.7,
		},
	}


static func order() -> Array:
	return ["glock", "ak", "awp"]
