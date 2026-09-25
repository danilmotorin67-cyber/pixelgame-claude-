extends CharacterBody2D
class_name Player

@export var walk_speed: float = 70.0
@export var slow_speed: float = 40.0
@export var dodge_speed: float = 140.0

var facing: Vector2 = Vector2.DOWN
var energy: float = 270.0
var health: float = 100.0
var cold: float = 0.0
var lantern_on: bool = false
var _dodge_t: float = 0.0
var _walk_time: float = 0.0
var tool_kind: String = ""
var tool_time: float = 0.0
var _carry_distance: float = 0.0
var boat_heading: Vector2 = Vector2.DOWN
var boat_speed: float = 0.0
var sail_up: bool = false
var _row_distance: float = 0.0
var _sail_distance: float = 0.0
var _hit_cooldown: float = 0.0
var _storm_clock: float = 0.0
# A held hoe or can (9): when the press began (-1 when idle), where it aimed and the step shown last.
var _charge_start: int = -1
var _charge_at: Vector2 = Vector2.ZERO
var _charge_step: int = 0
const CHARGE_MS := 400
const TOOL_DURATION := 0.34
const CARRY_SPEED := 0.6
const CARRY_TILES_PER_ENERGY := 10.0

@onready var sprite: Sprite2D = $Body
@onready var tool_art: Node2D = $ToolArt


func _ready() -> void:
	if Router.current_map == "sea":
		var art := BoatArt.new()
		art.name = "BoatArt"
		art.show_behind_parent = true
		add_child(art)
	if Game.player_state.is_empty():
		global_position = Router.spawn
	else:
		restore_state(Game.player_state)
	_update_sprite(false)
	Events.time_tick.connect(warm_or_chill)


func _physics_process(delta: float) -> void:
	if Cutscenes.playing or Clock.paused:
		velocity = Vector2.ZERO
		return
	if tool_time > 0.0:
		tool_time = maxf(0.0, tool_time - delta)
		tool_art.queue_redraw()
	if _charge_start >= 0:
		var step := charge_step(Time.get_ticks_msec() - _charge_start)
		if step != _charge_step:
			_charge_step = step
			_say("Замах: %d тайлов…" % int(Farm.CHARGE_TILES[step]))
	if Router.current_map == "sea":
		_boat_physics(delta)
		return
	if Router.current_map in ["deep", "grotto"] and _held():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _dodge_t > 0.0:
		_dodge_t -= delta
		move_and_slide()
		_update_sprite(true)
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var fishing_hud := get_tree().current_scene.get_node_or_null("HUD/FishingHud") as FishingHud if get_tree().current_scene else null
	if fishing_hud and fishing_hud.active():
		dir = Vector2.ZERO
	if dir.length() > 0.1:
		facing = dir.normalized()
	var spd := slow_speed if Input.is_action_pressed("walk_slow") else walk_speed
	if is_tired():
		spd *= float(Game.balance("fatigue_speed", 0.9))
	spd *= maxf(0.5, 1.0 + Game.effect("speed")) * (Animals.ride_speed() if Animals.riding else 1.0)
	if Graveyard.carried != "" and not (Buildings.level("hearse") > 0 and Animals.has_pony()):
		spd *= CARRY_SPEED
	velocity = dir * spd
	if Router.current_map == "deep" and Deep.active:
		# 17.1: swimming in eight directions with a light drift; the suit walks the bottom at ×0.8.
		var walking := Deep.gear() == "suit"
		velocity *= float(Deep.cfg("suit_speed")) if walking else 1.0
		if not walking:
			velocity += Vector2.from_angle(float(Deep.level) * 1.7) * 6.0
		velocity += Deep.world.player["push"] as Vector2
		Deep.world.player["push"] = (Deep.world.player["push"] as Vector2) * 0.85
	var before := global_position
	move_and_slide()
	if Graveyard.carried != "":
		_carry_distance += global_position.distance_to(before)
		if _carry_distance >= CARRY_TILES_PER_ENERGY * 16.0:
			_carry_distance -= CARRY_TILES_PER_ENERGY * 16.0
			energy = maxf(0.0, energy - 1.0)
	if dir.length() > 0.1:
		_walk_time += delta
	else:
		_walk_time = 0.0
	_update_sprite(dir.length() > 0.1)
	if Router.current_map == "cape":
		# Keep the lantern visible while the keeper works at the tower door.
		var camera: Camera2D = $Camera2D
		var near_tower := global_position.distance_to(Vector2(724, 264)) < 92.0
		camera.position.y = lerpf(camera.position.y, -55.0 if near_tower else 0.0,
			clampf(delta * 5.0, 0.0, 1.0))
	_tint()


