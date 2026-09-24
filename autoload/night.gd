extends Node

const FAINT_MESSAGES := [
	"Вас нашли на берегу. Хорошо, что не похоронили — вы же смотритель, кто бы копал?",
	"Фитиль дотащил вас до дома. Это стоило ему остатков достоинства.",
	"Доктор Фальк: «Жить будете. Долго — не обещаю».",
]
const HOME_SPAWN := Vector2(600, 360)
const BUNK_SPAWN := Vector2(4 * 16 + 8, 10 * 16 + 8)

var resolving: bool = false
var pending_report: Dictionary = {}


# Steps run in the strict order of spec 6.4; systems of later milestones slot in by number.
func end_day(fainted: bool = false, watch_sleep: bool = false) -> void:
	if resolving:
		return
	# The Great Tide is not slept through (Q4.5).
	if not fainted and Finale.finale_today():
		Events.debug_message.emit(Loc.t("finale.no_sleep"))
		return
	resolving = true
	Clock.paused = true
	var current_scene := get_tree().current_scene
	var player: Player = null
	if current_scene:
		player = current_scene.get_node_or_null("Player") as Player
	if player:
		Game.player_state = player.serialize_state()
	var report := {"fainted": fainted, "steps": []}
	var bedtime := Clock.minutes
	var night_index := Clock.day_index
	var aurora_tonight := Weather.aurora
	var storm_today := Weather.current in ["storm", "blizzard"]
	if storm_today:
		Game.counters["last_storm_day"] = Clock.day_index
	var weather_today := Weather.current
	var hmar_tonight := Weather.hmar_night
	var compass_before := [Lighthouse.fire_power, Graveyard.peace, Sea.mercy]
	_step(report, "lighthouse", func() -> void:
		report["lighthouse"] = Lighthouse.resolve_night(bedtime, watch_sleep and not fainted))
	_step(report, "weather_tides", func() -> void:
		Clock.start_next_day()
		report["hmar_night"] = Weather.hmar_night)
	_step(report, "farm", func() -> void:
		Farm.advance_day(storm_today)
		# 17.4: the frozen swordfish (Ice Festival prize) thaws in spring into an ordinary one.
		if Clock.season == "spring" and Clock.day == 1:
			var frozen := Inventory.count_of("frozen_swordfish")
			if frozen > 0 and Inventory.take("frozen_swordfish", frozen):
				Inventory.add("swordfish", frozen)
		Farm.spawn_wild(Clock.day_index))
	_step(report, "animals", func() -> void:
		report["animals"] = Animals.night(weather_today))
	_step(report, "stations", func() -> void:
		report["built"] = Buildings.night()
		report["tool_ready"] = Buildings.tool_night()
		report["crafting"] = Crafting.night(weather_today)
		report["stations_ready"] = Crafting.finished_overnight())
	_step(report, "bodies", func() -> void:
		report["bodies_arrived"] = Graveyard.advance_night(storm_today))
	_step(report, "peace", func() -> void:
		Graveyard.recalc_peace())
	_step(report, "sea", func() -> void:
		Sea.night_mercy()
		Sea.night_gear()
		SeaGarden.night(storm_today)
		Sea.night_boats()
		Sea.generate_gifts(Clock.day_index, storm_today))
	_step(report, "mail", func() -> void:
		Lighthouse.night_mail(night_index)
		Graveyard.deliver_replies(Clock.day_index)
		Relationships.night_letters()
		Crafting.recipe_letters()
		Mail.sunday_gazette()
		report["mail"] = Mail.unread())
	_step(report, "sales", func() -> void:
		report["sales"] = Economy.collect_shipping(night_index, storm_today))
	_step(report, "friendship", func() -> void:
		Relationships.night())
	_step(report, "quests", func() -> void:
		report["story"] = Story.night(night_index, hmar_tonight)
		report["quests_started"] = Quests.check_starts())
	_step(report, "luck", func() -> void:
		report["luck"] = Game.roll_luck(Clock.day_index, aurora_tonight))
	_wake_hero(report, bedtime, fainted, night_index, player, watch_sleep)
	_step(report, "skills", func() -> void:
		report["levels"] = Skills.apply_levels())
	_step(report, "autosave", func() -> void:
		report["saved"] = Save.save_game())
	report["compass"] = {"light": Lighthouse.fire_power - float(compass_before[0]),
		"peace": Graveyard.peace - float(compass_before[1]), "sea": Sea.mercy - float(compass_before[2])}
	report["fortuna"] = Dialogue.hint_of_the_day()
	report["day"] = Clock.day
	report["season"] = Clock.season
	report["weather"] = Weather.current
	report["tide"] = Clock.tide_height()
	report["moon"] = Clock.moon_name()
	report["steps"].append("report")
	var wake_map := Router.current_map
	if current_scene and current_scene.get("map_id") != wake_map:
		pending_report = report
		Router.goto_map(wake_map, Router.spawn)
	else:
		Events.night_resolved.emit(report)
	resolving = false


func _step(report: Dictionary, id: String, action: Callable) -> void:
	action.call()
	report["steps"].append(id)


func energy_fraction(bedtime: int, fainted: bool) -> float:
	if fainted:
		return 0.5
	if bedtime < 60:
		return 0.9
	if bedtime < 120:
		return 0.75
	return 1.0


func _wake_hero(report: Dictionary, bedtime: int, fainted: bool, night_index: int,
		player: Player, watch_sleep: bool) -> void:
	var lost_money := 0
	if fainted:
		lost_money = mini(int(floor(float(Economy.money) * 0.1)), 1000)
		Economy.add(-lost_money)
		report["faint_message"] = FAINT_MESSAGES[posmod(Game.world_seed + night_index, FAINT_MESSAGES.size())]
	report["money_lost"] = lost_money
	var state := Game.player_state.duplicate(true)
	var bunk := 1.0 if Game.flag("comfy_bunk") or not watch_sleep or fainted \
		else float(Lighthouse.cfg("watch_sleep_energy"))
	state["energy"] = Game.max_energy() * energy_fraction(bedtime, fainted) * bunk
	state["cold"] = 0.0
	var wake_map := "lh_3" if watch_sleep and not fainted else "cape"
	var wake_at := BUNK_SPAWN if wake_map == "lh_3" else HOME_SPAWN
	state["x"] = wake_at.x
	state["y"] = wake_at.y
	Game.player_state = state
	Router.current_map = wake_map
	Router.spawn = wake_at
	if player:
		player.restore_state(state)
	Game.add_stat("days_survived")
