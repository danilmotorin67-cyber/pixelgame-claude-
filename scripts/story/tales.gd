class_name Tales

# Helga's twelve tales (27.3): one a visit, after a gift she liked that day, when its condition holds.


static func heard(n: int) -> bool:
	return Game.flag("tale_%d" % n)


static func on_gift(npc: String, reaction: String) -> void:
	if npc == "npc_helga" and reaction in ["love", "like"]:
		Game.counters["helga_liked_day"] = Clock.day_index


static func next_tale() -> int:
	if int(Game.counters.get("helga_liked_day", -1)) != Clock.day_index or Story.tale_day == Clock.day_index:
		return 0
	for row in Data.all("tales"):
		var n := int(row["n"])
		if not heard(n) and ConditionContext.check(str(row.get("when", ""))):
			return n
	return 0


static func tell() -> String:
	var n := next_tale()
	if n == 0:
		return Loc.t("tale.none")
	return tell_tale(n)


static func tell_tale(n: int) -> String:
	var row := Data.by_id("tales", "tale_%d" % n)
	Game.set_flag("tale_%d" % n)
	Collections.mark("tales", "tale_%d" % n)
	Story.tale_day = Clock.day_index
	Knowledge.add_points("rest", 1)
	if n == 6:
		Game.set_flag("pact_words")
		Story.add_page(8)
	Events.quest_event.emit("tale", str(n))
	return Loc.t("tale.told") % [n, Loc.t(str(row["title"])), Loc.t(str(row["text"]))]


static func count() -> int:
	var n := 0
	for i in 12:
		if heard(i + 1):
			n += 1
	return n
