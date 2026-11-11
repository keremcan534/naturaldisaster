extends RefCounted
## Görev modu: hand-made scenarios, played one at a time from the menu's
## SENARYO screen. Each fixes the map, the disaster and its severity, the time of
## day, and asks for something (see `goal`); 1-3 stars. Each opens once the one
## before has at least a star. Stars live in Profile.mission_stars; every star
## the first time pays STAR_COINS.
##
## goal: "rescue" (save `count` hurt civilians), "high" (end above `height` m),
## "fire" (put out `count` burning pieces), "heli" (get lifted by the rescue
## helicopter), "survive". Stars: the goal and alive; health at least half;
## `third`: "flawless" (no damage) or "all" (every civilian saved).

const Profile := preload("res://scripts/core/profile.gd")
const Lang := preload("res://scripts/core/lang.gd")

const STAR_COINS := 100
const LIST := [
	{"id": "first_quake", "title": "İlk Sarsıntı", "map": 3, "disaster": 0, "severity": 1, "time": "day",
		"goal": "rescue", "count": 2, "civilians": 2, "third": "flawless", "prep": 14.0,
		"text": "Mahallede deprem. İki yaralı komşun yardım bekliyor: onları yeşil ışığa taşı."},
	{"id": "hospital", "title": "Hastane Tahliyesi", "map": 7, "disaster": 0, "severity": 2, "time": "morning",
		"goal": "rescue", "count": 3, "civilians": 3, "third": "flawless", "prep": 16.0,
		"text": "Hastanede büyük deprem. Üç hastanın hepsini dışarı çıkar."},
	{"id": "harbor_wave", "title": "Dalga Geliyor", "map": 5, "disaster": 2, "severity": 2, "time": "golden",
		"goal": "high", "height": 8.0, "civilians": 2, "third": "all", "prep": 16.0,
		"text": "Limana tsunami geliyor. Dalga vurduğunda 8 metrenin üstünde ol; yaralıları da kurtarabilirsen..."},
	{"id": "tower_fire", "title": "Alevler Arasında", "map": 0, "disaster": 6, "severity": 3, "time": "night",
		"goal": "fire", "count": 15, "civilians": 2, "third": "all", "prep": 14.0, "blackout": true, "extinguisher": true,
		"text": "Gökdelende yangın, elektrikler kesik. Yangın tüpüyle 15 alevi söndür."},
	{"id": "last_heli", "title": "Son Helikopter", "map": 12, "disaster": 5, "severity": 3, "time": "day",
		"goal": "heli", "civilians": 0, "third": "flawless", "prep": 18.0, "heli": true,
		"text": "Şehre dev tsunami geliyor. Tek çıkış: en yüksek çatıya gelen kurtarma helikopteri."},
]


static func get_mission(index: int) -> Dictionary:
	return LIST[index] if index >= 0 and index < LIST.size() else {}


static func stars(index: int) -> int:
	return Profile.mission_stars.get(LIST[index].id, 0)


static func unlocked(index: int) -> bool:
	return index == 0 or stars(index - 1) > 0


static func total_stars() -> int:
	var n := 0
	for k in LIST.size():
		n += stars(k)
	return n


## What the HUD shows as the goal (translated).
static func goal_text(m: Dictionary) -> String:
	match m.goal:
		"rescue":
			return Lang.t("%d yaralıyı yeşil ışığa taşı") % m.count
		"high":
			return Lang.t("Felaket bittiğinde %d m'nin üstünde ol") % int(m.height)
		"fire":
			return Lang.t("%d alevi söndür ve hayatta kal") % m.count
		"heli":
			return Lang.t("Kurtarma helikopterine bin")
	return Lang.t("Hayatta kal")


## Stars for how the player did (0: failed).
static func grade(m: Dictionary, player: Node, saved: int, civilians: int) -> int:
	if not player.alive and not player.rescued:
		return 0
	var met := false
	match m.goal:
		"rescue":
			met = saved >= m.count
		"high":
			met = player.global_position.y >= m.height or player.rescued
		"fire":
			met = player.fires_out_round >= m.count
		"heli":
			met = player.rescued
		_:
			met = true
	if not met:
		return 0
	var result := 1
	if player.health >= player.max_health * 0.5:
		result = 2
		var third: bool = player.damage_taken < 1.0 if m.third == "flawless" else saved >= civilians
		if third:
			result = 3
	return result


## Saves the best result; returns the coins earned for new stars.
static func record(index: int, got: int) -> int:
	var before := stars(index)
	if got <= before:
		return 0
	Profile.mission_stars[LIST[index].id] = got
	var coins := (got - before) * STAR_COINS
	Profile.coins += coins
	Profile.save_profile()
	return coins