# Rowing and sailing (16.1-16.3): inertia, wind, rudder, rocks and storms.
func _boat_physics(delta: float) -> void:
	var info := SeaChart.boat_info()
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var fishing_hud := get_tree().current_scene.get_node_or_null("HUD/FishingHud") as FishingHud
	if fishing_hud and fishing_hud.active():
		input = Vector2.ZERO
	var rowing := not (sail_up and float(info.get("sail", 0.0)) > 0.0)
	if rowing:
		if input.length() > 0.1 and energy > 0.0:
			boat_heading = input.normalized()
		var target := input * walk_speed * float(info.get("row", 1.0)) if energy > 0.0 else Vector2.ZERO
		velocity = velocity.move_toward(target, 140.0 * delta)
	else:
		boat_heading = boat_heading.rotated(Input.get_axis("move_left", "move_right") * 1.6 * delta).normalized()
		boat_speed = move_toward(boat_speed, walk_speed * SeaChart.sail_speed(boat_heading), 30.0 * delta)
		velocity = boat_heading * boat_speed
	var before := global_position
	var speed := velocity.length()
	move_and_slide()
	var moved := global_position.distance_to(before)
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if get_slide_collision_count() > 0 and speed > 30.0 and _hit_cooldown <= 0.0:
		_hit_cooldown = 1.0
		boat_speed *= 0.3
		if Sea.damage_hull(lerpf(10.0, 30.0, clampf(speed / 130.0, 0.0, 1.0))):
			_towed()
			return
		_say("Удар о камни! Корпус %d%%." % int(Sea.hull))
	if Weather.current in ["storm", "blizzard"] and not Game.flag("storm_sails") and not Daughters.storm_hull_safe() \
			and not Skills.has_profession("wind_son"):
		_storm_clock += delta
		if _storm_clock >= float(SeaChart.cfg("storm_damage_every")):
			_storm_clock = 0.0
			if Sea.damage_hull(1.0):
				_towed()
				return
	if rowing and moved > 0.0:
		_row_distance += moved
		var per_energy := float(SeaChart.cfg("row_tiles_per_energy")) * 16.0
		if _row_distance >= per_energy:
			_row_distance -= per_energy
			energy = maxf(0.0, energy - (0.5 if Sea.blessings.has("zyb") else 1.0))
	_sail_distance += moved
	if _sail_distance >= 20.0 * 16.0:
		_sail_distance -= 20.0 * 16.0
		var mult := 2.0 if Weather.current == "storm" else (1.5 if Weather.current in ["rain", "fog"] else 1.0)
		Skills.add_xp("seafaring", int(round(mult)))
	SeaChart.reveal(global_position)
	if Sea.visit(SeaChart.near_place(global_position, 4.0)):
		_say("Новое место на карте: %s." % Loc.t("sea." + SeaChart.near_place(global_position, 4.0)))
	facing = boat_heading
	_update_sprite(false)
	var art := get_node_or_null("BoatArt")
	if art:
		art.queue_redraw()


func _towed() -> void:
	Sea.tow_home()
	var landing: Array = SeaChart.cfg("cape_landing")
	Router.goto_map("cape", Vector2(float(landing[0]), float(landing[1])))


func _direction_index() -> int:
	if absf(facing.x) > absf(facing.y):
		return 1 if facing.x < 0.0 else 2
	return 3 if facing.y < 0.0 else 0


