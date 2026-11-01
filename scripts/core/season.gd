extends RefCounted
## The season: a free reward track that starts over every month. Experience
## earned this month climbs its tiers; each tier pays coins and the last one an
## outfit you can't buy. (A paid track would sit beside it, see ROADMAP.md.)
## Saved in the "season" section of user://profile.cfg.

const Profile := preload("res://scripts/core/profile.gd")
const PATH := "user://profile.cfg"
const XP_PER_TIER := 300
const REWARDS := [100, 120, 150, 180, 200, 250, 300, 350, 400, 600]
const SKIN := "season"
const MONTHS := ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim",
		"Kasım", "Aralık"]

static var id := -1
static var xp := 0
static var claimed := 0


static func _current_id() -> int:
	var date := Time.get_date_dict_from_system()
	return int(date.year) * 12 + int(date.month) - 1


static func title() -> String:
	return "%s Sezonu" % MONTHS[_current_id() % 12]


static func load_season() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		id = config.get_value("season", "id", -1)
		xp = config.get_value("season", "xp", 0)
		claimed = config.get_value("season", "claimed", 0)
	_roll_over()


static func save_season() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("season", "id", id)
	config.set_value("season", "xp", xp)
	config.set_value("season", "claimed", claimed)
	config.save(PATH)


## A new month: the track starts over.
static func _roll_over() -> void:
	var now := _current_id()
	if id != now:
		id = now
		xp = 0
		claimed = 0


static func tier() -> int:
	return mini(xp / XP_PER_TIER, REWARDS.size())


## Adds experience; pays every tier reached. Returns toasts [[text, coins], ...].
static func add_xp(amount: int) -> Array:
	_roll_over()
	xp += amount
	var toasts: Array = []
	while claimed < tier():
		var reward: int = REWARDS[claimed]
		claimed += 1
		Profile.coins += reward
		var text := "Sezon kademesi %d / %d" % [claimed, REWARDS.size()]
		if claimed == REWARDS.size() and not Profile.has(SKIN):
			Profile.owned.append(SKIN)
			text += ": Sezon kıyafeti açıldı!"
		toasts.append([text, reward])
	Profile.save_profile()
	save_season()
	return toasts
