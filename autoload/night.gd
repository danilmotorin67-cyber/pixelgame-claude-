extends Node

const FAINT_MESSAGES := [
	"Вас нашли на берегу. Хорошо, что не похоронили — вы же смотритель, кто бы копал?",
	"Фитиль дотащил вас до дома. Это стоило ему остатков достоинства.",
	"Доктор Фальк: «Жить будете. Долго — не обещаю».",
]
const HOME_SPAWN := Vector2(600, 360)

var resolving: bool = false
var pending_report: Dictionary = {}


# Steps run in the strict order of spec 6.4; systems of later milestones slot in by number.
func end_day(fainted: bool = false) -> void:
	if resolving:
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
	_step(report, "lighthouse", func() -> void:
		report["lighthouse"] = Lighthouse.resolve_night())
	_step(report, "weather_tides", func() -> void:
		Clock.start_next_day()
		report["hmar_night"] = Weather.hmar_night)
	_step(report, "farm", func() -> void:
		Farm.advance_day(storm_today))
	_step(report, "sales", func() -> void:
		report["sales"] = Economy.collect_shipping(night_index, storm_today))
	_step(report, "luck", func() -> void:
		report["luck"] = Game.roll_luck(Clock.day_index, aurora_tonight))
	_wake_hero(report, bedtime, fainted, night_index, player)
	_step(report, "skills", func() -> void:
		report["levels"] = Skills.apply_levels())
	_step(report, "autosave", func() -> void:
		report["saved"] = Save.save_game())
	report["day"] = Clock.day
	report["season"] = Clock.season
	report["weather"] = Weather.current
	report["tide"] = Clock.tide_height()
	report["moon"] = Clock.moon_name()
	report["steps"].append("report")
	if current_scene and current_scene.get("map_id") != "cape":
		pending_report = report
		Router.goto_map("cape", HOME_SPAWN)
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
		player: Player) -> void:
	var lost_money := 0
	if fainted:
		lost_money = mini(int(floor(float(Economy.money) * 0.1)), 1000)
		Economy.add(-lost_money)
		report["faint_message"] = FAINT_MESSAGES[posmod(Game.world_seed + night_index, FAINT_MESSAGES.size())]
	report["money_lost"] = lost_money
	var state := Game.player_state.duplicate(true)
	state["energy"] = Game.max_energy() * energy_fraction(bedtime, fainted)
	state["cold"] = 0.0
	state["x"] = HOME_SPAWN.x
	state["y"] = HOME_SPAWN.y
	Game.player_state = state
	Router.current_map = "cape"
	Router.spawn = HOME_SPAWN
	if player:
		player.restore_state(state)
	Game.add_stat("days_survived")