func _update_sprite(moving: bool) -> void:
	sprite.frame = _direction_index() * 4 + (int(_walk_time * 8.0) % 4 if moving else 0)


func play_tool(kind: String, target: Vector2) -> void:
	var toward := target - global_position
	if toward.length() > 4.0:
		facing = toward.normalized()
	tool_kind = kind
	tool_time = TOOL_DURATION * (float(Game.balance("fatigue_tool_time", 1.25)) if is_tired() else 1.0) \
		* (1.2 if Cold.shivering(cold) else 1.0)
	_update_sprite(false)
	tool_art.queue_redraw()


func max_health() -> float:
	return float(Game.balance("health_max", 100)) + 5.0 * float(Skills.level("diving"))


# Items with a "use": the sea chart reveals the bay, star amber adds 30 energy for good (21.3).
func use_selected() -> String:
	var index := Inventory.selected_hotbar
	var id := str(Inventory.slots[index]["id"])
	match str(Data.by_id("items", id).get("use", "")):
		"reveal_sea":
			var size: Array = Game.balance("sea", {}).get("size", [120, 90])
			for y in range(0, int(size[1]), 8):
				for x in range(0, int(size[0]), 8):
					SeaChart.reveal(Vector2(x * 16 + 8, y * 16 + 8))
			Inventory.take_slot(index, 1)
			return "Карта залива перенесена на вашу: мели, рифы, течения."
		"star_amber":
			Inventory.take_slot(index, 1)
			Game.counters["star_amber"] = int(Game.counters.get("star_amber", 0)) + 1
			energy = minf(energy + 30.0, Game.max_energy())
			return "Звёздный янтарь тёплый, как ладонь. Сил навсегда стало больше."
		"calm_tomorrow":
			if Weather.requested_calm == Clock.day_index + 1:
				return "Штиль на завтра уже обещан."
			Inventory.take_slot(index, 1)
			Weather.requested_calm = Clock.day_index + 1
			return "Зелье выпито. Ветер к утру ляжет."
	var use := str(Data.by_id("items", id).get("use", ""))
	if use.begins_with("warp:"):
		var target := use.substr(5)
		if Router.current_map == target:
			return "Вы и так здесь."
		Inventory.take_slot(index, 1)
		Router.goto_map(target, Router.WARP_SPAWNS.get(target, Vector2(400, 300)))
		return "Тотем рассыпался. Мир на миг стал другим."
	var item := Data.by_id("items", id)
	if item.has("slot") or str(item.get("category", "")) == "amulet":
		match Game.equip(id):
			"on":
				return "Надето: %s." % Loc.t(str(item["name"]))
			"off":
				return "Снято: %s." % Loc.t(str(item["name"]))
			_:
				return "Некуда снять надетое: рюкзак полон."
	return ""


# Food restores energy and health (8.6); returns the eaten item id or "".
func eat_selected() -> String:
	var index := Inventory.selected_hotbar
	var id := str(Inventory.slots[index]["id"])
	var edible: Dictionary = Data.by_id("items", id).get("edible", {})
	if edible.is_empty() or not Inventory.take_slot(index, 1):
		return ""
	energy = minf(energy + float(edible.get("energy", 0)), Game.max_energy())
	health = minf(health + float(edible.get("health", 0)), max_health())
	var buff: Dictionary = Data.by_id("items", id).get("buff", {})
	if not buff.is_empty():
		if str(Data.by_id("items", id).get("category", "")) == "potion" and Skills.has_profession("healer"):
			buff = buff.duplicate()
			buff["hours"] = float(buff.get("hours", 0)) * 1.5
		Game.add_buff(buff)
		if bool(buff.get("warm_now", false)):
			cold = 0.0
	if Cold.is_warm_food(id):
		cold = maxf(0.0, cold - float(Cold.cfg("warm_food_relief", 20)))
	return id


