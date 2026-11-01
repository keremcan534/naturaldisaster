extends RefCounted
## Gyro aim on phones (browser device motion): turning the phone turns the view.
## Off by default (Settings.gyro). iOS asks for permission, which a page may only
## do inside a real touch handler, so a one-shot listener asks on the next touch.

static var _started := false


static func available() -> bool:
	return OS.has_feature("web")


static func start() -> void:
	if not available() or _started:
		return
	_started = true
	# Rotation rates (degrees/s) summed up between reads, already turned into
	# view yaw/pitch for the screen's orientation (right turn and look down are
	# positive, like a finger dragging right and down).
	JavaScriptBridge.eval("""
		window._gyro = {yaw: 0, pitch: 0};
		var listen = function () {
			window.addEventListener('devicemotion', function (e) {
				var r = e.rotationRate;
				if (!r) { return; }
				var dt = e.interval > 1 ? e.interval / 1000 : (e.interval || 0.016);
				var angle = (screen.orientation && screen.orientation.angle) || window.orientation || 0;
				var b = r.beta || 0, g = r.gamma || 0, yaw, pitch;
				if (angle == 90) { yaw = -b; pitch = g; }
				else if (angle == 270 || angle == -90) { yaw = b; pitch = -g; }
				else { yaw = -g; pitch = -b; }
				window._gyro.yaw += yaw * dt;
				window._gyro.pitch += pitch * dt;
			});
		};
		if (typeof DeviceMotionEvent !== 'undefined' && typeof DeviceMotionEvent.requestPermission === 'function') {
			document.addEventListener('touchend', function () {
				DeviceMotionEvent.requestPermission().then(function (s) {
					if (s === 'granted') { listen(); }
				}).catch(function () {});
			}, { once: true });
		} else {
			listen();
		}
	""", true)


## The turn since the last read, in radians (x: yaw, y: pitch).
static func read() -> Vector2:
	if not _started:
		return Vector2.ZERO
	var text: Variant = JavaScriptBridge.eval("""
		(function () {
			var g = window._gyro;
			if (!g) { return '0,0'; }
			var out = g.yaw + ',' + g.pitch;
			g.yaw = 0; g.pitch = 0;
			return out;
		})()
	""", true)
	if typeof(text) != TYPE_STRING:
		return Vector2.ZERO
	var parts: PackedStringArray = (text as String).split(",")
	if parts.size() != 2:
		return Vector2.ZERO
	return Vector2(parts[0].to_float(), parts[1].to_float()) * (PI / 180.0)
