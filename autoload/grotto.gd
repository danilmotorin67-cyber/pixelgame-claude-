extends Node

# The Ebb Grottoes (17.6): ten halls open only at low tide (halls 1-5 at h ≤ −0.4, 6-10 at h ≤ −0.8).
# Thirty minutes before the water returns the caves rumble; whoever stays is thrown out (−20 energy and a
# stack the sea keeps). Otliva's blessing gives 60 more minutes and a safe way out.
const TILE := 16.0
const ENTRANCE := Vector2(52 * 16 + 8, 14 * 16 + 8)
const ECHO := [1, 0, 3, 2]

var active: bool = false
var hall: int = 0
var world: CombatWorld
var carrying: bool = false
# Per visit: boulders moved onto plates (hall 2), the struck stalactites (hall 6), breath in hall 7.
var plates: Dictionary = {}
var boulders_left: Dictionary = {}
var struck: Array = []
var breath: float = 30.0
var warned: bool = false


func cfg(key: String) -> Variant:
	return Data.tables.get("grotto", {}).get(key)


func reset() -> void:
	active = false
	hall = 0
	world = null
	_visit_reset()


func _visit_reset() -> void:
	carrying = false
	plates.clear()
	boulders_left.clear()
	struck.clear()
	breath = float(cfg("dive_air")) if cfg("dive_air") != null else 30.0
	warned = false


func hall_info(index: int = -1) -> Dictionary:
	var halls: Array = cfg("halls")
	return halls[clampi(hall if index < 0 else index, 0, halls.size() - 1)]


func rows(index: int = -1) -> Array:
	return hall_info(index)["rows"]


func tile(cell: Vector2i, index: int = -1) -> String:
	var r: Array = rows(index)
	if cell.y < 0 or cell.y >= r.size() or cell.x < 0 or cell.x >= str(r[0]).length():
		return "#"
	return str(r[cell.y])[cell.x]


func blessed() -> bool:
	return Sea.blessings.has("otliva")


func threshold(band: int) -> float:
	return float(cfg("open_band").get(str(band), -0.4))


func open_at(band: int, index: int, minutes: int) -> bool:
	var thr := threshold(band)
	if Clock.tide_height_at(index, minutes) <= thr:
		return true
	return blessed() and (Clock.tide_height_at(index, minutes - 60) <= thr or Clock.tide_height_at(index, minutes + 60) <= thr)


func band_open(band: int) -> bool:
	return open_at(band, Clock.day_index, Clock.minutes)


# Game minutes until the water closes this band (0 when closed now).
func minutes_left(band: int) -> int:
	var m := 0
	while m < 720 and open_at(band, Clock.day_index, Clock.minutes + m):
		m += 5
	return m


# ---- entering ----

func entrance_state() -> String:
	if not Game.flag("grotto_open"):
		return "rock"
	return "" if band_open(1) else "water"


# The stone over the mouth shows at the great ebb of Spring 15 and later (Q1.10): a pickaxe breaks it.
func break_entrance(tool_id: String) -> bool:
	if Game.flag("grotto_open") or tool_id != "tool_pick" or Clock.day_index < 14 or not band_open(1):
		return false
	Game.set_flag("grotto_open")
	Events.quest_event.emit("grotto_opened", "")
	return true


func enter() -> bool:
	if entrance_state() != "":
		return false
	active = true
	hall = 0
	_visit_reset()
	_build_world()
	return true


func _build_world() -> void:
	world = CombatWorld.new(Game.world_seed * 17 + hall + Clock.day_index, func(p: Vector2) -> bool: return walkable(p))
	world.underwater = false
	var r := rows()
	for y in r.size():
		for x in str(r[y]).length():
			if str(r[y])[x] == "c":
				world.spawn("crab", cell_center(Vector2i(x, y)))


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + 8.0, cell.y * TILE + 8.0)


func entry_cell(index: int = -1) -> Vector2i:
	var r := rows(index)
	for y in r.size():
		var x := str(r[y]).find("<")
		if x >= 0:
			return Vector2i(x + 1, y)
	return Vector2i(1, 1)


