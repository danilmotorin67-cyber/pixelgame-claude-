extends Node

var open: bool = false
var last: String = ""

func exec(line: String) -> String:
	last = line
	var p := line.strip_edges().split(" ")
	if p.is_empty() or p[0] == "":
		return ""
	match p[0]:
		"time":
			if p.size() >= 2:
				var hm := p[1].split(":")
				Clock.set_time(int(hm[0]), int(hm[1]) if hm.size() > 1 else 0)
			return "time %02d:%02d" % [Clock.hour, Clock.minute]
		"day":
			if p.size() >= 2:
				Clock.day_index = maxi(0, Clock.day_index + int(p[1]))
			return "day_index=%d" % Clock.day_index
		"money":
			if p.size() >= 2:
				Economy.add(int(p[1]))
			return "money=%d" % Economy.money
		"give":
			if p.size() >= 2:
				var n := int(p[2]) if p.size() >= 3 else 1
				Inventory.add(p[1], n)
			return "ok"
		"deep":
			# Test mode of M8: the keeper breathes freely and may start at any level.
			Game.set_flag("test_deep")
			var start_level := int(p[1]) if p.size() >= 2 else 1
			if Deep.begin(start_level) != "ok":
				return "no"
			Router.goto_map("deep", Deep.cell_center(Deep.data["entry"]))
			return "deep %d" % start_level
		"weather":
			if p.size() >= 2:
				Weather.set_weather(p[1])
			return Weather.current
		"tp":
			if p.size() >= 2:
				Router.goto_map(p[1])
			return Router.current_map
		"light":
			if p.size() >= 2:
				Lighthouse.fire_power = float(p[1])
			return str(Lighthouse.fire_power)
		"peace":
			if p.size() >= 2:
				Graveyard.peace = float(p[1])
			return str(Graveyard.peace)
		"sea":
			if p.size() >= 2:
				Sea.mercy = float(p[1])
			return str(Sea.mercy)
		"god":
			return "ok"
		"hearts":
			if p.size() >= 3:
				Relationships.set_hearts(p[1], int(p[2]))
			return "%s: %d" % [p[1] if p.size() > 1 else "?", Relationships.hearts_of(p[1]) if p.size() > 1 else 0]
		"scene":
			if p.size() >= 2:
				Cutscenes.seen.erase(p[1])
				Cutscenes.play(p[1])
			return "scene"
		"flag":
			if p.size() >= 3 and p[1] == "set":
				Game.set_flag(p[2])
			return "ok"
		"act":
			if p.size() >= 2:
				Game.act = int(p[1])
			return "act=%d" % Game.act
		"where":
			if p.size() >= 2:
				return str(NPCs.where_is(p[1]))
			return str(NPCs.on_map(Router.current_map))
		"help":
			return "time day money give weather tp light peace sea god hearts scene flag act where"
		_:
			return "unknown: %s" % p[0]