# 8.3: Cold builds by the weather, the season and the water, and leaves by the fire (Cold). At 50 and above every
# action costs a quarter more (8.1); at 100 the Shivers take a point of energy a minute.
func warm_or_chill(minutes: int) -> void:
	cold = Cold.step(cold, minutes, Router.current_map, global_position, Weather.current, Clock.season)
	if Cold.shivering(cold):
		energy = maxf(0.0, energy - float(minutes))


func spend_raw(amount: float) -> void:
	energy = maxf(0.0, energy - amount)


func _place_selected(at: Vector2) -> bool:
	var info := Data.by_id("items", Inventory.selected_id())
	if str(info.get("place", "")) == "" and str(info.get("plant", "")) == "":
		return false
	if global_position.distance_to(at) > Crafting.PLACE_REACH:
		return false
	if Crafting.place_selected(Router.current_map, at):
		var stations := get_tree().current_scene.get_node_or_null("Stations") as Stations
		if stations:
			stations.rebuild()
	return true


# 19.1/19.3 raw materials: sand from beaches, seawater with a bucket, birches in the grove.
func _gather(at: Vector2) -> bool:
	if global_position.distance_to(at) > 48.0:
		return false
	var id := Inventory.selected_id()
	if id in ["tool_hoe", "tool_shovel"]:
		var mark := Farm.raven_mark_at(Router.current_map, at)
		if not mark.is_empty():
			if energy <= 0.0:
				_say("Нужен отдых, сил на работу нет.")
				return true
			var got := Farm.dig_raven_mark(Router.current_map, mark)
			spend_energy("shovel" if id == "tool_shovel" else "hoe")
			play_tool("hoe", at)
			var pickups := get_tree().current_scene.get_node_or_null("Pickups") as Pickups
			if pickups:
				pickups.rebuild()
			_say("Вороны не зря кружили: %s." % ("старые монеты, %d кр" % int(got["money"]) if got.has("money")
				else "%s ×%d" % [Crafting.item_name(str(got["item"])), int(got["count"])]))
			return true
	if id == "tool_can":
		if Farm.fresh_water_at(Router.current_map, at):
			Farm.fill_can()
			_say("Лейка полна: %d." % Farm.can_water)
			return true
		if Fishing.is_water(Router.current_map, at):
			_say("Лейка отказывается. Она видела, что соль делает с репой.")
			return true
	var scoop := int(Data.by_id("items", id).get("use_water", 0))
	if scoop > 0:
		var got := Crafting.scoop_seawater(Router.current_map, at, scoop)
		_say("Морская вода: +%d." % got if got > 0 else "Зачерпнуть можно только у моря.")
		return true
	if energy <= 0.0 and id in ["tool_shovel", "tool_axe"]:
		_say("Нужен отдых, сил на работу нет.")
		return true
	if id == "tool_shovel" and Router.current_map in Crafting.GATHER_BEACHES and Router.current_map != "cape":
		var sand := Crafting.dig_sand(Router.current_map, at)
		if sand > 0:
			spend_energy("shovel")
			play_tool("hoe", at)
			_say("Песок: +%d." % sand)
			return true
	if id == "tool_shovel" and Router.current_map == "cape" and Crafting.dig_sand("cape", at) > 0:
		spend_energy("shovel")
		play_tool("hoe", at)
		_say("Песок: +1.")
		return true
	if id == "tool_scythe" and Router.current_map in ["cape", "moor", "birch"] and Buildings.level("hayloft") > 0 \
			and not Fishing.is_water(Router.current_map, at):
		spend_energy("scythe")
		play_tool("hoe", at)
		var got := Buildings.mow(randf())
		_say("Сено в сенник: +1 (%d из %d)." % [Buildings.hay, Buildings.hay_capacity()] if got > 0
			else ("Сенник полон." if Buildings.hay >= Buildings.hay_capacity() else "Трава скошена, сена не вышло."))
		return true
	if id == "tool_axe" and Router.current_map == "birch":
		var felled := Crafting.fell_birch("birch", at)
		if felled.has("log"):
			spend_energy("axe")
			play_tool("hoe", at)
			_say("Берёза срублена: бревно, кора и щепа.")
		elif felled.has("done"):
			_say("На сегодня хватит: рощу берегут.")
		else:
			return false
		return true
	return false


