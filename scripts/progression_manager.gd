extends Node
## One manager per journey, outside terrain chunks. No autoload required.
## World triggers supply stable IDs; the manager does not judge obstacle success.

signal coins_changed(new_balance: int)
signal upgrade_purchased(node_id: String)
signal ability_unlocked(ability_id: String)
signal challenge_completed(challenge_id: String)
signal comeback_achieved(comeback_id: String, coins_awarded: int)
signal progression_loaded()
signal celebration(kind: String, source_id: String)
signal save_failed(message: String)
signal cosmetic_purchased(cosmetic_id: String)
signal cosmetic_equipped(cosmetic_id: String)
signal reward_received(amount: int, reason: String)

const COSMETICS = preload("res://scripts/cosmetic_catalog.gd")

const SAVE_VERSION := 1
const MAX_SOURCE_IDS := 2048
const MAX_COINS := 100000000
const MAX_STAT := 1000000000
const DEFAULT_SAVE := "user://echo_progression_v1.json"
const BRANCH_COLORS := {
	"mobility": Color("55e6ff"), "rebound": Color("bd8bff"),
	"impact": Color("ffce72"), "utility": Color("53e6c5")
}

# Rewards are instance properties so a world can tune them before play.
var coin_pickup_reward := 5
var perfect_rebound_reward := 10
var comeback_reward := 25
var challenge_reward := 40
var biome_reward := 50
var ascension_reward := 100
var auto_save := true
var save_path := DEFAULT_SAVE
var coins := 0
var stats := _default_stats()
var _unlocked := {"basic_movement": true, "perfect_rebound": true}
var _challenges: Dictionary = {}
var _biomes: Dictionary = {}
var _sources: Dictionary = {}
var _retired_chunk := -1
var _player: Node
var _dirty := false
var _save_elapsed := 0.0
var _last_player_position := Vector2.ZERO
var _owned_cosmetics := {"skin_echo": true, "trail_cyan": true, "glow_standard": true}
var _equipped_cosmetics := COSMETICS.defaults()

signal profile_changed()
signal xp_changed(total: int, level: int)
signal milestone_unlocked(level: int, cosmetic_id: String)
signal run_completed(summary: Dictionary)
const RUN_TRACKER = preload("res://scripts/run_tracker.gd")
const INSIGHTS = preload("res://scripts/performance_insights.gd")
const XP_THRESHOLDS := [0, 100, 250, 500, 900]
const MILESTONE_GIFTS := {2: "glow_spark", 3: "trail_star", 5: "skin_champion", 10: "glow_celestial"}
var display_name := ""
var lifetime_xp := 0
var reduced_motion := false
var recent_runs: Array = []
var personal_bests := {"distance": 0.0, "combo": 1}
var xp_rewards := {"challenge": 40, "comeback": 30, "biome": 50, "ascension": 100, "distance_record": 75, "combo_record": 50}
var run_tracker := RUN_TRACKER.new()
var _claimed_milestones: Dictionary = {}

func set_display_name(value: String) -> bool:
	var clean := ""
	for character in value.strip_edges():
		if character.unicode_at(0) >= 32 and character.unicode_at(0) != 127:
			clean += character
	clean = clean.strip_edges().left(24)
	if clean.is_empty():
		return false
	display_name = clean
	profile_changed.emit()
	_commit()
	return true

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if is_instance_valid(_player): _player.reduced_visual_motion = enabled
	profile_changed.emit()
	_commit()

func xp_threshold(level: int) -> int:
	if level <= 5:
		return XP_THRESHOLDS[clampi(level - 1, 0, 4)]
	var n := level - 5
	return 900 + n * 500 + (n * (n - 1) / 2) * 150

func get_player_level() -> int:
	var level := 1
	while level < 100 and lifetime_xp >= xp_threshold(level + 1):
		level += 1
	return level

