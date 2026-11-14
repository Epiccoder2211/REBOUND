extends RefCounted
## Deterministic offline analysis. No network, model, or personal-data upload.
static func analyze(run: Dictionary, history: Array = [], dash_unlocked: bool = false) -> Array[String]:
	var result: Array[String] = []
	if run.get("records", []).has("distance"):
		result.append("New distance record! You've traveled farther than ever before.")
	if int(run.get("springs", 0)) >= 5 and float(run.get("perfect_rebounds", 0)) / float(run["springs"]) < 0.3:
		result.append("Try pressing Jump just before reaching a spring for a stronger rebound.")
	if int(run.get("best_combo", 1)) >= 5:
		result.append("Strong momentum control. Keep linking your rebounds and abilities.")
	if dash_unlocked and int(run.get("springs", 0)) >= 3 and int(run.get("dashes", 0)) == 0:
		result.append("Air Dash is unlocked. Try combining it with a rebound to explore new routes.")
	if not history.is_empty() and float(run.get("distance", 0)) > float(history.back().get("distance", 0)) and float(run.get("distance", 0)) > 0:
		result.append("You traveled farther than in your previous journey.")
	if result.is_empty():
		result.append("Explore a new route and practice one movement chain at a time." if float(run.get("distance", 0)) > 0 else "Your next journey is ready when you are.")
	return result.slice(0, 3)
