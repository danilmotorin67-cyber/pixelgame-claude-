extends Node

# The festivals of 24 (24.1): on the day the islanders go to the festival place; walking in starts the festival
# and stops the clock; walking out ends it and moves the clock to its closing hour. The activities — contests,
# minigames, the stalls — are once a festival each.
const RESIDENTS_SKIP := ["npc_fortuna", "npc_kai", "npc_tuve"]

var active: String = ""
var tokens_today: int = 0


func _ready() -> void:
	Events.map_entered.connect(on_map_entered)


func reset() -> void:
	active = ""
	tokens_today = 0


func today() -> Dictionary:
	return Clock.festival_on()


func info(id: String) -> Dictionary:
	return Data.by_id("festivals", id)


func name_of(id: String) -> String:
	return Loc.t("festival.%s.name" % id)


# Within the festival's hours (a festival running past midnight counts the small hours too).
func open_now(f: Dictionary = {}) -> bool:
	if f.is_empty():
		f = today()
	if f.is_empty():
		return false
	var start := int(f["start"])
	var end := int(f["end"])
	if end <= start:
		return Clock.hour >= start or Clock.hour < end
	return Clock.hour >= start and Clock.hour < end


func running() -> bool:
	return active != ""


func on_map_entered(map_id: String) -> void:
	var f := today()
	if running() and (f.is_empty() or str(f.get("map", "")) != map_id):
		finish_festival()
		return
	if not running() and not f.is_empty() and str(f.get("map", "")) == map_id and open_now(f):
		begin(str(f["id"]))


func begin(id: String) -> void:
	active = id
	tokens_today = 0
	Game.set_flag("festival_visited_%s_%d" % [id, Clock.year])
	Events.festival_started.emit(id)
	if id == "herring_fair" and Relationships.dating.size() >= 2 and not Game.flag("jealousy_%d" % Clock.year):
		jealousy()


# Leaving the festival: the clock jumps to the closing hour (the evening before midnight for the drowned night).
func finish_festival() -> int:
	if not running():
		return -1
	var f := info(active)
	active = ""
	var end := int(f.get("end", 18))
	if end >= 24:
		Clock.set_time(23, 50)
	else:
		Clock.set_time(end, 0)
	if str(f["id"]) == "bird_day":
		Game.set_flag("eiders_for_sale")
	return end


func done(act: String) -> bool:
	return Game.flag("fest_%s_%s_%d" % [active, act, Clock.year])


func _mark(act: String) -> void:
	Game.set_flag("fest_%s_%s_%d" % [active, act, Clock.year])


func activity(act: String) -> Dictionary:
	for a in info(active).get("activities", []):
		if str(a["id"]) == act:
			return a
	return {}


# Starts an activity: a Minigame to play, or the answer at once as a String.
func run(act: String) -> Variant:
	var a := activity(act)
	if a.is_empty():
		return ""
	if done(act) and str(a["kind"]) != "shop" and act != "tokens":
		return Loc.t("fest.done_already")
	if str(a["kind"]) == "minigame":
		var p: Dictionary = (a["params"] as Dictionary).duplicate()
		p["title"] = Loc.t(str(a["label"]))
		p["seed"] = Game.world_seed + Clock.day_index * 7 + act.hash()
		if act == "race":
			if Sea.boat not in ["sloop", "bot"]:
				return Loc.t("fest.no_sloop")
			var rivals: Array = [["npc_hedda", 2.9], ["npc_erland", 2.7], ["npc_nut", 2.6]]
			if Relationships.hearts_of("npc_einar") >= 6:
				rivals.append(["npc_einar", 2.4])
			p["rivals"] = rivals
		if act == "dance" and dance_partner() == "":
			return Loc.t("fest.dance_nobody")
		return Minigame.make(str(p.get("type", "timing")), p)
	return special(act)