func _grant_xp(amount: int) -> void:
	# Internal: callers already validated unique world sources or run completion.
	lifetime_xp = mini(MAX_STAT, lifetime_xp + maxi(0, amount))
	run_tracker.event("xp", amount)
	var level := get_player_level()
	for milestone in MILESTONE_GIFTS:
		if level >= milestone and not _claimed_milestones.has(str(milestone)):
			_claimed_milestones[str(milestone)] = true
			var gift: String = MILESTONE_GIFTS[milestone]
			_owned_cosmetics[gift] = true
			if run_tracker.active:
				run_tracker.metrics["gifts"].append(gift)
			milestone_unlocked.emit(milestone, gift)
	xp_changed.emit(lifetime_xp, level)

func start_run() -> bool:
	return run_tracker.begin()

func report_run_distance(verified_route_distance: float) -> void:
	run_tracker.report_distance(verified_route_distance)

func end_run() -> Dictionary:
	if not run_tracker.active:
		return {}
	var run: Dictionary = run_tracker.metrics
	# Record awards require substantial improvements, not tiny increments.
	if float(run["distance"]) >= maxf(1000.0, float(personal_bests["distance"]) + 1000.0):
		_grant_xp(xp_rewards["distance_record"])
		run["records"].append("distance")
	if int(run["best_combo"]) >= maxi(3, int(personal_bests["combo"]) + 1):
		_grant_xp(xp_rewards["combo_record"])
		run["records"].append("combo")
	personal_bests["distance"] = maxf(float(personal_bests["distance"]), float(run["distance"]))
	personal_bests["combo"] = maxi(int(personal_bests["combo"]), int(run["best_combo"]))
	# Completion XP requires forward route progress and an actual milestone.
	if float(run["duration"]) >= 20.0 and float(run["distance"]) >= 500.0 and int(run["challenges"]) + int(run["comebacks"]) > 0:
		_grant_xp(mini(25, int(float(run["distance"]) / 500.0) * 5))
	run["insights"] = INSIGHTS.analyze(run, recent_runs, _unlocked.has("air_dash"))
	run["total_xp"] = lifetime_xp
	run["level"] = get_player_level()
	run_tracker.active = false
	recent_runs.append(run.duplicate(true))
	if recent_runs.size() > 10:
		recent_runs.pop_front()
	_commit()
	run_completed.emit(run.duplicate(true))
	return run.duplicate(true)

func _run_jump() -> void: run_tracker.event("jumps")
func _run_dash(_direction: Vector2) -> void: run_tracker.event("dashes")
func _run_slam() -> void: run_tracker.event("slams")
func _run_fall(_at: Vector2) -> void: run_tracker.event("falls")
func _run_spring(perfect: bool, _combo: int) -> void:
	run_tracker.event("springs")
	if perfect: run_tracker.event("perfect_rebounds")

func _load_profile(data: Dictionary) -> void:
	display_name = str(data.get("display_name", "")).strip_edges().left(24) if data.get("display_name", "") is String else ""
	lifetime_xp = _safe_int(data.get("lifetime_xp"), 0, MAX_STAT)
	reduced_motion = data.get("reduced_motion", false) == true
	_claimed_milestones.clear()
	personal_bests = {"distance": 0.0, "combo": 1}
	var best: Variant = data.get("personal_bests", {})
	if best is Dictionary:
		personal_bests["distance"] = _safe_int(best.get("distance"), 0, 100000000)
		personal_bests["combo"] = _safe_int(best.get("combo"), 1, 8)
	recent_runs = []
	var history: Variant = data.get("recent_runs", [])
	if history is Array:
		for record in history.slice(-10):
			if record is Dictionary:
				var safe := {}
				for key in ["duration", "distance", "coins", "xp", "jumps", "springs", "perfect_rebounds", "dashes", "slams", "best_combo", "style", "falls", "challenges", "comebacks", "total_xp", "level"]:
					safe[key] = _safe_int(record.get(key), 0, MAX_STAT)
				recent_runs.append(safe)
	# Reconstruct gifts from XP; repairs missing optional fields without stacking.
	for level in MILESTONE_GIFTS:
		if get_player_level() >= level:
			_claimed_milestones[str(level)] = true
			_owned_cosmetics[MILESTONE_GIFTS[level]] = true
	run_tracker.active = false