# How far a held blow has charged: one step per 0.4 s, up to what the tool's level allows.
func charge_step(held_ms: int) -> int:
	return mini(held_ms / CHARGE_MS, Farm.max_charge(Inventory.selected_id()))


func is_tired() -> bool:
	return energy <= Game.max_energy() * float(Game.balance("fatigue_share", 0.15))


# At zero energy tools stop working; the last action may drain the keeper to zero.
func spend_energy(action: String) -> bool:
	if energy <= 0.0:
		return false
	energy = maxf(0.0, energy - Game.action_cost(action, cold))
	return true


func _unhandled_input(event: InputEvent) -> void:
	if Clock.paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode
		if code >= KEY_1 and code <= KEY_9:
			Inventory.select_hotbar(code - KEY_1)
			return
		if code == KEY_0:
			Inventory.select_hotbar(9)
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Inventory.select_hotbar(Inventory.selected_hotbar - 1)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Inventory.select_hotbar(Inventory.selected_hotbar + 1)
			return
	if event.is_action_pressed("use_tool") and Graveyard.carried != "":
		_say("С ношей на плечах инструменты не взять. E — положить.")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("use_tool") and _combat() != null \
			and str(Data.by_id("items", Inventory.selected_id()).get("category", "")) == "weapon":
		_combat().player["facing"] = facing
		var hits := _combat().attack(Inventory.selected_id())
		play_tool("hoe", global_position + facing * 16.0)
		if not hits.is_empty():
			_say("Попадание!")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("use_tool") and not Fishing.rod(Inventory.selected_id()).is_empty():
		var hud := get_tree().current_scene.get_node_or_null("HUD") as CanvasLayer
		if hud and not FishingHud.of(hud).active():
			FishingHud.of(hud).begin(self, Inventory.selected_id())
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("use_tool") and Router.current_map == "sea" \
			and str(Data.by_id("items", Inventory.selected_id()).get("sea_garden", "")) != "":
		var at_sea := get_global_mouse_position()
		match SeaGarden.place(Inventory.selected_id(), at_sea) if global_position.distance_to(at_sea) <= 48.0 else "far":
			"ok":
				var map_node := get_tree().current_scene.get_node_or_null("Terrain")
				if map_node and map_node.has_method("rebuild_garden"):
					map_node.rebuild_garden()
				_say("Поставлено в морском огороде. Урожай — с лодки, E рядом.")
			"taken":
				_say("Здесь уже что-то стоит.")
			_:
				_say("Морской огород — участок у причала мыса (рамка на воде).")
		get_viewport().set_input_as_handled()
		return
	var gear_kind := str(Data.by_id("items", Inventory.selected_id()).get("place_water", ""))
	if event.is_action_pressed("use_tool") and gear_kind != "":
		var at := get_global_mouse_position()
		if global_position.distance_to(at) <= 48.0:
			if Sea.place_gear(gear_kind, Router.current_map, at):
				var pickups := get_tree().current_scene.get_node_or_null("Pickups") as Pickups
				if pickups:
					pickups.rebuild()
				_say("Поставлено." if gear_kind in ["trap", "longline"] else "Сеть поставлена. Снимать — на следующем отливе.")
			else:
				_say("Ловушку — в воду у берега; сеть — на приливную полосу в отлив.")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("use_tool") and _use_on_object(get_global_mouse_position()):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("use_tool") and Inventory.selected_id() == "tool_shovel" \
			and Router.current_map != "cape":
		var at := get_global_mouse_position()
		var cell := Vector2i(floori(at.x / 16.0), floori(at.y / 16.0))
		if Farm.in_peat_bog(Router.current_map, cell) and global_position.distance_to(at) <= 40.0:
			var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
			if energy <= 0.0:
				hint.text = "Нужен отдых, сил на работу нет."
			else:
				var got := Farm.dig_peat(Router.current_map, cell)
				if got > 0:
					spend_energy("shovel")
					play_tool("hoe", at)
				hint.text = ("Торф: +%d" % got) if got > 0 else "Здесь уже копали в этом сезоне."
			get_viewport().set_input_as_handled()
			return
	if event.is_action_released("use_tool") and _charge_start >= 0:
		var step := charge_step(Time.get_ticks_msec() - _charge_start)
		_charge_start = -1
		_charge_step = 0
		if step > 0:
			var aim := _charge_at - global_position
			var dir := Vector2i(signi(roundi(aim.x)), 0) if absf(aim.x) > absf(aim.y) else Vector2i(0, signi(roundi(aim.y)))
			if aim.length() < 8.0:
				dir = Vector2i(roundi(facing.x), roundi(facing.y))
			for garden in get_tree().get_nodes_in_group("gardens"):
				if garden.use_area(_charge_at, self, step, dir):
					break
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("use_tool") and Router.current_map == "cape":
		if Inventory.selected_id() in ["tool_hoe", "tool_can"] and Farm.max_charge(Inventory.selected_id()) > 0:
			_charge_start = Time.get_ticks_msec()
			_charge_at = get_global_mouse_position()
			_charge_step = 0
		for garden in get_tree().get_nodes_in_group("gardens"):
			if garden.use_at(get_global_mouse_position(), self):
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("use_tool") and _place_selected(get_global_mouse_position()):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("use_tool") and _gather(get_global_mouse_position()):
		get_viewport().set_input_as_handled()
		return
	if Router.current_map == "sea" and event.is_action_pressed("dodge"):
		if float(SeaChart.boat_info().get("sail", 0.0)) > 0.0:
			sail_up = not sail_up
			boat_speed = velocity.length()
			_say("Парус поднят: руль — A/D." if sail_up else "Парус спущен: на вёслах.")
		get_viewport().set_input_as_handled()
		return
	if Router.current_map == "sea" and event.is_action_pressed("quick_eat") and Inventory.selected_id() == "repair_kit":
		_say("Корпус залатан: %d%%." % int(Sea.hull) if Sea.use_repair_kit() else "Корпус и так цел.")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("dodge") and _dodge_t <= 0.0:
		if _combat() != null and not _combat().dodge():
			return
		_dodge_t = 0.18
		velocity = facing * dodge_speed
	if event.is_action_pressed("quick_eat"):
		var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
		# Story things read or used by hand: bottles, the sextant, a flare (18.6, 11.8).
		var story := Story.use_item(Inventory.selected_id(), global_position)
		if story != "":
			var hud := get_tree().current_scene.get_node_or_null("HUD") as CanvasLayer
			if hud and story.length() > 60:
				InfoPanel.open(hud, Crafting.item_name(Inventory.selected_id()) if Inventory.selected_id() != "" else "", func() -> String: return story)
			elif hint:
				hint.text = story
			return
		var used := use_selected()
		if used != "":
			if hint:
				hint.text = used
			return
		if Data.by_id("items", Inventory.selected_id()).has("open"):
			var loot := Lighthouse.open_crate(Inventory.selected_hotbar)
			var names: Array[String] = []
			for entry in loot:
				names.append("%s ×%d" % [Loc.t(str(Data.by_id("items", str(entry[0]))["name"])), int(entry[1])])
			if hint:
				hint.text = "В ящике: " + ", ".join(names)
			return
		var eaten := eat_selected()
		if hint:
			hint.text = ("Съедено: %s" % Loc.t(str(Data.by_id("items", eaten)["name"]))) if eaten != "" \
				else "Это не едят. Даже на спор."
	if event.is_action_pressed("lantern"):
		lantern_on = not lantern_on
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("give"):
		var npc := _facing_object("receive_gift")
		if npc:
			npc.receive_gift(self)
		else:
			_say("Подарок вручают лицом к лицу. G рядом с жителем.")