func finish(act: String, game: Minigame) -> String:
	_mark(act)
	var won := game.won
	match act:
		"oar_run":
			if won:
				Economy.add(300)
				Relationships.add_friendship("npc_erland", 50)
			return Loc.t("fest.win" if won else "fest.lose") % "+300 кр"
		"eggs":
			var eggs := int(game.score)
			Inventory.add("egg_large", maxi(1, eggs / 10))
			# the most eggs of the day: the rivals gather about as many as the need
			if won:
				Inventory.add("nest_box", 2)
				Economy.add(500)
			return Loc.t("fest.eggs") % eggs + ("  " + Loc.t("fest.win") % "2 гнездовых ящика, 500 кр" if won else "")
		"birds":
			for bird in ["puffin", "guillemot", "loon", "eider", "cormorant"]:
				Collections.mark("birds", bird)
			Relationships.add_friendship("npc_liv", 150 if won else 60)
			return Loc.t("fest.birds")
		"dance":
			var partner := dance_partner()
			Relationships.add_friendship(partner, 250 if won else 120)
			return Loc.t("fest.dance") % Loc.t(str(NPCs.info(partner).get("name", partner)))
		"race":
			if won:
				Economy.add(2000)
				Inventory.add("regatta_cup", 1)
				Inventory.add("storm_sails", 1)
				Game.set_flag("regatta_won_%d" % Clock.year)
			return Loc.t("fest.win" if won else "fest.lose") % ("2 000 кр, кубок и штормовые паруса" if won else "место %d" % int(game.score))
		"herring":
			return _tokens(int(game.score) * 5)
		"boot":
			return _tokens(int(game.score) * 10)
		"cod":
			return _tokens(int(game.score) * 5)
		"gulls":
			return _tokens(int(game.score) * 8)
		"ice_fishing":
			var fish := int(game.score)
			if fish > 0:
				Inventory.add("fish_navaga", fish)
			if fish >= 8:
				Inventory.add("frozen_swordfish", 1)
				Economy.add(1500)
				return Loc.t("fest.fishing_win") % fish
			return Loc.t("fest.fishing_lose") % fish
		"skating":
			Skills.add_xp("foraging", 10)
			return Loc.t("fest.skating")
	return ""


func _tokens(n: int) -> String:
	Inventory.add("fair_token", n)
	tokens_today += n
	return Loc.t("fest.tokens_got") % n


# ---- activities without a minigame ----

func special(act: String, arg: String = "") -> String:
	match act:
		"blessing":
			_mark(act)
			Game.counters["boat_blessed_until"] = Clock.day_index + 7
			return Loc.t("fest.blessing")
		"decor":
			return decor_contest()
		"songs":
			_mark(act)
			for npc in residents():
				Relationships.add_friendship(npc, 20)
			return Loc.t("fest.songs")
		"bet":
			return bet(arg if arg != "" else "npc_hedda")
		"exhibit":
			return exhibit()
		"speech":
			_mark(act)
			return Loc.t("fest.speech_2" if Clock.year >= 2 else "fest.speech_1")
		"tokens":
			return token_shop(int(arg) if arg != "" else -1)
		"lanterns":
			if not (Inventory.take("paper_lantern", 1) or Inventory.take("paper", 1)):
				return Loc.t("fest.lantern_need")
			Knowledge.add_points("rest", 1)
			Game.counters["drowned_lanterns"] = int(Game.counters.get("drowned_lanterns", 0)) + 1
			return Loc.t("fest.lantern")
		"shadow_fair":
			return shadow_fair()
		"ghosts":
			_mark(act)
			for ghost in Graveyard.present_ghosts():
				Events.quest_event.emit("ghost_talk", str(ghost["id"]))
			return Loc.t("fest.ghosts")
		"sculpture":
			return sculpture(Inventory.selected_hotbar)
		"secret_gift":
			return secret_gift(Inventory.selected_hotbar)
		"dinner":
			return dinner(Inventory.selected_hotbar)
		"garlands":
			if done(act):
				return Loc.t("fest.done_already")
			if not Inventory.take("garland", 1):
				return Loc.t("fest.garlands_need")
			_mark(act)
			Game.set_flag("garlands_%d" % Clock.year)
			return Loc.t("fest.garlands")
	return ""


func residents() -> Array:
	var out: Array = []
	for npc in Data.all("npcs"):
		var id := str(npc["id"])
		if not bool(npc.get("visitor", false)) and id not in RESIDENTS_SKIP:
			out.append(id)
	return out


