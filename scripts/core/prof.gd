extends RefCounted
## A tiny profiler for --perf: hot code wraps its work in begin()/end(name) and
## debug_tools prints where the time went every second. Costs one static call
## when off.

static var on := false
static var _totals := {}


static func begin() -> int:
	return Time.get_ticks_usec() if on else 0


static func end(name: String, start: int) -> void:
	if on:
		_totals[name] = _totals.get(name, 0) + Time.get_ticks_usec() - start


## The biggest spenders since the last call, in ms per second.
static func report() -> String:
	var keys := _totals.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _totals[a] > _totals[b])
	var parts: Array = []
	for k: String in keys.slice(0, 9):
		parts.append("%s %.0f" % [k, _totals[k] / 1000.0])
	_totals.clear()
	return " ".join(parts)
