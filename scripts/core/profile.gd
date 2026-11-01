extends RefCounted
## The player's progress between sessions: coins, records, what they bought in
## the shop and which outfit they wear. Saved in user://profile.cfg.
##
## Coins come from round points (see disaster_manager.gd) and a daily gift. The
## shop sells perks (small advantages that are always on once bought) and
## outfits (colors for the character shown in the menu and on the scoreboard).
## This is the in-game economy that rewarded ads or purchases can plug into later.

const PATH := "user://profile.cfg"
## Round points per coin.
const POINTS_PER_COIN := 5
const DAILY_GIFT := 100
const START_COINS := 100

const ITEMS := [
	{"id": "helmet", "kind": "perk", "name": "Baret", "price": 300,
			"desc": "Düşen enkaz %40 daha az can götürür"},
	{"id": "vest", "kind": "perk", "name": "Can yeleği", "price": 250,
			"desc": "Su altında iki kat uzun nefes, daha hızlı yüzme"},
	{"id": "boots", "kind": "perk", "name": "Yaylı ayakkabı", "price": 400,
			"desc": "Daha yükseğe zıpla, düşünce daha az hasar al"},
	{"id": "medkit", "kind": "perk", "name": "İlk yardım çantası", "price": 500,
			"desc": "Her tura 125 canla başla"},
	{"id": "runner", "kind": "perk", "name": "Koşu ayakkabısı", "price": 600,
			"desc": "%10 daha hızlı koş"},
	{"id": "parachute", "kind": "item", "name": "Paraşüt", "price": 350,
			"desc": "Her tur 1 kez: düşerken aç, süzülerek in"},
	{"id": "bandage", "kind": "item", "name": "Sargı bezi", "price": 250,
			"desc": "Her tur 2 tane: anında +40 can"},
	{"id": "hook", "kind": "item", "name": "Kanca", "price": 800,
			"desc": "Her tur 3 atış: baktığın yere kendini çek"},
	{"id": "glasses", "kind": "extra", "name": "Güneş gözlüğü", "price": 300, "desc": "Havalı görün"},
	{"id": "cap", "kind": "extra", "name": "Şapka", "price": 350, "desc": "Kıyafet renginde kep"},
	{"id": "backpack", "kind": "extra", "name": "Sırt çantası", "price": 450, "desc": "Kıyafet renginde çanta"},
	{"id": "blue", "kind": "skin", "name": "Mavi", "price": 0, "color": Color(0.2, 0.5, 0.95)},
	{"id": "red", "kind": "skin", "name": "Kırmızı", "price": 150, "color": Color(0.85, 0.2, 0.2)},
	{"id": "green", "kind": "skin", "name": "Yeşil", "price": 150, "color": Color(0.25, 0.7, 0.3)},
	{"id": "orange", "kind": "skin", "name": "Turuncu", "price": 200, "color": Color(1.0, 0.55, 0.1)},
	{"id": "purple", "kind": "skin", "name": "Mor", "price": 250, "color": Color(0.55, 0.3, 0.85)},
	{"id": "black", "kind": "skin", "name": "Gece", "price": 400, "color": Color(0.12, 0.12, 0.14)},
	{"id": "gold", "kind": "skin", "name": "Altın", "price": 1500, "color": Color(1.0, 0.78, 0.2)},
	# Event outfits: in the shop only during their week (events.gd).
	{"id": "wave", "kind": "skin", "name": "Dalga (etkinlik)", "price": 600, "color": Color(0.1, 0.75, 0.85), "event": true},
	{"id": "comet", "kind": "skin", "name": "Kuyruklu yıldız (etkinlik)", "price": 600, "color": Color(0.95, 0.35, 0.1), "event": true},
	{"id": "storm", "kind": "skin", "name": "Fırtına (etkinlik)", "price": 600, "color": Color(0.35, 0.38, 0.6), "event": true},
	{"id": "chaos", "kind": "skin", "name": "Kaos (etkinlik)", "price": 600, "color": Color(0.85, 0.1, 0.45), "event": true},
	{"id": "frost", "kind": "skin", "name": "Ayaz (etkinlik)", "price": 600, "color": Color(0.75, 0.9, 1.0), "event": true},
]

static var player_name := "Sen"
static var coins := START_COINS
static var best_score := 0
static var rounds_played := 0
static var rounds_survived := 0
static var owned: Array = ["blue"]
static var skin := "blue"
## Extras (glasses, cap, backpack) the player has on.
static var wearing: Array = []
## Day number (days since 1970) of the last daily gift.
static var gift_day := -1


static func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	player_name = config.get_value("profile", "name", player_name)
	coins = config.get_value("profile", "coins", coins)
	best_score = config.get_value("profile", "best_score", 0)
	rounds_played = config.get_value("profile", "rounds_played", 0)
	rounds_survived = config.get_value("profile", "rounds_survived", 0)
	owned = config.get_value("profile", "owned", owned)
	skin = config.get_value("profile", "skin", skin)
	wearing = config.get_value("profile", "wearing", [])
	gift_day = config.get_value("profile", "gift_day", -1)


static func save_profile() -> void:
	var config := ConfigFile.new()
	# Keep the other sections (progress.gd's).
	config.load(PATH)
	config.set_value("profile", "name", player_name)
	config.set_value("profile", "coins", coins)
	config.set_value("profile", "best_score", best_score)
	config.set_value("profile", "rounds_played", rounds_played)
	config.set_value("profile", "rounds_survived", rounds_survived)
	config.set_value("profile", "owned", owned)
	config.set_value("profile", "skin", skin)
	config.set_value("profile", "wearing", wearing)
	config.set_value("profile", "gift_day", gift_day)
	config.save(PATH)


static func item(id: String) -> Dictionary:
	for entry: Dictionary in ITEMS:
		if entry.id == id:
			return entry
	return {}


static func has(id: String) -> bool:
	return id in owned


static func buy(id: String) -> bool:
	var entry := item(id)
	if entry.is_empty() or has(id) or coins < entry.price:
		return false
	coins -= entry.price
	owned.append(id)
	if entry.kind == "skin":
		skin = id
	elif entry.kind == "extra":
		wearing.append(id)
	save_profile()
	return true


## Puts an owned extra on or takes it off.
static func toggle_extra(id: String) -> void:
	if id in wearing:
		wearing.erase(id)
	elif has(id):
		wearing.append(id)
	save_profile()


static func skin_color() -> Color:
	var entry := item(skin)
	return entry.color if not entry.is_empty() else Color(0.2, 0.5, 0.95)


static func _today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


static func gift_ready() -> bool:
	return gift_day != _today()


static func claim_gift() -> int:
	if not gift_ready():
		return 0
	gift_day = _today()
	coins += DAILY_GIFT
	save_profile()
	return DAILY_GIFT


## After every round: the player's points become coins and records.
static func add_round(points: int, survived: bool, session_score: int, multiplier := 1) -> int:
	var earned := points / POINTS_PER_COIN * multiplier
	coins += earned
	rounds_played += 1
	if survived:
		rounds_survived += 1
	best_score = maxi(best_score, session_score)
	save_profile()
	return earned
