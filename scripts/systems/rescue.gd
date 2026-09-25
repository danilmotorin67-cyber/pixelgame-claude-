class_name Rescue

# 10.12: once the Guild House's rescue station stands, a wreck rings the bell at 3:00. A keeper asleep in the
# watch room (or awake) may launch the boat — row out and throw the ring (a timing game), each hit a life;
# asleep at home, the station's crew goes out alone and saves each with 30% + 5% per Seafaring level.
# The saved are one body fewer; they live 3 days at the tavern, send a gift, sometimes a recipe or a story;
# +10 honour and +3 mercy each. The Rescuer (Seafaring 10) brings back 2 more and doubles the rewards.

static func active() -> bool:
	return Game.flag("rescue_station")


# Night step: tonight's wrecks either wait for the keeper's choice in the morning or go to the crew.
static func night(night_index: int, watch_sleep: bool) -> int:
	if not active():
		return 0
	var saved := 0
	for wreck in Lighthouse.wrecks:
		if int(wreck["day"]) != night_index or survivors(str(wreck["ship"])) <= 0:
			continue
		if watch_sleep:
			Lighthouse.rescue_pending.append({"ship": str(wreck["ship"]), "type": str(wreck["type"]), "day": night_index})
		else:
			saved += crew_rescue(str(wreck["ship"]), night_index)
	return saved


static func crew_chance() -> float:
	return 0.3 + 0.05 * float(Skills.level("seafaring"))


# The ones still in the water: bodies of that ship not yet washed ashore.
static func survivors(ship: String) -> int:
	var n := 0
	for entry in Graveyard.incoming:
		if str(entry["ship"]) == ship:
			n += 1
	return n


static func crew_rescue(ship: String, night_index: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = posmod(Game.world_seed * 1709 + night_index * 13 + ship.hash(), 2147483647)
	var n := 0
	for entry in Graveyard.incoming.duplicate():
		if str(entry["ship"]) == ship and rng.randf() < crew_chance():
			_save(entry, false)
			n += 1
	if n > 0:
		Mail.send("mail.rescue_crew", [Loc.t(ship), n])
	return n


# The morning's choice for the first pending wreck: launch the boat (a game) or leave it to the crew.
static func pending() -> Dictionary:
	return Lighthouse.rescue_pending[0] if not Lighthouse.rescue_pending.is_empty() else {}


static func game_for(wreck: Dictionary) -> Minigame:
	var people := survivors(str(wreck["ship"]))
	var rough := Weather.current in ["storm", "blizzard"] or bool(wreck.get("storm", false))
	return Minigame.make("timing", {"title": "Спасательный круг", "rounds": maxi(people, 1),
		"speed": 1.0 if rough else 0.8, "width": 0.2, "limit": 90.0,
		"seed": posmod(Game.world_seed + int(wreck["day"]) * 7, 2147483647)})


# The ring found `hits` people: each saved (up to those in the water), the Rescuer brings two more.
static func resolve(wreck: Dictionary, hits: int) -> int:
	Lighthouse.rescue_pending.erase(wreck)
	var n := 0
	for entry in Graveyard.incoming.duplicate():
		if n >= hits:
			break
		if str(entry["ship"]) == str(wreck["ship"]):
			_save(entry, true)
			n += 1
	if n > 0 and Skills.has_profession("rescuer"):
		for extra in 2:
			Lighthouse.rescue_guests.append({"name": Graveyard.FIRST_NAMES[posmod(int(wreck["day"]) + extra * 7, Graveyard.FIRST_NAMES.size())],
				"ship": str(wreck["ship"]), "until": Clock.day_index + 3, "gift": false})
	Game.add_stat("rescued", n)
	Skills.add_xp("seafaring", 20 * n)
	return n


static func decline(wreck: Dictionary) -> int:
	Lighthouse.rescue_pending.erase(wreck)
	return crew_rescue(str(wreck["ship"]), int(wreck["day"]))


static func _save(entry: Dictionary, by_keeper: bool) -> void:
	Graveyard.incoming.erase(entry)
	var name := str(entry.get("registry", ""))
	for person in Graveyard.registry_extra.duplicate():
		if str(person["id"]) == str(entry.get("registry", "")):
			name = str(person["name"])
			Graveyard.registry_extra.erase(person)
	var mult := 2 if by_keeper and Skills.has_profession("rescuer") else 1
	Game.add_honor(10 * mult)
	Sea.add_mercy(3.0 * mult)
	Lighthouse.rescue_guests.append({"name": name, "ship": str(entry["ship"]), "until": Clock.day_index + 3, "gift": false})
	Events.quest_event.emit("rescued", str(entry["ship"]))


# Each guest sends a thank-you once (a gift; now and then a recipe or a story) and leaves after 3 days.
static func guests_night() -> void:
	var gifts: Array = Game.balance("rescue_gifts", ["tea", "rum", "spices", "coffee", "salted_herring", "old_sea_chart"])
	for guest in Lighthouse.rescue_guests.duplicate():
		if not bool(guest["gift"]):
			guest["gift"] = true
			var rng := RandomNumberGenerator.new()
			rng.seed = posmod(Game.world_seed * 31 + str(guest["name"]).hash() + Clock.day_index, 2147483647)
			var item := str(gifts[rng.randi_range(0, gifts.size() - 1)])
			var roll := rng.randf()
			if roll < 0.2:
				var recipe := Crafting.gazette_recipe()
				Mail.send("mail.rescue_recipe", [str(guest["name"]), Crafting.item_name(str(Crafting._recipe(recipe)["out"][0])) if recipe != "" else "—"], 0, [[item, 1]])
			elif roll < 0.5:
				Mail.send("mail.rescue_story", [str(guest["name"]), Dialogue.rumor()], 0, [[item, 1]])
			else:
				Mail.send("mail.rescue_thanks", [str(guest["name"]), Loc.t(str(guest["ship"]))], 0, [[item, 1]])
		if Clock.day_index > int(guest["until"]):
			Lighthouse.rescue_guests.erase(guest)


static func guests_text() -> String:
	var names: Array = []
	for guest in Lighthouse.rescue_guests:
		names.append(str(guest["name"]))
	return "Спасённые в таверне: " + ", ".join(names) if not names.is_empty() else ""
