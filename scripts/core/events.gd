extends RefCounted
## This week's event, the same for everyone (picked from the week number, weeks
## starting on Monday). An event makes some disasters commoner, pays double coins
## for rounds survived against them, and sells an outfit only that week.

const EVENTS := [
	{"name": "Tsunami Haftası", "desc": "Su felaketleri daha sık, onlardan sağ çıkana 2 kat coin",
			"disasters": [2, 5, 10, 12, 18], "kinds": ["tsunami", "hurricane"], "skin": "wave"},
	{"name": "Meteor Haftası", "desc": "Gökten taş yağıyor: meteor ve volkanda 2 kat coin",
			"disasters": [1, 16, 4, 24], "kinds": ["meteor", "bigmeteor", "volcano", "ufo"], "skin": "comet"},
	{"name": "Fırtına Haftası", "desc": "Hortum, kasırga, yıldırım ve dolu: 2 kat coin",
			"disasters": [3, 7, 12, 8], "kinds": ["tornado", "hurricane", "lightning", "hail"], "skin": "storm"},
	{"name": "Kaos Haftası", "desc": "Çifte felaketler çok sık, çiftelerde 2 kat coin",
			"disasters": [], "kinds": [], "combo": 0.75, "skin": "chaos"},
	{"name": "Ateş ve Buz", "desc": "Yangın, sıcak hava, kar fırtınası ve çığ: 2 kat coin",
			"disasters": [6, 14, 22, 21], "kinds": ["fire", "heat", "blizzard"], "skin": "frost"},
]
## How often an event's disasters are picked over a random one.
const BOOST := 0.45


static func week() -> int:
	# 1 January 1970 was a Thursday: shift so weeks turn over on Monday.
	return int((Time.get_unix_time_from_system() / 86400.0 + 3.0) / 7.0)


static func current() -> Dictionary:
	return EVENTS[week() % EVENTS.size()]


## Days until the event changes (for the menu banner).
static func days_left() -> int:
	var day := Time.get_unix_time_from_system() / 86400.0 + 3.0
	return 7 - int(fposmod(day, 7.0))


## Coins multiplier for a finished round (DisasterManager.last_round).
static func coin_multiplier(last_round: Dictionary) -> int:
	var event := current()
	if event.has("combo"):
		return 2 if last_round.get("double", false) else 1
	for kind: String in last_round.get("kinds", []):
		if kind in event.kinds:
			return 2
	return 1
