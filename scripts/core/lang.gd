extends RefCounted
## English for the interface. The game is written in Turkish; this table maps
## Turkish text to English and is registered with the TranslationServer, so
## labels and buttons whose whole text is in it switch language by themselves.
## Text built with numbers or names goes through t() first (its pattern is the
## key, e.g. "Puan: %d"). Settings.language picks "tr" or "en".

const EN := {
	# Main menu, pause, settings, shop, goals.
	"DOĞAL AFET": "NATURAL DISASTER",
	"Felaketlerden sağ çık, puanları topla!": "Survive the disasters, collect points!",
	"OYNA": "PLAY", "GÖREVLER": "GOALS", "MAĞAZA": "SHOP", "AYARLAR": "SETTINGS", "Ayarlar": "Settings",
	"GERİ": "BACK", "MENÜ": "MENU", "DEVAM": "RESUME", "ANA MENÜ": "MAIN MENU", "FOTOĞRAF ÇEK": "TAKE PHOTO",
	"Oyun arkada devam ediyor": "The game keeps going behind this menu",
	"Kapat": "Close", "Tuşları yerleştir": "Place the buttons", "SONRAKİ": "NEXT", "BAŞLA!": "START!",
	"MOD: %s  >": "MODE: %s  >", "GÜNLÜK HEDİYE (%d. gün / 7): +%d": "DAILY GIFT (day %d / 7): +%d",
	"HAFTANIN ETKİNLİĞİ: %s (%d gün)\n%s": "EVENT OF THE WEEK: %s (%d days)\n%s",
	"Seviye %d   ·   %d / %d XP": "Level %d   ·   %d / %d XP",
	"En yüksek puan: %d     Hayatta kalınan tur: %d / %d": "Best score: %d     Rounds survived: %d / %d",
	"Günlük görevler (her gün yenilenir)": "Daily missions (new every day)", "Başarımlar": "Achievements",
	"İstatistikler": "Statistics", "TAMAM": "DONE", "AÇILDI": "UNLOCKED", "kademe": "tier",
	"Sonraki kademe: %d / %d XP  →  +%d coin%s": "Next tier: %d / %d XP  →  +%d coins%s",
	" ve Sezon kıyafeti": " and the Season outfit", "Sezon kıyafeti kazanıldı!": "Season outfit won!",
	"Oynanan tur: %d   ·   Hayatta kalınan: %d": "Rounds played: %d   ·   Survived: %d",
	"En uzun seri: %d   ·   En yüksek puan: %d": "Longest streak: %d   ·   Best score: %d",
	"Kazanılan coin: %d   ·   Helikopterle kurtulma: %d   ·   Kurtarılan arkadaş: %d":
			"Coins earned: %d   ·   Helicopter rescues: %d   ·   Teammates helped: %d",
	"Güçlendirmeler (alınca hep açık)": "Perks (always on once bought)",
	"Eşyalar (her tur yenilenir, tuşla kullanılır)": "Items (refilled every round, used with a button)",
	"Aksesuarlar (tak / çıkar)": "Accessories (put on / take off)", "Kıyafetler": "Outfits",
	"GİYİLDİ": "WORN", "GİY": "WEAR", "ALINDI": "OWNED", "TAK": "PUT ON", "ÇIKAR": "TAKE OFF", "SATIN AL  %d": "BUY  %d",
	"Bakış hassasiyeti": "Look sensitivity", "Ses": "Sound", "Müzik": "Music", "Tuş boyutu": "Button size",
	"Arayüz boyutu": "Interface size", "Dikey bakışı ters çevir": "Invert vertical look", "Otomatik zıpla": "Auto-jump",
	"Üçüncü şahıs kamera (V)": "Third-person camera (V)", "Renk körü modu": "Colorblind mode",
	"Jiroskopla nişan (telefonu çevirerek bak)": "Gyro aim (turn the phone to look)",
	"Bot seviyesi": "Bot level", "Kolay": "Easy", "Normal": "Normal", "Zor": "Hard",
	"Performans bilgisi göster (takılma olursa ekran görüntüsü at)": "Show performance info (send a screenshot if it stutters)",
	"Grafik kalitesi (takılıyorsa düşür)": "Graphics quality (lower it if it stutters)",
	"Otomatik": "Auto", "Düşük": "Low", "Orta": "Medium", "Yüksek": "High", "Adın": "Your name", "Dil": "Language",
	# Modes and events.
	"Klasik": "Classic", "Kaos": "Chaos", "Sadece Su": "Water Only", "Son Kalan": "Last Standing",
	"Rastgele felaketler, bazen çifte felaket": "Random disasters, sometimes two at once",
	"Her tur iki felaket birden": "Two disasters every round",
	"Hepsi Kıyamet şiddetinde, molalar kısa": "All at Apocalypse strength, short breaks",
	"Tsunami, sel, kasırga, çamur ve çığ": "Tsunamis, floods, hurricanes, mud and avalanches",
	"Ölen geri dönmez; en son kalan kazanır": "The fallen stay out; the last one standing wins",
	"Tsunami Haftası": "Tsunami Week", "Meteor Haftası": "Meteor Week", "Fırtına Haftası": "Storm Week",
	"Kaos Haftası": "Chaos Week", "Ateş ve Buz": "Fire and Ice",
	"Su felaketleri daha sık, onlardan sağ çıkana 2 kat coin": "Water disasters more often, double coins for surviving them",
	"Gökten taş yağıyor: meteor ve volkanda 2 kat coin": "Rocks from the sky: double coins in meteors and volcanoes",
	"Hortum, kasırga, yıldırım ve dolu: 2 kat coin": "Tornadoes, hurricanes, lightning and hail: double coins",
	"Çifte felaketler çok sık, çiftelerde 2 kat coin": "Double disasters very often, double coins in them",
	"Yangın, sıcak hava, kar fırtınası ve çığ: 2 kat coin": "Fire, heat, blizzards and avalanches: double coins",
	# Shop items.
	"Baret": "Hard hat", "Can yeleği": "Life vest", "Yaylı ayakkabı": "Spring shoes", "İlk yardım çantası": "First aid kit",
	"Koşu ayakkabısı": "Running shoes", "Paraşüt": "Parachute", "Sargı bezi": "Bandage", "Kanca": "Grappling hook",
	"Güneş gözlüğü": "Sunglasses", "Şapka": "Cap", "Sırt çantası": "Backpack",
	"Mavi": "Blue", "Kırmızı": "Red", "Yeşil": "Green", "Turuncu": "Orange", "Mor": "Purple", "Gece": "Night", "Altın": "Gold",
	"Düşen enkaz %40 daha az can götürür": "Falling debris does 40% less damage",
	"Su altında iki kat uzun nefes, daha hızlı yüzme": "Twice the breath under water, faster swimming",
	"Daha yükseğe zıpla, düşünce daha az hasar al": "Jump higher, take less damage from falls",
	"Her tura 125 canla başla": "Start every round with 125 health",
	"%10 daha hızlı koş": "Run 10% faster",
	"Her tur 1 kez: düşerken aç, süzülerek in": "Once a round: open it while falling and glide down",
	"Her tur 2 tane: anında +40 can": "Two a round: +40 health at once",
	"Her tur 3 atış: baktığın yere kendini çek": "Three shots a round: pull yourself to where you look",
	"Havalı görün": "Look cool", "Kıyafet renginde kep": "A cap in your outfit's color",
	"Kıyafet renginde çanta": "A backpack in your outfit's color",
	# Tutorial.
	"Hoş geldin!": "Welcome!", "Nasıl hayatta kalırsın?": "How to survive", "Kontroller": "Controls", "Ödüller": "Rewards",
	"Her turda adaya bir felaket gelir. Uyarı kartı çıkınca ne yapman gerektiği yazar: oku ve hemen harekete geç!":
			"Every round a disaster hits the island. The warning card tells you what to do: read it and move!",
	"Tsunami ve sel: yükseğe, çatıya çık.\nDeprem ve yangın: binalardan uzak, açık alana.\nDolu, yıldırım, asit, kum: kapalı bir yere gir.\nHortum ve volkan: uzaklaş. Kırmızı ok tehlikeyi gösterir.":
			"Tsunami and flood: get high, onto a roof.\nEarthquake and fire: away from buildings, into the open.\nHail, lightning, acid, sand: get under cover.\nTornado and volcano: get away. The red arrow points at the danger.",
	"Sol başparmak: hareket. Tam ileri itersen koşarsın; yukarıdaki kilide çekip bırakırsan otomatik koşarsın.\nSağ başparmak: ekranı kaydırarak etrafa bak, büyük tuşla zıpla.\nMerdivenlere doğru yürüyerek tırman.":
			"Left thumb: move. Push all the way to run; drag up onto the lock and let go to keep running.\nRight thumb: drag to look around, the big button jumps.\nWalk into ladders to climb.",
	"WASD ile yürü, Shift ile koş, Space ile zıpla, fareyle bak.\nMerdivenlere doğru yürüyerek tırman. Esc menüyü açar.":
			"WASD to walk, Shift to run, Space to jump, mouse to look.\nWalk into ladders to climb. Esc opens the menu.",
	"Hayatta kaldıkça puan, coin ve XP kazanırsın. Günlük görevleri ve başarımları tamamla, mağazadan güçlendirme ve kıyafet al.\nTakım arkadaşların da hayatta kalmaya çalışıyor: hepiniz kurtulursanız bonus var!":
			"Staying alive earns points, coins and XP. Finish daily missions and achievements, buy perks and outfits in the shop.\nYour teammates are trying to survive too: everyone making it pays a bonus!",
	# HUD.
	"Puan: %d": "Score: %d", "Hayatta: %d / %d": "Alive: %d / %d", "! UYARI !": "! WARNING !",
	"Öldün! Sonraki turu bekle": "You died! Wait for the next round", "Öldün! İzliyorsun: %s": "You died! Watching: %s",
	"Elendin! Son kalan belirlenince döneceksin": "You're out! You'll be back once someone is the last standing",
	"SKOR TABLOSU": "SCOREBOARD", "Kazandın:  +": "You earned:  +", "SONRAKİ HARİTA: OY VER": "NEXT MAP: VOTE",
	"MVP: %s  (+%d)": "MVP: %s  (+%d)", "En yükseğe çıkan: %s  (%d m)": "Highest climb: %s  (%d m)",
	"%s ayağa kalktı! +25 puan": "%s is back on their feet! +25 points",
	"KURTARILDIN! Bu tur artık hasar almazsın": "RESCUED! Nothing can hurt you this round",
	"Kurtarma helikopteri geliyor! En yüksek çatıya çık": "Rescue helicopter coming! Get to the highest roof",
	"Reklam izle: +%d coin": "Watch an ad: +%d coins", "Reklam ödülü": "Ad reward",
	"Fotoğraf kaydedildi": "Photo saved", "Fotoğraf kaydedilemedi": "Couldn't save the photo",
	"Beni takip edin!": "Follow me!", "Yakında kimse yok": "Nobody nearby", "Takım: kendi başınıza": "Team: on your own",
	" elendi": " is out", "%s kurtarıldı!": "%s was rescued!",
	"Takip": "Follow", "Selam": "Wave", "Kamera": "Camera", "Çömel": "Crouch", "Sargı": "Bandage",
	"WASD: yürü  Shift: koş  Space: zıpla  C: çömel  F: takip et  G: selam  V: kamera  P: fotoğraf  Esc: menü":
			"WASD: walk  Shift: run  Space: jump  C: crouch  F: follow me  G: wave  V: camera  P: photo  Esc: menu",
	# Round status.
	"Harita: %s - sonraki felakete hazırlan": "Map: %s - get ready for the next disaster",
	"UYARI: %s geliyor!": "WARNING: %s is coming!", "UYARI: ÇİFTE FELAKET! %s + %s": "WARNING: DOUBLE DISASTER! %s + %s",
	"Çifte felaket! ": "Double disaster! ", "Hayatta kaldın!": "You survived!", "Öldün!": "You died!",
	"Hayatta kalanlar: %d / %d": "Survivors: %d / %d", "SON KALAN: %s! Herkes geri dönüyor": "LAST STANDING: %s! Everyone's back",
	"Kimse kalmadı! Herkes geri dönüyor": "Nobody left! Everyone's back",
	"Şiddetli": "Severe", "Felaket": "Catastrophic", "Kıyamet": "Apocalyptic",
	# Maps.
	"Gökdelen": "Skyscraper", "Bahçeli Ev": "Garden House", "Apartman": "Apartments", "Mahalle": "Neighbourhood",
	"AVM": "Mall", "Liman": "Harbour", "Okul": "School", "Hastane": "Hospital", "Stadyum": "Stadium", "Köy": "Village",
	"Kamp Alanı": "Campsite", "Kale": "Castle", "Şehir Merkezi": "City Centre", "Havalimanı": "Airport",
	"Lunapark": "Funfair", "Nehir ve Köprü": "River and Bridge", "Çöl Kasabası": "Desert Town",
	"Kayak Merkezi": "Ski Resort", "Petrol Platformu": "Oil Rig", "Baraj": "Dam", "Baraj Patlaması": "Dam Burst",
	"Baraj çatlıyor! Dev su seli vadiden geliyor: hemen yükseğe çık!": "The dam is cracking! A huge flood is coming down the valley: get high now!",
	# Disasters.
	"Deprem": "Earthquake", "Meteor Yağmuru": "Meteor Shower", "Tsunami": "Tsunami", "Hortum": "Tornado",
	"Volkan": "Volcano", "Dev Tsunami": "Mega Tsunami", "Yangın": "Fire", "Yıldırım Fırtınası": "Lightning Storm",
	"Dolu": "Hail", "Kum Fırtınası": "Sandstorm", "Sel": "Flood", "Asit Yağmuru": "Acid Rain", "Kasırga": "Hurricane",
	"Obruk": "Sinkhole", "Isı Dalgası": "Heat Wave", "Zehirli Gaz": "Poison Gas", "Dev Meteor": "Giant Meteor",
	"Güneş Patlaması": "Solar Flare", "Dalga Serisi": "Wave Series", "Kül Yağmuru": "Ash Fall",
	"Çamur Heyelanı": "Mudslide", "Çığ": "Avalanche", "Kar Fırtınası": "Blizzard", "Kara Delik": "Black Hole",
	"UFO İstilası": "UFO Invasion",
	"Binalardan uzak dur!": "Stay away from buildings!", "Sağlam bir yere saklan!": "Hide somewhere solid!",
	"Üst katlara ya da çatıya çık!": "Go up to the top floors or the roof!", "Hortumun yolundan çekil!": "Get out of the tornado's way!",
	"Lavdan ve düşen kayalardan uzak dur!": "Keep away from lava and falling rocks!",
	"Dev dalga ve gemi geliyor! En yüksek binanın tepesine çık!": "A giant wave and a ship are coming! Get on top of the tallest building!",
	"Binalarda yangın çıktı! Alevlerden ve binalardan uzak dur!": "Buildings are on fire! Keep away from flames and buildings!",
	"Yıldırımlar düşecek! Açıkta ve çatıda durma, içeri gir!": "Lightning is coming! Don't stand in the open or on roofs, get inside!",
	"Dolu geliyor! Bir çatının altına gir!": "Hail is coming! Get under a roof!",
	"Kum fırtınası! İçeri gir, açıkta kalma!": "Sandstorm! Get inside, don't stay in the open!",
	"Sel geliyor! Su yükseliyor, üst katlara çık!": "Flood! The water is rising, go to the upper floors!",
	"Asit yağmuru! Kapalı bir yere sığın!": "Acid rain! Take cover indoors!",
	"Kasırga geliyor! Fırtına ve deniz kabarması: binaya gir, üst kata çık!": "Hurricane! Storm and surge: get in a building, go upstairs!",
	"Yer çöküyor! Çöken yerden ve kenarındaki binalardan uzak dur!": "The ground is caving in! Keep away from the hole and the buildings at its edge!",
	"Isı dalgası! Gölgeye, kapalı bir yere gir!": "Heat wave! Get into the shade, indoors!",
	"Zehirli gaz yayılıyor! Yere çöküyor: yükseğe, üst katlara çık!": "Poison gas is spreading! It sinks: get high, to the upper floors!",
	"Dev bir meteor düşüyor! Kırmızı halkanın dışına kaç!": "A giant meteor is falling! Run out of the red ring!",
	"Güneş fırtınası! Elektrik gidiyor, ışınım dalgaları geliyor: çatı altında kal!": "Solar storm! The power goes out, radiation is coming: stay under a roof!",
	"Art arda üç dalga geliyor! Yüksekte kal, dalgalar arasında inme!": "Three waves in a row! Stay high, don't come down between them!",
	"Volkanik kül yağıyor! Kapalı yere gir ama zayıf çatılardan uzak dur!": "Volcanic ash is falling! Get inside, but not under weak roofs!",
	"Heyelan! Çamur seli geliyor: yükseğe çık!": "Mudslide! A flood of mud is coming: get high!",
	"Çığ geliyor! Bir binaya, yukarıya çık!": "Avalanche! Get into a building, go up!",
	"Kar fırtınası! Dışarıda donarsın: kapalı bir yere gir!": "Blizzard! You'll freeze outside: get indoors!",
	"Gökyüzünde bir kara delik açılıyor! Her şeyi çekiyor: uzaklaş, sağlam bir yere tutun!": "A black hole is opening in the sky! It pulls everything: get away, hold on to something solid!",
	"Gökyüzünde bir UFO! Işığına yakalanma, saklan!": "A UFO in the sky! Don't get caught in its beam, hide!",
}

static var _english: Translation


## Switches the interface language ("tr" or "en"). The English table is only
## registered while English is on: Godot falls back to English translations
## for a locale that has none, which would turn Turkish into English.
static func apply(language: String) -> void:
	if _english == null:
		_english = Translation.new()
		_english.locale = "en"
		for key: String in EN:
			_english.add_message(key, EN[key])
	TranslationServer.remove_translation(_english)
	if language == "en":
		TranslationServer.add_translation(_english)
	TranslationServer.set_locale(language)


## The current language's version of a text (or the text itself).
static func t(text: String) -> String:
	return String(TranslationServer.translate(text))