func get_cosmetic_definitions() -> Dictionary:
	return COSMETICS.definitions()

func get_owned_cosmetics() -> Array:
	return _owned_cosmetics.keys()

func get_equipped_cosmetics() -> Dictionary:
	return _equipped_cosmetics.duplicate()

func get_cosmetic_appearance(equipped_override: Dictionary = {}) -> Dictionary:
	var selected := _equipped_cosmetics.duplicate()
	selected.merge(equipped_override, true)
	return COSMETICS.appearance(selected)

func purchase_cosmetic(cosmetic_id: String) -> bool:
	var catalog := COSMETICS.definitions()
	if not catalog.has(cosmetic_id) or _owned_cosmetics.has(cosmetic_id):
		return false
	if catalog[cosmetic_id].has("level"):
		return false
	var cost: int = catalog[cosmetic_id]["cost"]
	if coins < cost:
		return false
	coins -= cost
	_owned_cosmetics[cosmetic_id] = true
	coins_changed.emit(coins)
	cosmetic_purchased.emit(cosmetic_id)
	_commit()
	return true

func equip_cosmetic(cosmetic_id: String) -> bool:
	var catalog := COSMETICS.definitions()
	if not catalog.has(cosmetic_id) or not _owned_cosmetics.has(cosmetic_id):
		return false
	var slot: String = catalog[cosmetic_id]["slot"]
	if _equipped_cosmetics[slot] == cosmetic_id:
		return false
	_equipped_cosmetics[slot] = cosmetic_id
	_apply_cosmetics_to_player()
	cosmetic_equipped.emit(cosmetic_id)
	_commit()
	return true

func _load_cosmetics(data: Dictionary) -> void:
	_owned_cosmetics = {"skin_echo": true, "trail_cyan": true, "glow_standard": true}
	_equipped_cosmetics = COSMETICS.defaults()
	var catalog := COSMETICS.definitions()
	var owned: Variant = data.get("owned_cosmetics", [])
	if owned is Array:
		for id in owned.slice(0, catalog.size()):
			if id is String and catalog.has(id):
				_owned_cosmetics[id] = true
	var equipped: Variant = data.get("equipped_cosmetics", {})
	if equipped is Dictionary:
		for slot in _equipped_cosmetics:
			var id: Variant = equipped.get(slot)
			if id is String and _owned_cosmetics.has(id) and catalog[id]["slot"] == slot:
				_equipped_cosmetics[slot] = id

func _init(path: String = DEFAULT_SAVE) -> void:
	save_path = path

static func _default_stats() -> Dictionary:
	return {"world_coin_pickups": 0, "total_coins_earned": 0, "comebacks": 0,
		"highest_combo": 1, "total_style_points": 0, "distance_traveled": 0.0}

func _ready() -> void:
	load_progression()

func _process(delta: float) -> void:
	if is_instance_valid(_player) and _player.get("active") and not _player.get("dead"):
		run_tracker.tick(delta)
		var at: Vector2 = _player.global_position
		var distance := at.distance_to(_last_player_position)
		# Respawn teleports are not travel. Exact world distance may be supplied
		# separately by Ved's camera/world; this is a conservative motion statistic.
		if distance < 100.0:
			stats["distance_traveled"] = minf(MAX_STAT, float(stats["distance_traveled"]) + distance)
			_dirty = true
		_last_player_position = at
	_save_elapsed += delta
	if auto_save and _dirty and _save_elapsed >= 5.0:
		save_progression()

func _exit_tree() -> void:
	if auto_save and _dirty:
		save_progression()

