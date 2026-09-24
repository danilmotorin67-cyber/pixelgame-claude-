class_name Kronvald

# Postgame trips to Kronvald (5.7): once a season, a day away — the Neptune office (ruined or still stamping),
# the market of rarities, the old colleagues.


static func key() -> String:
	return "kronvald_%d_%s" % [Clock.year, Clock.season]


static func can_travel() -> bool:
	return Game.act >= 5 and not Game.flag(key())


static func travel() -> String:
	if not can_travel():
		return Loc.t("kronvald.done")
	Game.set_flag(key())
	Clock.set_time(20, 0)
	Game.add_stat("kronvald_trips")
	var office := "kronvald.office.ruins" if Game.flag("neptune_ruined") else "kronvald.office.open"
	return "%s\n%s\n%s" % [Loc.t(office), Loc.t("kronvald.colleagues"), Loc.t("kronvald.market")]
