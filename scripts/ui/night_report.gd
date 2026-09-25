class_name NightReport

const WEATHER_NAMES := {"clear": "ясно", "cloud": "облачно", "rain": "дождь", "fog": "туман",
	"storm": "шторм", "snow": "снег", "blizzard": "метель"}
const EVENTS := {"mechanism_stopped": "в 3:00 встал механизм", "glass_cracked": "в шторм треснуло стекло",
	"lightning_stairs": "молния ударила в лестницу", "lightning_masonry": "молния ударила в кладку",
	"lightning_paint": "молния опалила краску", "lightning_rod": "молния ударила в громоотвод",
	"lightning_gallery": "молния ударила в галерею"}


static func _delta(value: float) -> String:
	var n := int(round(value))
	return ("+%d" % n) if n > 0 else str(n)


# "The keeper's night report" of 6.1, built from the night resolution's report.
static func text(report: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("Ночной отчёт смотрителя · %s %d · %s" % [Loc.t("season." + str(report.get("season", "spring"))),
		int(report.get("day", 1)), WEATHER_NAMES.get(str(report.get("weather", "")), "")])
	if bool(report.get("fainted", false)):
		lines.append(str(report.get("faint_message", "Вы потеряли сознание.")))
		if int(report.get("money_lost", 0)) > 0:
			lines.append("Потеряно: %d кр." % int(report["money_lost"]))
	var light: Dictionary = report.get("lighthouse", {})
	if bool(light.get("no_fire", false)):
		lines.append("Маяк: огонь не требовался · Свет: %d" % int(round(float(light.get("light", 0.0)))))
	else:
		lines.append("Маяк: %d · Свет: %d%s" % [int(round(float(light.get("power", 0.0)))),
			int(round(float(light.get("light", 0.0)))), "" if bool(light.get("lit", false)) else " · ночь без огня"])
	for event in light.get("events", []):
		lines.append("  " + str(EVENTS.get(str(event), event)))
	var passed: Array[String] = []
	var wrecked: Array[String] = []
	for ship in light.get("ships", []):
		if bool(ship.get("wrecked", false)):
			wrecked.append("%s (тел: %d, ящиков: %d)" % [Loc.t(str(ship["name"])), int(ship.get("bodies", 0)),
				int(ship.get("crates", 0))])
		else:
			passed.append(Loc.t(str(ship["name"])))
	if not passed.is_empty():
		lines.append("Прошли: " + ", ".join(passed))
	if not wrecked.is_empty():
		lines.append("Крушение: " + ", ".join(wrecked))
	var arrived: Array = report.get("bodies_arrived", [])
	if not arrived.is_empty():
		lines.append("Море вернуло тел: %d. Над берегом кружат вороны." % arrived.size())
	if bool(report.get("bell", false)):
		lines.append("На рассвете звонил колокол погоста.")
	if int(report.get("unrest", 0)) > 0:
		lines.append("Беспокойство: в покойницкой всё сдвинуто, у погоста вянут посевы (%d)." % int(report["unrest"]))
	if bool(report.get("cabin", false)):
		lines.append("Ночь в каюте бота: проснулись в море, там же, где бросили якорь.")
	if bool(report.get("quiet_sleep", false)):
		lines.append("Тихий сон: погост спокоен, сил на 10% больше.")
	var started: Array = report.get("quests_started", [])
	for id in started:
		lines.append("Новое дело: " + Loc.t(str(Data.by_id("quests", str(id)).get("title", id))))
	var sales: Dictionary = report.get("sales", {})
	if int(sales.get("income", 0)) > 0:
		lines.append("Выручка «Чайки»: %d кр" % int(sales["income"]))
	elif bool(sales.get("storm", false)) and int(sales.get("waiting", 0)) > 0:
		lines.append("Шторм: «Чайка» не пришла, ящик ждёт до завтра")
	if int(report.get("stations_ready", 0)) > 0:
		lines.append("Станки: готово заданий — %d" % int(report["stations_ready"]))
	if int(report.get("mail", 0)) > 0:
		lines.append("В почтовом ящике писем: %d" % int(report["mail"]))
	var compass: Dictionary = report.get("compass", {})
	if not compass.is_empty():
		lines.append("Компас: Свет %s · Покой %s · Море %s" % [_delta(float(compass.get("light", 0.0))),
			_delta(float(compass.get("peace", 0.0))), _delta(float(compass.get("sea", 0.0)))])
	if bool(report.get("hmar_night", false)):
		lines.append("Сегодня ночью придёт Хмарь.")
	if report.has("fortuna"):
		lines.append("Фортуна: " + str(report["fortuna"]))
	lines.append("Игра сохранена." if bool(report.get("saved", false)) else "Ошибка сохранения.")
	return "\n".join(lines)