# The fight model of the place the keeper is in: a Deep level or a grotto hall.
func _combat() -> CombatWorld:
	if Router.current_map == "deep" and Deep.active:
		return Deep.world
	if Router.current_map == "grotto" and Grotto.active:
		return Grotto.world
	if LandFoes.current != null and LandFoes.active_now():
		return LandFoes.current
	return null


func _held() -> bool:
	var world := _combat()
	if world:
		return float(world.player["held"]) > 0.0 or float(world.player["stun"]) > 0.0
	return false


func _say(text: String) -> void:
	var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
	if hint:
		hint.text = text


# Graves and stones answer to the selected tool under the mouse (48 px reach).
func _use_on_object(at: Vector2) -> bool:
	if global_position.distance_to(at) > 48.0:
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = at
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 8
	for hit in get_world_2d().direct_space_state.intersect_point(query, 8):
		var node: Object = hit.get("collider")
		if node and node.has_method("use_tool"):
			if energy <= 0.0:
				_say("Нужен отдых, сил на работу нет.")
				return true
			var result: String = node.use_tool(self, Inventory.selected_id())
			if result != "":
				play_tool("hoe", at)
				_say(result)
				return true
	return false


func _facing_object(method: String) -> Node:
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + facing * 18.0)
	q.collide_with_areas = true
	q.hit_from_inside = true
	q.collision_mask = 8
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	var n: Node = hit.get("collider") if hit else null
	return n if n and n.has_method(method) else null


