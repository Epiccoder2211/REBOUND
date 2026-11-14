extends RefCounted
## Event counters only. World supplies monotonic verified route distance.
var active := false
var metrics: Dictionary = {}
var _seen: Dictionary = {}
func begin() -> bool:
	if active:
		return false
	active = true
	_seen.clear()
	metrics = {"duration": 0.0, "distance": 0.0, "coins": 0, "xp": 0, "jumps": 0,
		"springs": 0, "perfect_rebounds": 0, "dashes": 0, "slams": 0, "best_combo": 1,
		"style": 0, "falls": 0, "challenges": 0, "comebacks": 0, "records": [], "gifts": []}
	return true
func tick(delta: float) -> void:
	if active:
		metrics["duration"] += maxf(0.0, delta)
func event(kind: String, amount: int = 1, source_id: String = "") -> void:
	if not active or not metrics.has(kind) or amount <= 0:
		return
	if not source_id.is_empty():
		var key := kind + "/" + source_id
		if _seen.has(key) or _seen.size() >= 2048:
			return
		_seen[key] = true
	metrics[kind] += amount
func report_distance(distance: float) -> void:
	if active and is_finite(distance) and distance >= 0.0:
		metrics["distance"] = maxf(float(metrics["distance"]), minf(distance, 100000000.0))
