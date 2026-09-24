class_name Perfection

# "The Keeper's Perfection" (27.5): thirteen parts with their weights; 100% puts a Golden Lantern on the cape.


static func _ratio(have: int, total: int) -> float:
	return clampf(float(have) / float(maxi(total, 1)), 0.0, 1.0)


static func parts() -> Dictionary:
	var fish_total := 0
	for row in Data.all("items"):
		if str(row.get("category", "")) in ["fish", "shellfish"]:
			fish_total += 1
	var cook_total := Data.all("recipes_cook").size()
	var cooked := 0
	for r in Data.all("recipes_cook"):
		if Crafting.made.has(str(r["out"][0])):
			cooked += 1
	var craft_total := Data.all("recipes_craft").size()
	var crafted := 0
	for r in Data.all("recipes_craft"):
		if Crafting.made.has(str(r["out"][0])):
			crafted += 1
	var skills_max := 0
	for id in Skills.NAMES:
		if Skills.base_level(str(id)) >= 10:
			skills_max += 1
	var residents: Array = Festivals.residents()
	var best := 0
	for npc in residents:
		if Relationships.hearts_of(str(npc)) >= 10:
			best += 1
	var ghosts_total := Data.all("ghosts").size()
	var reads: int = Bottles.read_count() + Story.pages.size() + Tales.count()
	var eye := Lighthouse.lens == "great_eye" and Game.flag("fire_100")
	var seen: int = Cats.count() + Collections.found.get("birds", {}).size() + Collections.found.get("ships", {}).size()
	return {
		"fish": [_ratio(Collections.found.get("fish", {}).size(), fish_total), 10],
		"cooking": [_ratio(cooked, cook_total), 10],
		"crafting": [_ratio(crafted, craft_total), 10],
		"cabinet": [_ratio(Cabinet.count(), Cabinet.wanted().size()), 10],
		"skills": [_ratio(skills_max, Skills.NAMES.size()), 10],
		"friends": [_ratio(best, residents.size()), 10],
		"ghosts": [_ratio(Graveyard.laid_ghosts.size(), ghosts_total), 10],
		"blessings": [_ratio(Daughters.count(), Daughters.ALL.size()), 5],
		"letters": [_ratio(reads, 40 + 24 + 12), 5],
		"great_eye": [1.0 if eye else 0.0, 5],
		"rooms": [_ratio(Community.done.size(), 6), 5],
		"two_fires": [1.0 if Game.flag("two_fires") else 0.0, 5],
		"sightings": [_ratio(seen, 8 + 15 + 20), 5],
	}


static func percent() -> int:
	var total := 0.0
	var parts_now := parts()
	for key in parts_now:
		total += float(parts_now[key][0]) * float(parts_now[key][1])
	return int(floor(total + 0.0001))


static func check() -> bool:
	if percent() >= 100 and not Game.flag("golden_lantern"):
		Game.set_flag("golden_lantern")
		Achievements.unlock("ach_perfection")
		Mail.send("perfection.golden")
		return true
	return false