func get_upgrade_definitions() -> Dictionary:
	var definitions := {
		"basic_movement": _node("Basic Movement", "Move, jump, and bounce automatically.", 0, [], "mobility", Vector2(110, 90)),
		"double_jump": _node("Double Jump", "One extra, slightly weaker jump per airtime.", 100, ["basic_movement"], "mobility", Vector2(110, 235)),
		"air_dash": _node("Air Dash", "Shift in midair. Earned through the Velocity Trial.", 0, ["basic_movement"], "mobility", Vector2(285, 235), "velocity_trial"),
		"dash_amplifier": _node("Dash Amplifier", "Dash 15% farther with the same collision checks.", 125, ["air_dash"], "mobility", Vector2(210, 395)),
		"perfect_rebound": _node("Perfect Rebound", "Press Jump just before spring contact for a stronger launch.", 0, [], "rebound", Vector2(490, 90)),
		"spring_mastery": _node("Spring Mastery", "Widens Perfect Rebound timing to 150 ms. Complete a Comeback first.", 75, ["perfect_rebound"], "rebound", Vector2(490, 235), "comeback"),
		"energy_booster": _node("Energy Booster", "Gain 25% more momentum energy from actions.", 125, ["spring_mastery"], "rebound", Vector2(490, 395)),
		"echo_overdrive": _node("Echo Overdrive", "At 100 energy, press E for five seconds of speed and style boosts.", 175, ["energy_booster"], "rebound", Vector2(490, 550)),
		"ground_slam": _node("Ground Slam", "X in midair. Earned through the Impact Trial.", 0, ["basic_movement"], "impact", Vector2(755, 90), "impact_trial"),
		"slam_pulse": _node("Slam Pulse", "Meaningful slam landings emit a 120 px environmental pulse.", 150, ["ground_slam"], "impact", Vector2(755, 235)),
		"coin_magnet": _node("Coin Magnet", "Attract world coins within 90 px. Collect ten coin objects first.", 60, ["basic_movement"], "utility", Vector2(755, 395), "ten_coins")
	}
	var effects := {
		"basic_movement": {}, "perfect_rebound": {}, "double_jump": {"double_jump_unlocked": true},
		"air_dash": {"dash_unlocked": true}, "dash_amplifier": {"dash_distance_multiplier": 1.15},
		"spring_mastery": {"perfect_window_msec": 150}, "energy_booster": {"energy_gain_multiplier": 1.25},
		"echo_overdrive": {"overdrive_unlocked": true}, "ground_slam": {"slam_unlocked": true},
		"slam_pulse": {"slam_pulse_radius": 120.0}, "coin_magnet": {"coin_magnet_radius": 90.0}
	}
	for node_id in definitions:
		definitions[node_id]["id"] = node_id
		definitions[node_id]["effects"] = effects[node_id]
	return definitions

func _node(title: String, description: String, cost: int, prerequisites: Array, branch: String, position: Vector2, challenge: String = "") -> Dictionary:
	return {"name": title, "description": description, "cost": cost,
		"prerequisites": prerequisites, "branch": branch, "position": position,
		"challenge": challenge, "effects": title}

func get_coin_balance() -> int:
	return coins

func get_bound_player() -> Node:
	return _player if is_instance_valid(_player) else null

func get_statistics() -> Dictionary:
	var result := stats.duplicate(true)
	result["abilities_unlocked"] = _unlocked.keys()
	return result

func _gate_met(gate: String) -> bool:
	match gate:
		"": return true
		"comeback": return int(stats["comebacks"]) > 0
		"ten_coins": return int(stats["world_coin_pickups"]) >= 10
		_: return _challenges.has(gate)

func get_node_state(node_id: String) -> String:
	if _unlocked.has(node_id):
		return "unlocked"
	var definitions := get_upgrade_definitions()
	if not definitions.has(node_id):
		return "locked"
	var definition: Dictionary = definitions[node_id]
	for prerequisite in definition["prerequisites"]:
		if not _unlocked.has(prerequisite):
			return "locked"
	return "available" if _gate_met(definition["challenge"]) else "locked"

