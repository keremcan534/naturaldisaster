extends RefCounted
## Long-term goals on top of the coins (profile.gd): experience and levels,
## three daily missions that change every day, and achievements. Fed once per
## round by record_round() with what happened; returns what was just completed
## (for the HUD's toasts). Saved in user://profile.cfg next to the profile.

const Profile := preload("res://scripts/core/profile.gd")
const PATH := "user://profile.cfg"

## XP per round: points / XP_DIVISOR, plus a little for taking part.
const XP_DIVISOR := 2
const XP_PER_ROUND := 10

## Daily missions: event, goal, reward. Events: "survive", "survive:<kind>",
## "round", "points", "streak", "high", "flawless", "team".
const MISSIONS := [
	{"id": "survive3", "text": "3 felaketten sağ çık", "event": "survive", "goal": 3, "reward": 60},
	{"id": "survive5", "text": "5 felaketten sağ çık", "event": "survive", "goal": 5, "reward": 100},
	{"id": "rounds5", "text": "5 tur oyna", "event": "round", "goal": 5, "reward": 50},
	{"id": "points600", "text": "Toplam 600 puan topla", "event": "points", "goal": 600, "reward": 80},
	{"id": "streak3", "text": "Üst üste 3 tur hayatta kal", "event": "streak", "goal": 3, "reward": 90},
	{"id": "high", "text": "Bir felakette 15 m yükseğe çık", "event": "high", "goal": 1, "reward": 60},
	{"id": "flawless", "text": "Bir turu hiç hasar almadan bitir", "event": "flawless", "goal": 1, "reward": 70},
	{"id": "team", "text": "Bütün takım hayatta kalsın", "event": "team", "goal": 1, "reward": 80},
	{"id": "tsunami", "text": "Bir tsunamiden sağ çık", "event": "survive:tsunami", "goal": 1, "reward": 60},
	{"id": "tornado", "text": "Bir hortumdan sağ çık", "event": "survive:tornado", "goal": 1, "reward": 60},
	{"id": "fire", "text": "Bir yangından sağ çık", "event": "survive:fire", "goal": 1, "reward": 60},
	{"id": "quake", "text": "Bir depremden sağ çık", "event": "survive:earthquake", "goal": 1, "reward": 50},
	{"id": "storm", "text": "Bir yıldırım fırtınasından sağ çık", "event": "survive:lightning", "goal": 1, "reward": 60},
]

## Achievements: unlocked once, for good, with a coin reward.
const ACHIEVEMENTS := [
	{"id": "first", "name": "İlk Adım", "text": "İlk felaketinden sağ çık", "event": "survive", "goal": 1, "reward": 50},
	{"id": "veteran", "name": "Kurt", "text": "50 felaketten sağ çık", "event": "survive", "goal": 50, "reward": 300},
	{"id": "surfer", "name": "Dalga Sörfçüsü", "text": "10 tsunamiden sağ çık", "event": "survive:tsunami", "goal": 10, "reward": 200},
	{"id": "captain", "name": "Kaptan", "text": "Dev tsunamiden sağ çık", "event": "survive:mega", "goal": 1, "reward": 150},
	{"id": "storm_chaser", "name": "Fırtına Avcısı", "text": "5 hortumdan sağ çık", "event": "survive:tornado", "goal": 5, "reward": 150},
	{"id": "firefighter", "name": "İtfaiyeci", "text": "5 yangından sağ çık", "event": "survive:fire", "goal": 5, "reward": 150},
	{"id": "double", "name": "Çifte Şans", "text": "Bir çifte felaketten sağ çık", "event": "survive:double", "goal": 1, "reward": 150},
	{"id": "unstoppable", "name": "Durdurulamaz", "text": "Üst üste 10 tur hayatta kal", "event": "streak", "goal": 10, "reward": 400},
	{"id": "flawless3", "name": "Kusursuz", "text": "3 turu hiç hasar almadan bitir", "event": "flawless", "goal": 3, "reward": 150},
	{"id": "teamplayer", "name": "Takım Oyuncusu", "text": "Bütün takım 3 kez hayatta kalsın", "event": "team", "goal": 3, "reward": 150},
	{"id": "climber", "name": "Dağcı", "text": "Bir felakette 25 m yükseğe çık", "event": "high25", "goal": 1, "reward": 100},
	{"id": "level10", "name": "Usta", "text": "10. seviyeye ulaş", "event": "level", "goal": 10, "reward": 300},
]