func blocked(ch: String) -> bool:
	match ch:
		"#":
			return true
		"g":
			return not gate_open()
		"R":
			return not Game.flag("grotto_rubble")
	return false


func walkable(at: Vector2) -> bool:
	return not blocked(tile(Vector2i(floori(at.x / TILE), floori(at.y / TILE))))


func gate_open() -> bool:
	match hall:
		1:
			return plates.size() >= 3
		5:
			return Game.flag("grotto_echo") or struck.size() >= ECHO.size()
	return true


# ---- moving between halls ----

func next_hall() -> String:
	if hall >= 9:
		return "last"
	var band := int(hall_info(hall + 1)["band"])
	if not band_open(band):
		return "water"
	hall += 1
	carrying = false
	_build_world()
	Skills.add_xp("foraging", 5)
	if hall + 1 > int(Game.counters.get("grotto_deepest", 0)):
		Game.counters["grotto_deepest"] = hall + 1
	return "ok"


func previous_hall() -> String:
	if hall == 0:
		leave()
		return "out"
	hall -= 1
	carrying = false
	_build_world()
	return "ok"


func leave() -> String:
	var out := Twenty.on_left_grotto() if active else ""
	active = false
	world = null
	_visit_reset()
	return out


# ---- the water returns ----

# Called every game tick: the rumble 30 minutes before, then the flood.
func check_water() -> String:
	if not active:
		return ""
	var band := int(hall_info()["band"])
	var left := minutes_left(band)
	if left <= 0:
		return flood()
	if left <= int(cfg("warn_minutes")) and not warned:
		warned = true
		return "rumble"
	return ""


func flood() -> String:
	var lost := ""
	Twenty.on_flood()
	# 12.4: whoever stays in the tenth hall when the water comes back meets Otliva; she holds the water.
	if hall == 9 and not blessed():
		Daughters.grant("otliva")
		leave()
		return "otliva"
	if not blessed():
		var candidates: Array = []
		for i in Inventory.capacity:
			var id := str(Inventory.slots[i]["id"])
			if id != "" and str(Data.by_id("items", id).get("category", "")) not in ["tool", "weapon", "quest"]:
				candidates.append(i)
		if not candidates.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = posmod(Game.world_seed * 3 + Clock.day_index * 5 + hall, 2147483647)
			var i: int = candidates[rng.randi_range(0, candidates.size() - 1)]
			lost = str(Inventory.slots[i]["id"])
			Inventory.take_slot(i, int(Inventory.slots[i]["count"]))
	leave()
	return "flood:" + lost


# Energy the flood takes (none with Otliva's blessing).
func flood_energy() -> float:
	return 0.0 if blessed() else float(cfg("flood_energy"))


# Hall 7: holding the breath in the flooded passage (30 s of air).
func dive_tick(delta: float, at: Vector2) -> String:
	if tile(Vector2i(floori(at.x / TILE), floori(at.y / TILE))) != "W":
		breath = minf(float(cfg("dive_air")), breath + delta * 10.0)
		return ""
	breath -= delta
	if breath <= 0.0:
		breath = float(cfg("dive_air"))
		return "gasp"
	return ""


# ---- the halls' things ----

func _once(key: String) -> bool:
	if Game.flag(key):
		return false
	Game.set_flag(key)
	return true


func _daily(key: String) -> bool:
	var k := "%s_%d" % [key, Clock.day_index]
	if Game.flag(k):
		return false
	Game.set_flag(k)
	return true