func get_lock_reason(node_id: String) -> String:
	var definitions := get_upgrade_definitions()
	if not definitions.has(node_id):
		return "Unknown upgrade"
	var requirements: Array[String] = []
	for prerequisite in definitions[node_id]["prerequisites"]:
		if not _unlocked.has(prerequisite):
			requirements.append(definitions[prerequisite]["name"])
	var gate: String = definitions[node_id]["challenge"]
	if not _gate_met(gate):
		match gate:
			"comeback": requirements.append("Complete one Comeback")
			"ten_coins": requirements.append("Collect 10 world coin objects (%d/10)" % int(stats["world_coin_pickups"]))
			_: requirements.append("Complete " + gate.replace("_", " ").capitalize())
	return "; ".join(requirements)

func try_unlock_node(node_id: String) -> bool:
	if get_node_state(node_id) != "available":
		return false
	var cost: int = get_upgrade_definitions()[node_id]["cost"]
	if coins < cost:
		return false
	coins -= cost
	_unlocked[node_id] = true
	_apply_to_player()
	coins_changed.emit(coins)
	upgrade_purchased.emit(node_id)
	_commit()
	return true

func bind_player(player: Node) -> void:
	if is_instance_valid(_player):
		_disconnect_player()
	_player = player
	if not is_instance_valid(_player):
		return
	for pair in _run_connections():
		_player.connect(pair[0], pair[1])
	_player.style_points_awarded.connect(_on_style_points)
	_player.combo_changed.connect(_on_combo_changed)
	_player.spring_source_bounced.connect(_on_spring_source)
	_player.total_style_points = int(stats["total_style_points"])
	_last_player_position = _player.global_position
	_apply_to_player()

func _run_connections() -> Array:
	return [["jumped", _run_jump], ["double_jumped", _run_jump], ["dash_started", _run_dash], ["slam_started", _run_slam], ["died", _run_fall], ["spring_bounced", _run_spring]]

func _disconnect_player() -> void:
	for pair in _run_connections():
		if _player.is_connected(pair[0], pair[1]):
			_player.disconnect(pair[0], pair[1])
	for pair in [["style_points_awarded", _on_style_points], ["combo_changed", _on_combo_changed], ["spring_source_bounced", _on_spring_source]]:
		if _player.is_connected(pair[0], pair[1]):
			_player.disconnect(pair[0], pair[1])

func _apply_to_player() -> void:
	if is_instance_valid(_player):
		_player.apply_progression(_unlocked)
		_apply_cosmetics_to_player()

func _apply_cosmetics_to_player() -> void:
	if is_instance_valid(_player):
		_player.apply_cosmetics(get_cosmetic_appearance())
		_player.reduced_visual_motion = reduced_motion

func _on_style_points(points: int, _reason: String) -> void:
	run_tracker.event("style", points)
	stats["total_style_points"] = mini(MAX_STAT, int(stats["total_style_points"]) + maxi(0, points))
	_dirty = true

func _on_combo_changed(combo: int) -> void:
	if run_tracker.active:
		run_tracker.metrics["best_combo"] = maxi(int(run_tracker.metrics["best_combo"]), combo)
	stats["highest_combo"] = maxi(int(stats["highest_combo"]), combo)
	_dirty = true

func _on_spring_source(source_id: String, perfect: bool) -> void:
	if perfect:
		reward_perfect_rebound(source_id)

func _style_bonus(points: int, reason: String) -> void:
	if is_instance_valid(_player):
		_player.award_style_points(points, reason)
	else:
		_on_style_points(points, reason)

func has_claimed_source(kind: String, source_id: String) -> bool:
	return _is_retired(source_id) or _sources.has(kind + "|" + source_id)

func _claim(kind: String, source_id: String) -> bool:
	if source_id.is_empty() or source_id.contains("|") or source_id.length() > 180 or has_claimed_source(kind, source_id):
		return false
	# Fail closed instead of evicting IDs and allowing still-loaded objects to
	# reward again. Worlds should retire unloaded chunks to keep this bounded.
	if _sources.size() >= MAX_SOURCE_IDS:
		return false
	_sources[kind + "|" + source_id] = true
	return true

func _chunk_index(source_id: String) -> int:
	var parts := source_id.split("/")
	if parts.size() >= 3 and parts[0] == "chunk" and parts[1].is_valid_int():
		return int(parts[1])
	return -1