func _try_interact() -> void:
	var space := get_world_2d().direct_space_state
	var to := global_position + facing * 16.0
	var q := PhysicsRayQueryParameters2D.create(global_position, to)
	q.collide_with_areas = true
	q.hit_from_inside = true
	q.collision_mask = 8
	var hit := space.intersect_ray(q)
	if hit:
		var n: Node = hit.get("collider")
		if n and n.has_method("interact"):
			n.interact(self)
			return
	if Router.current_map == "sea" and bool(SeaChart.boat_info().get("cabin", false)):
		_offer_cabin()
		return
	if Graveyard.carried != "":
		Graveyard.put_down(Router.current_map, global_position + facing * 12.0)
		var layer := get_tree().current_scene.get_node_or_null("BodiesLayer") as BodiesLayer
		if layer:
			layer.rebuild()
		_say("Тело положено на землю.")


func _tint() -> void:
	if sprite:
		sprite.modulate = Color.WHITE if not lantern_on else Color(1.0, 0.92, 0.73)


func serialize_state() -> Dictionary:
	return {"x": global_position.x, "y": global_position.y,
		"energy": energy, "health": health, "cold": cold,
		"lantern_on": lantern_on, "face_x": facing.x, "face_y": facing.y}


func restore_state(state: Dictionary) -> void:
	global_position = Vector2(float(state.get("x", 600)), float(state.get("y", 360)))
	energy = clampf(float(state.get("energy", Game.max_energy())), 0.0, Game.max_energy())
	health = float(state.get("health", 100.0))
	cold = float(state.get("cold", 0.0))
	lantern_on = bool(state.get("lantern_on", false))
	facing = Vector2(float(state.get("face_x", 0)), float(state.get("face_y", 1)))
	velocity = Vector2.ZERO
	_update_sprite(false)
	_tint()


# 8.4: the bot's cabin — sleep at sea (from 18:00) and wake where the boat lies.
func _offer_cabin() -> void:
	var hud := get_tree().current_scene.get_node_or_null("HUD") as CanvasLayer
	if hud == null:
		return
	if Clock.hour >= 2 and Clock.hour < 18:
		_say("Каюта бота: койка, фонарь, пахнет смолой. Спать — с 18:00.")
		return
	InfoPanel.open(hud, "Каюта бота", func() -> String:
		return "Лечь в каюте? Проснётесь здесь же, в море.", [["Спать", func(p: InfoPanel) -> String:
			p.close()
			Game.set_flag("cabin_sleep")
			Night.end_day()
			return ""]])