func interact(cell: Vector2i, tool_id: String = "") -> String:
	var ch := tile(cell)
	var key := "grotto_%d_%d_%d" % [hall, cell.x, cell.y]
	match ch:
		"P":
			if not _daily(key):
				return "Лужа пуста до следующего отлива."
			var pools: Dictionary = Data.tables["forage"]["tidepools"]
			var item := Sea._pick(RandomNumberGenerator.new(), pools["table"])
			Inventory.add(item, 1)
			Skills.add_xp("foraging", 5)
			return "В луже: " + Crafting.item_name(item)
		"M":
			if not _daily(key):
				return "Мидии уже собраны."
			Inventory.add("mussels", 2)
			return "Мидии ×2."
		"S":
			if not _daily(key):
				return "Кристалл сколот — вырастет к следующему отливу."
			Inventory.add("salt_crystal", 1)
			return "Соляной кристалл."
		"B":
			if carrying or boulders_left.has(key):
				return "Камень уже сдвинут."
			carrying = true
			boulders_left[key] = true
			return "Камень на руках. Положите его на плиту (E у плиты)."
		"p":
			if plates.has(key):
				return "Плита уже придавлена."
			if not carrying:
				return "Плита поддаётся под тяжестью. Нужен камень."
			carrying = false
			plates[key] = true
			return "Решётка поднялась!" if plates.size() >= 3 else "Плита опустилась (%d из 3)." % plates.size()
		"g":
			return "Решётка поднята." if gate_open() else ("Решётка. Где-то рядом три плиты." if hall == 1 else "Решётка. Капель стучит в каком-то ритме.")
		"O":
			return "Капель падает в колодец: второй, первый, четвёртый, третий сталактит. Повторите."
		"T":
			return strike(cell)
		"X":
			if not _once("page_2"):
				return "Ниша с вырезанной «Ф» пуста."
			Knowledge.add_points("rest", 2)
			Story.add_page(2)
			return "Страница журнала Агаты №2 — за нишей с буквой «Ф»."
		"F":
			return "Пустой постамент носовой фигуры. Кто-то стоял здесь двести лет."
		"G":
			if not Cats.find(7):
				return "«Фитиль VII. Прожил 23 года из вредности.»"
			return "Кошачья могила: «Фитиль VII. Прожил 23 года из вредности.»"
		"C":
			if not _once(key):
				return "Ящик пуст."
			Inventory.add("smuggler_crate", 1)
			return "Ящик контрабандистов — Q, чтобы вскрыть."
		"K":
			if hall == Twenty.HALL:
				return Twenty.take_from_hall()
			return Ghosts.jacques_remains()
		"R":
			if Game.flag("grotto_rubble"):
				return "Проход открыт."
			if tool_id != "tool_pick" or Buildings.tool_level("tool_pick") < 2:
				return "Завал. Нужна железная кирка (улучшение у Торы)."
			Game.set_flag("grotto_rubble")
			return "Завал рухнул. За ним — тишина Зала Двадцати."
		"E":
			return Twenty.take_eleonora()
		"$":
			if not _once(key):
				return "Пусто."
			Inventory.add("old_crown", 3)
			Inventory.add("silver_ingot", 1)
			return "Клад: старые кроны и серебро."
		"L":
			if not _once("grotto_false_lantern"):
				return "Пустой крюк."
			Inventory.add("false_lantern", 1)
			Inventory.add("grim_seal", 1)
			return "Старый ложный фонарь и печать Гримов."
		"H":
			if not _once("grotto_heart"):
				return "Сундук пуст."
			Inventory.add("heart_of_grotto", 1)
			return "Сундук «Сердце грота» — Q, чтобы открыть."
		"~", "A":
			return "Вода здесь уходит последней. Говорят, иногда она не хочет уходить совсем."
	return ""


# Hall 6: strike the stalactites in the order of the drops.
func strike(cell: Vector2i) -> String:
	var order: Array = []
	var r := rows()
	for y in r.size():
		for x in str(r[y]).length():
			if str(r[y])[x] == "T":
				order.append(Vector2i(x, y))
	var index := order.find(cell)
	if index < 0:
		return ""
	if int(ECHO[struck.size()]) != index:
		struck.clear()
		return "Звук ушёл не туда. Капель начинает заново."
	struck.append(index)
	if struck.size() >= ECHO.size():
		Game.set_flag("grotto_echo")
		return "Эхо ответило. Решётка ушла вверх."
	return "Звон (%d из %d)." % [struck.size(), ECHO.size()]