func _is_retired(source_id: String) -> bool:
	var index := _chunk_index(source_id)
	return index >= 0 and index <= _retired_chunk

func retire_chunks_through(index: int) -> void:
	# Call only once these monotonically numbered chunks can never be revisited.
	_retired_chunk = maxi(_retired_chunk, index)
	for key in _sources.keys():
		var source: String = str(key).get_slice("|", 1)
		if _is_retired(source):
			_sources.erase(key)
	_commit()

func _credit(amount: int, reason: String = "reward") -> void:
	var credited := mini(maxi(0, amount), MAX_COINS - coins)
	coins += credited
	run_tracker.event("coins", credited)
	stats["total_coins_earned"] = mini(MAX_STAT, int(stats["total_coins_earned"]) + credited)
	coins_changed.emit(coins)
	if credited > 0:
		reward_received.emit(credited, reason)

func add_coins(amount: int, source_id: String) -> bool:
	if amount <= 0 or not _claim("grant", source_id):
		return false
	_credit(amount)
	_commit()
	return true

func collect_coin(source_id: String) -> bool:
	if not _claim("coin", source_id):
		return false
	stats["world_coin_pickups"] = mini(MAX_STAT, int(stats["world_coin_pickups"]) + 1)
	_credit(coin_pickup_reward, "Echo Coins")
	_commit()
	return true

func reward_perfect_rebound(spring_id: String) -> bool:
	if not _claim("spring", spring_id):
		return false
	_credit(perfect_rebound_reward, "Perfect Rebound")
	_commit()
	return true

func complete_comeback(comeback_id: String) -> bool:
	# Only world success triggers call this. Dying never calls it.
	if not _claim("comeback", comeback_id):
		return false
	stats["comebacks"] = mini(MAX_STAT, int(stats["comebacks"]) + 1)
	_credit(comeback_reward, "Comeback")
	run_tracker.event("comebacks")
	_grant_xp(xp_rewards["comeback"])
	_style_bonus(250, "comeback")
	comeback_achieved.emit(comeback_id, comeback_reward)
	celebration.emit("comeback", comeback_id)
	_commit()
	return true

func complete_challenge(challenge_id: String) -> bool:
	if _challenges.has(challenge_id) or _challenges.size() >= 128 or challenge_id.length() > 180:
		return false
	var ascension := challenge_id == "ascension_challenge" or challenge_id.begins_with("ascension/")
	var momentum := challenge_id == "momentum_trial" or challenge_id.begins_with("momentum/")
	if not ascension and not momentum and challenge_id not in ["velocity_trial", "impact_trial"]:
		return false
	_challenges[challenge_id] = true
	run_tracker.event("challenges")
	_grant_xp(xp_rewards["ascension"] if ascension else xp_rewards["challenge"])
	_credit(ascension_reward if ascension else challenge_reward, "Ascension" if ascension else "Trial complete")
	var node_id := "air_dash" if challenge_id == "velocity_trial" else "ground_slam"
	if challenge_id in ["velocity_trial", "impact_trial"]:
		_unlocked[node_id] = true
		_apply_to_player()
		ability_unlocked.emit("dash" if node_id == "air_dash" else "slam")
	_style_bonus(1000 if ascension else 400, challenge_id)
	challenge_completed.emit(challenge_id)
	celebration.emit("ascension" if ascension else "challenge", challenge_id)
	_commit()
	return true

func enter_biome(biome_id: String) -> bool:
	if biome_id.is_empty() or biome_id.length() > 80 or _biomes.has(biome_id) or _biomes.size() >= 64:
		return false
	_biomes[biome_id] = true
	_grant_xp(xp_rewards["biome"])
	_credit(biome_reward, "Biome discovered")
	celebration.emit("biome", biome_id)
	_commit()
	return true

func _commit() -> void:
	_dirty = true
	if auto_save:
		save_progression()