static var xp := 0
static var day := -1
## Today's missions: ids, and progress by id.
static var daily: Array = []
static var mission_progress := {}
static var missions_done: Array = []
## Achievement progress by id, and the unlocked ones.
static var counters := {}
static var unlocked: Array = []
static var tutorial_done := false


static func load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		xp = config.get_value("progress", "xp", 0)
		day = config.get_value("progress", "day", -1)
		daily = config.get_value("progress", "daily", [])
		mission_progress = config.get_value("progress", "mission_progress", {})
		missions_done = config.get_value("progress", "missions_done", [])
		counters = config.get_value("progress", "counters", {})
		unlocked = config.get_value("progress", "unlocked", [])
		tutorial_done = config.get_value("progress", "tutorial_done", false)
	_roll_daily()


## Writes the progress section (load first: the profile section lives there too).
static func save_progress() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("progress", "xp", xp)
	config.set_value("progress", "day", day)
	config.set_value("progress", "daily", daily)
	config.set_value("progress", "mission_progress", mission_progress)
	config.set_value("progress", "missions_done", missions_done)
	config.set_value("progress", "counters", counters)
	config.set_value("progress", "unlocked", unlocked)
	config.set_value("progress", "tutorial_done", tutorial_done)
	config.save(PATH)


## A new day brings three new missions (the same three for everyone that day).
static func _roll_daily() -> void:
	var today := int(Time.get_unix_time_from_system() / 86400.0)
	if today == day and daily.size() == 3:
		return
	day = today
	var rng := RandomNumberGenerator.new()
	rng.seed = today * 7919
	var ids: Array = []
	for m: Dictionary in MISSIONS:
		ids.append(m.id)
	daily = []
	while daily.size() < 3:
		var id: String = ids[rng.randi() % ids.size()]
		if id not in daily:
			daily.append(id)
	mission_progress = {}
	missions_done = []
	save_progress()


## Level from XP: each level needs a bit more than the last.
static func level() -> int:
	var lvl := 1
	var left := xp
	while left >= _need(lvl):
		left -= _need(lvl)
		lvl += 1
	return lvl


## XP into the current level, and needed for the next.
static func level_progress() -> Vector2i:
	var lvl := 1
	var left := xp
	while left >= _need(lvl):
		left -= _need(lvl)
		lvl += 1
	return Vector2i(left, _need(lvl))


static func _need(lvl: int) -> int:
	return 150 + 75 * (lvl - 1)


static func mission(id: String) -> Dictionary:
	for m: Dictionary in MISSIONS:
		if m.id == id:
			return m
	return {}


## After every round. info: survived, points, streak, height, flawless, team,
## kinds (Array), mega, double. Returns toasts: [[text, coins], ...].
static func record_round(info: Dictionary) -> Array:
	_roll_daily()
	var toasts: Array = []
	var before := level()
	xp += int(info.points) / XP_DIVISOR + XP_PER_ROUND
	var events := {"round": 1, "points": int(info.points)}
	if info.survived:
		events["survive"] = 1
		for kind: String in info.kinds:
			events["survive:" + kind] = 1
		if info.mega:
			events["survive:mega"] = 1
		if info.double:
			events["survive:double"] = 1
		if info.height >= 15.0:
			events["high"] = 1
		if info.height >= 25.0:
			events["high25"] = 1
		if info.flawless:
			events["flawless"] = 1
		if info.team:
			events["team"] = 1
	# Streak and level are "reach this", not "add this".
	var reach := {"streak": int(info.streak)}

	for id: String in daily:
		var m := mission(id)
		if m.is_empty() or id in missions_done:
			continue
		var value: int = mission_progress.get(id, 0)
		if reach.has(m.event):
			value = maxi(value, reach[m.event])
		else:
			value += events.get(m.event, 0)
		mission_progress[id] = value
		if value >= m.goal:
			missions_done.append(id)
			Profile.coins += m.reward
			toasts.append(["Görev tamam: " + m.text, m.reward])

	var after := level()
	if after > before:
		var bonus := 50 + 10 * after
		Profile.coins += bonus
		toasts.append(["Seviye atladın: %d. seviye!" % after, bonus])
	reach["level"] = after
	for a: Dictionary in ACHIEVEMENTS:
		if a.id in unlocked:
			continue
		var value: int = counters.get(a.id, 0)
		if reach.has(a.event):
			value = maxi(value, reach[a.event])
		else:
			value += events.get(a.event, 0)
		counters[a.id] = value
		if value >= a.goal:
			unlocked.append(a.id)
			Profile.coins += a.reward
			toasts.append(["Başarım: " + a.name, a.reward])
	Profile.save_profile()
	save_progress()
	return toasts
