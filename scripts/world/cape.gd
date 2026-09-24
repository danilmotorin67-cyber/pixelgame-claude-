extends Node2D

@export var map_id: String = "cape"

@onready var hud: CanvasLayer = $HUD
@onready var time_label: Label = $HUD/TimePanel/TimeLabel
@onready var tide_label: Label = $HUD/TidePanel/TideLabel
@onready var weather_label: Label = $HUD/WeatherLabel
@onready var compass_label: Label = $HUD/Compass/CompassLabel
@onready var compass_hud: CompassHud = $HUD/Compass
@onready var money_label: Label = $HUD/MoneyLabel
@onready var hotbar_label: Label = $HUD/HotbarLabel
@onready var inventory_panel: Panel = $HUD/InventoryPanel
@onready var inventory_list: Label = $HUD/InventoryPanel/InventoryScroll/InventoryList
@onready var console: LineEdit = $HUD/Console
@onready var console_out: Label = $HUD/ConsoleOut
@onready var morning_panel: Panel = $HUD/MorningPanel
@onready var morning_text: Label = $HUD/MorningPanel/MorningText

const WEATHER_NAMES := {
	"clear": "Ясно", "cloud": "Облачно", "rain": "Дождь",
	"fog": "Туман", "storm": "Шторм", "snow": "Снег", "blizzard": "Метель",
}

var _was_paused_before_console: bool = false
var _was_paused_before_inventory: bool = false


func _ready() -> void:
	if map_id == "":
		map_id = Router.current_map
	Router.current_map = map_id
	add_child(Pickups.new())
	add_child(Stations.new())
	if map_id == "cape":
		$Garden.add_to_group("gardens")
		if Sea.towing:
			var honour := Sea.finish_tow()
			call_deferred("_tow_hint", honour)
		for plot_id in ["greenhouse_small", "greenhouse"]:
			var house := preload("res://scripts/world/garden.gd").new()
			house.name = "Garden_" + plot_id
			house.plot = plot_id
			house.position = Farm.PLOTS[plot_id]["origin"]
			house.add_to_group("gardens")
			add_child(house)
		add_child(GraveyardWorld.new())
		add_child(Farmstead.new())
		var landing := BoatLanding.new()
		landing.name = "BoatLanding"
		var at: Array = Game.balance("sea", {}).get("cape_landing", [900, 850])
		landing.position = Vector2(float(at[0]), float(at[1]) - 16.0)
		add_child(landing)
		var stone := RannStoneObject.new()
		stone.name = "RannStone"
		stone.position = RannStone.position()
		add_child(stone)
	add_child(BodiesLayer.new())
	if map_id in ["cape", "village", "seal_shore", "wreck_bay", "lagoon"]:
		var foes := LandFoes.new()
		foes.map_id = map_id
		add_child(foes)
	var npcs := NpcLayer.new()
	npcs.map_id = map_id
	add_child(npcs)
	var story := StorySpots.new()
	story.map_id = map_id
	add_child(story)
	if map_id == "cape":
		var bell := TowerBell.new()
		bell.name = "TowerBell"
		bell.position = Vector2(748, 266)
		add_child(bell)
		var mailbox := Mailbox.new()
		mailbox.name = "Mailbox"
		mailbox.position = Vector2(664, 348)
		add_child(mailbox)
	Clock.paused = not Night.pending_report.is_empty()
	Events.map_entered.emit(map_id)
	Events.time_tick.connect(_on_world_changed)
	Events.tide_changed.connect(_on_world_changed)
	Events.weather_changed.connect(_on_world_changed)
	Events.money_changed.connect(_on_world_changed)
	Events.inventory_changed.connect(_refresh_inventory)
	Events.night_resolved.connect(_on_night_resolved)
	Events.lamp_lit.connect(_on_world_changed)
	Events.hour_changed.connect(_on_hour_changed)
	console.visible = false
	console_out.visible = false
	inventory_panel.visible = false
	morning_panel.visible = false
	if Router.TOWER_MAPS.has(map_id):
		$HUD/Hint.text = str(preload("res://scripts/world/lighthouse_floor.gd").TITLES.get(map_id, map_id))
	elif map_id == "sea":
		$HUD/Hint.text = "Залив. Пробел — парус, M — карта, E у причала — на берег."
	elif map_id in ["deep", "grotto"]:
		$Terrain.call_deferred("_hint")
	elif map_id == "cape_workshop":
		$HUD/Hint.text = "Мастерская: станки ставятся ЛКМ, выход — дверь внизу"
	elif map_id != "cape":
		var info := MapInfo.region(map_id)
		$HUD/Hint.text = "%s   E: переход%s" % [str(info.get("title", map_id)), "   E у жителя — поговорить, G — подарить" if map_id == "village" or MapInfo.is_interior(map_id) else ""]
	else:
		$HUD/Hint.text = "Маяк: E у двери — войти; огонь зажигают в фонарной"
	_refresh_hud()
	_refresh_inventory()
	if not Night.pending_report.is_empty():
		var report := Night.pending_report.duplicate(true)
		Night.pending_report.clear()
		call_deferred("_deliver_report", report)


