class_name Bottles

# Message-in-a-bottle post of 18.6: forty letters, no repeats until all are read; No. 39 (Agatha's) comes last
# from the usual sources and No. 40 is Olaf's, mailed when the other 39 are in. After that a bottle stays sealed
# ("Unopened message in a bottle", Olaf loves them). No. 13 is Pim's, and comes as its own bottle for his quest.
const GUARANTEED := [13, 39, 40]


static func read_count() -> int:
	return Collections.found.get("bottles", {}).size()


static func is_read(n: int) -> bool:
	return Collections.has("bottles", "bottle_%d" % n)


static func next_letter() -> int:
	var open: Array = []
	for n in range(1, 41):
		if not is_read(n) and not GUARANTEED.has(n):
			open.append(n)
	if not open.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = posmod(Game.world_seed * 613 + read_count() * 97, 2147483647)
		return int(open[rng.randi_range(0, open.size() - 1)])
	if not is_read(39):
		return 39
	return 0


# Q on a bottle: read it (or keep it sealed once all forty are known).
static func open_one() -> String:
	if Inventory.count_of("message_bottle") <= 0:
		return Loc.t("bottle.none")
	var n := next_letter()
	Inventory.take("message_bottle", 1)
	if n == 0:
		Inventory.add("unopened_letter", 1)
		return Loc.t("bottle.all")
	return read(n)


static func read(n: int) -> String:
	Collections.mark("bottles", "bottle_%d" % n)
	Inventory.add("empty_bottle", 1)
	var row := Data.by_id("bottles", "bottle_%d" % n)
	Effects.apply(row.get("effects", []))
	Events.quest_event.emit("bottle_read", str(n))
	if read_count() >= 39 and not is_read(40):
		Collections.mark("bottles", "bottle_40")
		Mail.send("mail.bottle_40", [], 0, [["star_amber", 1]])
	return Loc.t("bottle.opened") % [n, Loc.t(str(row.get("text", "")))]


# Where bottles wash up (18.6): 10% a day in Wreck Bay, 3% on other beaches.
static func beach_chance(map_id: String) -> float:
	return 0.10 if map_id == "wreck_bay" else 0.03
