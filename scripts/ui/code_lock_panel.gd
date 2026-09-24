class_name CodeLockPanel

# Q1.7: Agatha's desk has a "season + day" lock — the date the Mercy went down, stamped in the prologue.
static var season_index: int = 0
static var day: int = 1


static func open(hud: CanvasLayer) -> InfoPanel:
	var seasons := ["Весна", "Лето", "Осень", "Зима"]
	var codes := ["spring", "summer", "autumn", "winter"]
	var body := func() -> String:
		return "%s\n\nКолёсики: %s %d" % [Loc.t("story.spot.agatha_desk.text"), seasons[season_index], day]
	var buttons: Array = [
		["Сезон ▸", func(_p: InfoPanel) -> String:
			season_index = (season_index + 1) % 4
			return ""],
		["Число −", func(_p: InfoPanel) -> String:
			day = 28 if day <= 1 else day - 1
			return ""],
		["Число +", func(_p: InfoPanel) -> String:
			day = 1 if day >= 28 else day + 1
			return ""],
		["Число +7", func(_p: InfoPanel) -> String:
			day = (day + 6) % 28 + 1
			return ""],
		[Loc.t("story.lock.try"), func(_p: InfoPanel) -> String:
			var answer := Story.try_code("%s %d" % [seasons[season_index].to_lower(), day])
			if Game.flag("journal_open"):
				var parent := hud.get_parent()
				if parent and parent.get_node_or_null("StorySpots"):
					parent.get_node("StorySpots").call_deferred("refresh")
			return answer],
	]
	return InfoPanel.open(hud, Loc.t("story.spot.agatha_desk"), body, buttons)
