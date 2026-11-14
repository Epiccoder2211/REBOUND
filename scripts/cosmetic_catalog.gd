extends RefCounted
## Presentation data only. No movement values belong in this catalog.
static func defaults() -> Dictionary:
	return {"skin": "skin_echo", "trail": "trail_cyan", "glow": "glow_standard"}

static func definitions() -> Dictionary:
	return {
		"glow_spark": {"name": "First Spark", "slot": "glow", "cost": 0, "level": 2, "color": Color("ffe8a0"), "description": "Level 2 gift"},
		"trail_star": {"name": "Rising Star", "slot": "trail", "cost": 0, "level": 3, "color": Color("e2d5ff"), "description": "Level 3 gift"},
		"skin_champion": {"name": "Comeback Champion", "slot": "skin", "cost": 0, "level": 5, "color": Color("fff2bf"), "accent": Color.WHITE, "description": "Level 5 gift"},
		"glow_celestial": {"name": "Celestial Echo", "slot": "glow", "cost": 0, "level": 10, "color": Color("b2fff1"), "description": "Level 10 gift"},
		"skin_echo": {"name": "Echo Original", "slot": "skin", "cost": 0, "color": Color("68efff"), "accent": Color("e0fcff"), "description": "The first spark. Clear, luminous, unmistakably Echo."},
		"skin_solar": {"name": "Solar Echo", "slot": "skin", "cost": 80, "color": Color("ffc064"), "accent": Color("fff0bd"), "description": "A small sun, carrying the warmth of every comeback."},
		"skin_void": {"name": "Void Echo", "slot": "skin", "cost": 90, "color": Color("b995ff"), "accent": Color("f1ddff"), "description": "Amethyst light drawn from the quiet between stars."},
		"skin_pulse": {"name": "Pulse Echo", "slot": "skin", "cost": 90, "color": Color("ff83bd"), "accent": Color("ffe0ee"), "description": "A vivid heartbeat that refuses to fade."},
		"trail_cyan": {"name": "Ion Wake", "slot": "trail", "cost": 0, "color": Color("63eaff"), "description": "A clean cyan wake that traces your momentum."},
		"trail_gold": {"name": "Sunfall", "slot": "trail", "cost": 65, "color": Color("ffd580"), "description": "Fine golden sparks left in the wake of a dash."},
		"trail_nebula": {"name": "Nebula Thread", "slot": "trail", "cost": 75, "color": Color("c099ff"), "description": "A ribbon of violet starlight connecting every afterimage."},
		"glow_standard": {"name": "Quiet Radiance", "slot": "glow", "cost": 0, "color": Color("75eaff"), "description": "Soft concentric light. Echo's original signature."},
		"glow_royal": {"name": "Royal Orbit", "slot": "glow", "cost": 60, "color": Color("d0a4ff"), "description": "Amethyst orbital accents encircle the luminous core."},
		"glow_prism": {"name": "Prismatic Halo", "slot": "glow", "cost": 85, "color": Color("a2ffe5"), "description": "Three restrained spectral arcs in a slow celestial dance."}
	}

static func appearance(equipped: Dictionary) -> Dictionary:
	var catalog := definitions()
	var selected := defaults()
	for slot in selected:
		var id: Variant = equipped.get(slot)
		if id is String and catalog.has(id) and catalog[id]["slot"] == slot:
			selected[slot] = id
	return {"core": catalog[selected["skin"]]["color"], "accent": catalog[selected["skin"]]["accent"],
		"trail": catalog[selected["trail"]]["color"], "glow": catalog[selected["glow"]]["color"],
		"trail_style": selected["trail"], "glow_style": selected["glow"]}