func save_progression() -> bool:
	var data := {"version": SAVE_VERSION, "coins": coins, "unlocked": _unlocked.keys(),
		"challenges": _challenges.keys(), "biomes": _biomes.keys(), "sources": _sources.keys(),
		"retired_chunk": _retired_chunk, "stats": stats,
		"owned_cosmetics": _owned_cosmetics.keys(), "equipped_cosmetics": _equipped_cosmetics, "display_name": display_name,
		"lifetime_xp": lifetime_xp, "player_level": get_player_level(), "claimed_milestones": _claimed_milestones.keys(),
		"personal_bests": personal_bests, "recent_runs": recent_runs, "reduced_motion": reduced_motion}
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_failed.emit("Cannot write progression: " + error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		save_failed.emit("Progression write failed")
		return false
	if not _read_save(save_path).is_empty():
		var backup_error := DirAccess.rename_absolute(save_path, save_path + ".bak")
		if backup_error != OK:
			save_failed.emit("Cannot back up progression")
			return false
	var rename_error := DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if rename_error != OK:
		if FileAccess.file_exists(save_path + ".bak"):
			DirAccess.rename_absolute(save_path + ".bak", save_path)
		save_failed.emit("Cannot finalize progression")
		return false
	_dirty = false
	_save_elapsed = 0.0
	return true

func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# Bound memory usage and reject malformed/newer formats without crashing.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1000000:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary or parsed.get("version") != SAVE_VERSION:
		return {}
	for key in ["unlocked", "challenges", "biomes", "sources"]:
		if not parsed.get(key) is Array:
			return {}
	if not parsed.get("stats") is Dictionary:
		return {}
	return parsed

func load_progression() -> bool:
	var data := _read_save(save_path)
	if data.is_empty():
		data = _read_save(save_path + ".bak")
	coins = 0
	stats = _default_stats()
	_unlocked = {"basic_movement": true, "perfect_rebound": true}
	_challenges.clear()
	_biomes.clear()
	_sources.clear()
	_retired_chunk = -1
	_load_cosmetics(data)
	_load_profile(data)
	if not data.is_empty():
		coins = _safe_int(data.get("coins"), 0, MAX_COINS)
		_retired_chunk = _safe_int(data.get("retired_chunk"), -1, MAX_STAT)
		for key in stats:
			stats[key] = _safe_int(data["stats"].get(key), 0, MAX_STAT)
		stats["highest_combo"] = clampi(int(stats["highest_combo"]), 1, 8)
		_load_ids(_challenges, data["challenges"], 128)
		_load_ids(_biomes, data["biomes"], 64)
		_load_ids(_sources, data["sources"], MAX_SOURCE_IDS)
		# Rebuild purchases in prerequisite order; never trust impossible saves.
		for pass_index in range(4):
			for node_id in data["unlocked"]:
				if node_id is String and get_node_state(node_id) == "available":
					_unlocked[node_id] = true
		if _challenges.has("velocity_trial"):
			_unlocked["air_dash"] = true
		if _challenges.has("impact_trial"):
			_unlocked["ground_slam"] = true
	_apply_to_player()
	if is_instance_valid(_player):
		_player.total_style_points = int(stats["total_style_points"])
	_dirty = false
	coins_changed.emit(coins)
	progression_loaded.emit()
	return not data.is_empty()

func _load_ids(target: Dictionary, entries: Array, limit: int) -> void:
	for entry in entries.slice(0, limit):
		if entry is String and not entry.is_empty() and entry.length() <= 200:
			target[entry] = true

func _safe_int(value: Variant, minimum: int, maximum: int) -> int:
	if (value is int or value is float) and is_finite(float(value)):
		return int(clampf(float(value), minimum, maximum))
	return minimum

func development_reset() -> bool:
	if not OS.is_debug_build():
		return false
	coins = 0
	stats = _default_stats()
	_unlocked = {"basic_movement": true, "perfect_rebound": true}
	_challenges.clear()
	_biomes.clear()
	_sources.clear()
	_retired_chunk = -1
	_load_cosmetics({})
	_load_profile({})
	_apply_to_player()
	if is_instance_valid(_player):
		_player.total_style_points = 0
	coins_changed.emit(0)
	progression_loaded.emit()
	_commit()
	return true