# Three decor items from the backpack, the most valuable: 10 each, their price, 15 more for boat decor.
func decor_contest() -> String:
	var picks: Array = []
	for i in Inventory.capacity:
		var id := str(Inventory.slots[i]["id"])
		if id != "" and str(Data.by_id("items", id).get("category", "")) == "decor" and not picks.has(id):
			picks.append(id)
	if picks.size() < 3:
		return Loc.t("fest.decor_need")
	picks.sort_custom(func(a: String, b: String) -> bool: return _decor_points(a) > _decor_points(b))
	var score := 0
	for i in 3:
		score += _decor_points(str(picks[i]))
	_mark("decor")
	var best := 0
	for r in activity("decor")["params"].get("rivals", []):
		best = maxi(best, int(r) + 2 * Clock.year)
	if score > best:
		Economy.add(1000)
		Inventory.add("solvik_pennant", 1)
		return Loc.t("fest.decor_win")
	return Loc.t("fest.decor_lose") % [score, best]


func _decor_points(id: String) -> int:
	var item := Data.by_id("items", id)
	return 10 + int(item.get("price", 0)) / 50 + (15 if "boat_decor" in item.get("tags", []) else 0) + 4 * int(item.get("tier", 0))


func dance_partner() -> String:
	var best := ""
	for npc in Data.all("npcs"):
		var id := str(npc["id"])
		if bool(npc.get("romance", false)) and Relationships.hearts_of(id) >= 4 \
				and (best == "" or Relationships.hearts_of(id) > Relationships.hearts_of(best)):
			best = id
	return best


# Without a sloop: 100 kr on a rival with Bjorn; the race is sailed without the keeper.
func bet(npc: String) -> String:
	if done("bet") or done("race"):
		return Loc.t("fest.done_already")
	if not Economy.pay(100):
		return Loc.t("story.deliver.missing") + " 100 кр"
	_mark("bet")
	var game := Minigame.make("race", {"length": 100, "rivals": [["npc_hedda", 2.9], ["npc_erland", 2.7], ["npc_nut", 2.6]],
		"seed": Game.world_seed + Clock.year})
	var winner := ""
	var best := 1e9
	while not game.done and game.time < 200.0:
		game.tick(0.1)
		for r in game.rivals:
			if float(r["done"]) >= 0.0 and float(r["done"]) < best:
				best = float(r["done"])
				winner = str(r["id"])
		if winner != "":
			break
	var name := Loc.t(str(NPCs.info(npc).get("name", npc)))
	if winner == npc:
		Economy.add(300)
		return Loc.t("fest.bet_won") % name
	return Loc.t("fest.bet_lost") % name


# The fair's exhibition: nine different items; their value, quality and variety of kinds make tokens.
func exhibit() -> String:
	if done("exhibit"):
		return Loc.t("fest.done_already")
	var seen := {}
	var kinds := {}
	var value := 0
	for i in Inventory.capacity:
		var id := str(Inventory.slots[i]["id"])
		if id == "" or seen.has(id) or seen.size() >= 9:
			continue
		var item := Data.by_id("items", id)
		if str(item.get("category", "")) in ["tool", "weapon", "quest"]:
			continue
		seen[id] = true
		kinds[str(item.get("category", ""))] = true
		value += int(item.get("price", 0)) / 10 + 10 * int(Inventory.slots[i]["quality"])
	if seen.size() < 9:
		return Loc.t("fest.exhibit_need")
	_mark("exhibit")
	var tokens := value + 20 * kinds.size()
	Inventory.add("fair_token", tokens)
	return Loc.t("fest.exhibit") % tokens


func token_shop(index: int) -> String:
	var stock: Array = Story.cfg("token_shop", [])
	if index < 0 or index >= stock.size():
		var lines: Array = []
		for i in stock.size():
			lines.append("%d. %s — %d" % [i + 1, Crafting.item_name(str(stock[i][0])), int(stock[i][1])])
		return "\n".join(lines)
	var price := int(stock[index][1])
	if not Inventory.take("fair_token", price):
		return Loc.t("fest.token_short")
	Inventory.add(str(stock[index][0]), 1)
	return Loc.t("fest.token_bought") % Crafting.item_name(str(stock[index][0]))


func shadow_fair() -> String:
	if not Game.flag("shadow_fair"):
		return Loc.t("fest.shadow_closed")
	if not Inventory.take("pearl", 1):
		return Loc.t("fest.shadow_need")
	var wares := ["black_pearl", "deep_quartz", "squid_beak", "scrimshaw", "old_crown"]
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed + Clock.day_index * 31 + Inventory.count_of("black_pearl") * 7, 2147483647)
	var ware: String = wares[rng.randi_range(0, wares.size() - 1)]
	Inventory.add(ware, 3 if ware == "old_crown" else 1)
	return Loc.t("fest.shadow") % Crafting.item_name(ware)


