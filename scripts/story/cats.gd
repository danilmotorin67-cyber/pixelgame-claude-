class_name Cats

# The eight cat graves of 18.7: a small stone each; finding one is a journal entry and a candle.


static func found(n: int) -> bool:
	return Game.flag("cat_grave_%d" % n)


static func count() -> int:
	var n := 0
	for i in 8:
		if found(i + 1):
			n += 1
	return n


# Marks grave n; false when it was already found.
static func find(n: int) -> bool:
	if n < 1 or n > 8 or found(n):
		return false
	Game.set_flag("cat_grave_%d" % n)
	Collections.mark("cats", "cat_%d" % n)
	Knowledge.add_points("rest", 1)
	Events.quest_event.emit("cat", str(n))
	return true


static func text(n: int) -> String:
	return Loc.t("cat.found") % [n, Loc.t("cat.%d" % n)]