func _tow_hint(honour: int) -> void:
	$HUD/Hint.text = "Рыбак спасён: 300 кр, треска и честь +%d." % honour


func _deliver_report(report: Dictionary) -> void:
	Events.night_resolved.emit(report)


func _on_hour_changed(hour: int) -> void:
	if hour == 21 and Settings.fortuna_reminder and not Lighthouse.lamp_on and Lighthouse.fire_needed():
		$HUD/Hint.text = Dialogue.fortuna_reminder()


func _on_world_changed(_value: Variant = null) -> void:
	_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if morning_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		inventory_panel.visible = not inventory_panel.visible
		if inventory_panel.visible:
			_was_paused_before_inventory = Clock.paused
			Clock.paused = true
			_refresh_inventory()
		else:
			Clock.paused = _was_paused_before_inventory
		get_viewport().set_input_as_handled()
		return
	if inventory_panel.visible:
		return
	if event.is_action_pressed("debug_console"):
		console.visible = not console.visible
		console_out.visible = console.visible
		if console.visible:
			_was_paused_before_console = Clock.paused
			Clock.paused = true
			console.grab_focus()
			console.text = ""
		else:
			Clock.paused = _was_paused_before_console
			console.release_focus()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("open_map") and not console.visible:
		SeaChartPanel.toggle(hud)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("open_knowledge") and not console.visible:
		KnowledgeBook.open(hud)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("open_calendar") and not console.visible:
		CalendarPanel.toggle(hud)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("open_quests") and not console.visible:
		InfoPanel.open(hud, "Журнал: задания", func() -> String:
			var lines := Quests.journal_lines()
			return "\n".join(lines) if not lines.is_empty() else "Пока никаких поручений. Наслаждайтесь.")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and not console.visible:
		Clock.paused = not Clock.paused


func _on_console_submitted(text: String) -> void:
	var res := Debug.exec(text)
	console_out.text = res
	console.clear()
	Events.debug_message.emit(res)
	_refresh_hud()


func _on_night_resolved(report: Dictionary) -> void:
	morning_text.text = NightReport.text(report)
	morning_panel.visible = true
	Clock.paused = true
	_refresh_hud()
	$HUD/MorningPanel/MorningOk.grab_focus()


func _on_morning_ok() -> void:
	morning_panel.visible = false
	Clock.paused = false
	$HUD/MorningPanel/MorningOk.release_focus()
	KnowledgeBook.offer_profession(hud)


func _refresh_hud() -> void:
	var wd := {"mon":"Пн","tue":"Вт","wed":"Ср","thu":"Чт","fri":"Пт","sat":"Сб","sun":"Вс"}
	var sn := {"spring":"Весна","summer":"Лето","autumn":"Осень","winter":"Зима"}
	time_label.text = "%s, %s %d  %02d:%02d" % [
		wd.get(Clock.weekday, Clock.weekday),
		sn.get(Clock.season, Clock.season),
		Clock.day,
		Clock.hour,
		Clock.minute,
	]
	var peak := Clock.next_high_tide()
	tide_label.text = "%s %.1f    Пик %02d:%02d" % [
		"↑" if Clock.tide_rising() else "↓", Clock.tide_height(),
		peak / 60, peak % 60]
	weather_label.text = "%s · %s" % [WEATHER_NAMES.get(Weather.current, ""), Clock.moon_name()]
	compass_label.text = "Свет %d     Покой %d     Море %d" % [
		int(Lighthouse.fire_power),
		int(Graveyard.peace),
		int(Sea.mercy),
	]
	compass_hud.set_values(Lighthouse.fire_power, Graveyard.peace, Sea.mercy)
	money_label.text = "  %d кр" % Economy.money


func _refresh_inventory() -> void:
	var slot: Dictionary = Inventory.slots[Inventory.selected_hotbar]
	var id := str(slot["id"])
	var name := "Пусто" if id == "" else Loc.t(str(Data.by_id("items", id).get("name", id)))
	hotbar_label.text = "%d / 12   ·   %s ×%d" % [
		Inventory.selected_hotbar + 1, name, int(slot["count"])]
	var lines: Array[String] = []
	for index in Inventory.slots.size():
		var stored: Dictionary = Inventory.slots[index]
		if str(stored["id"]) == "":
			continue
		var item := Data.by_id("items", str(stored["id"]))
		lines.append("%02d  %s ×%d" % [index + 1, Loc.t(str(item.get("name", stored["id"]))), int(stored["count"])])
	inventory_list.text = "\n".join(lines) if not lines.is_empty() else "Рюкзак пуст."
