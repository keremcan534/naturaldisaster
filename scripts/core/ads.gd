extends RefCounted
## Rewarded ads for web game portals. If the page defines
## window.showRewardedAd(onReward) (a small wrapper around a portal's SDK, added
## to the export's head include), the scoreboard offers "watch an ad: double
## the coins". Without it nothing shows. See ROADMAP.md (needs a portal account).

static var _callback: JavaScriptObject


static func available() -> bool:
	if not OS.has_feature("web"):
		return false
	return JavaScriptBridge.eval("typeof window.showRewardedAd === 'function'", true) == true


static func show_rewarded(on_reward: Callable) -> void:
	if not available():
		return
	_callback = JavaScriptBridge.create_callback(func(_args: Array) -> void: on_reward.call())
	var window := JavaScriptBridge.get_interface("window")
	window.showRewardedAd(_callback)
