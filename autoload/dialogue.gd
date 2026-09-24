extends Node

const FORTUNA_HINTS := 12


func greet(npc_id: String) -> String:
	return Loc.t("npc.%s.greet.generic" % npc_id.trim_prefix("npc_"))


# Fortuna speaks once a day: the first time the P2 line, later the hint of the day (4.2).
func fortuna_talk() -> String:
	var last := int(Game.counters.get("fortuna_last_day", -1))
	if last == Clock.day_index:
		return Loc.t("fortuna.again")
	var talks := int(Game.counters.get("fortuna_talks", 0))
	Game.counters["fortuna_last_day"] = Clock.day_index
	Game.counters["fortuna_talks"] = talks + 1
	Events.npc_talked.emit("npc_fortuna")
	if talks == 0:
		return Loc.t("fortuna.first")
	return hint_of_the_day()


func hint_of_the_day(index: int = -1) -> String:
	if index < 0:
		index = Clock.day_index
	return Loc.t("fortuna.hint.%d" % (1 + posmod(index * 5 + Game.world_seed, FORTUNA_HINTS)))


func fortuna_friendship() -> int:
	return mini(10, int(Game.counters.get("fortuna_talks", 0)) / 10 + int(Game.counters.get("fortuna_story", 0)))


func fortuna_reminder() -> String:
	return Loc.t("fortuna.reminder")