func sculpture(index: int) -> String:
	if done("sculpture"):
		return Loc.t("fest.done_already")
	var id := str(Inventory.slots[index]["id"])
	if id == "":
		return Loc.t("fest.sculpture_need")
	_mark("sculpture")
	var score := 10 + int(Data.by_id("items", id).get("price", 0)) / 40 + 8 * int(Inventory.slots[index]["quality"])
	var best := 0
	for r in activity("sculpture")["params"].get("rivals", []):
		best = maxi(best, int(r))
	if score > best:
		Relationships.add_friendship("npc_liv", 150)
		Relationships.add_friendship("npc_sigrid", 150)
		return Loc.t("fest.sculpture_win")
	return Loc.t("fest.sculpture_lose") % [score, best]


# ---- the Long Night: the secret giver and the shared supper ----

func secret_target(year: int = -1) -> String:
	if year < 0:
		year = Clock.year
	var list := residents()
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 71 + year * 13, 2147483647)
	return str(list[rng.randi_range(0, list.size() - 1)])


func secret_gift(index: int) -> String:
	if done("secret_gift"):
		return Loc.t("fest.done_already")
	var npc := secret_target()
	var name := Loc.t(str(NPCs.info(npc).get("name", npc)))
	var id := str(Inventory.slots[index]["id"])
	if id == "" or Relationships.taste(npc, id, int(Inventory.slots[index]["quality"])) not in ["love", "like", "neutral"]:
		return Loc.t("fest.gift_none") % name
	Inventory.take_slot(index, 1)
	_mark("secret_gift")
	Relationships.add_friendship(npc, 150)
	var gifts := ["jam", "honey_cakes", "wool", "amber", "tallow_candle"]
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed + Clock.year * 17, 2147483647)
	Inventory.add(str(gifts[rng.randi_range(0, gifts.size() - 1)]), 1)
	return Loc.t("fest.gift_done") % name


func dinner(index: int) -> String:
	if done("dinner"):
		return Loc.t("fest.done_already")
	var id := str(Inventory.slots[index]["id"])
	if id == "" or Data.by_id("items", id).get("edible", {}).is_empty() or str(Data.by_id("items", id).get("category", "")) != "food":
		return Loc.t("fest.dinner_need")
	Inventory.take_slot(index, 1)
	_mark("dinner")
	for npc in residents():
		Relationships.add_friendship(npc, 50)
	return Loc.t("fest.dinner") % Crafting.item_name(id)


func jealousy() -> void:
	Game.set_flag("jealousy_%d" % Clock.year)
	for npc in Relationships.dating:
		Relationships.add_friendship(str(npc), -Relationships.HEART)
	Achievements.unlock("ach_jealousy")
	Mail.send("fest.jealous")


# 24.1: on a festival day the islanders go to the festival place for its hours.
func schedule_entry(npc: String) -> Dictionary:
	var f := today()
	if f.is_empty() or NPCs.is_static(npc) or bool(NPCs.info(npc).get("visitor", false)) or npc in RESIDENTS_SKIP:
		return {}
	var stand: Array = f.get("stand", [30, 30])
	var h := absi(npc.hash())
	var tile := [int(stand[0]) + h % 9 - 4, int(stand[1]) + (h / 9) % 5 - 2]
	var start := maxi(6, int(f["start"]) - 1)
	var end := int(f["end"])
	var path: Array = [["06:00", "home", null, "down", "sleep"], ["%02d:00" % start, str(f["map"]), tile, "down", "idle"]]
	if end > int(f["start"]) and end < 24:
		path.append(["%02d:00" % end, "home", null, "down", "sleep"])
	return {"priority": 1000, "path": path}


# Night: the secret giver's letter comes a week before the Long Night.
func night() -> void:
	if Clock.season == "winter" and Clock.day == 18:
		var npc := secret_target()
		Mail.send("mail.secret_giver", [Loc.t(str(NPCs.info(npc).get("name", npc)))])


func serialize() -> Dictionary:
	return {"active": active}


func deserialize(d: Dictionary) -> void:
	reset()
	active = str(d.get("active", ""))
