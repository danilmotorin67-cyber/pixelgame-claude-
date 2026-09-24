class_name Effects

# The effects of 33.6, shared by quests, dialogue choices and scenes: [["friendship","npc_x",60], ...].
static func apply(list: Array) -> void:
	for e in list:
		apply_one(e)


static func apply_one(e: Array) -> void:
	match str(e[0]):
		"friendship":
			Relationships.add_friendship(str(e[1]), int(e[2]))
		"flag":
			Game.set_flag(str(e[1]), bool(e[2]) if e.size() > 2 else true)
		"give", "item":
			var count := int(e[2]) if e.size() > 2 else 1
			if Inventory.add(str(e[1]), count) != count:
				Mail.send("mail.quest_parcel", [], 0, [[str(e[1]), count]])
		"take":
			Inventory.take(str(e[1]), int(e[2]) if e.size() > 2 else 1)
		"money":
			Economy.add(int(e[1]))
		"honor":
			Game.add_honor(int(e[1]))
		"points":
			Knowledge.add_points(str(e[1]), int(e[2]))
		"xp":
			Skills.add_xp(str(e[1]), int(e[2]))
		"start_quest":
			Quests.start(str(e[1]))
		"step_quest":
			Events.quest_event.emit(str(e[1]), str(e[2]) if e.size() > 2 else "")
		"mail":
			Mail.send(str(e[1]))
		"unlock_recipe", "recipe":
			Crafting.learn(str(e[1]))
		"set_weather_tomorrow":
			Weather.force(Clock.day_index + 1, str(e[1]))
		"play_music":
			AudioMgr.play_music(str(e[1]))
		"achievement":
			Achievements.unlock(str(e[1]))
		"stat":
			Game.add_stat(str(e[1]), int(e[2]) if e.size() > 2 else 1)
		"mercy":
			Sea.add_mercy(float(e[1]))
		"shore_gift":
			Sea.schedule_gift(str(e[1]), str(e[2]), Clock.day_index + int(e[3]))
		_:
			push_warning("Unknown effect: %s" % str(e))
