extends Control
class_name InventoryGrid

# The backpack (Tab): all slots in rows of twelve, the first row being the hotbar. Click a slot to pick
# it up and another to swap them; the card below describes the slot under the cursor (or the picked one).
const STEP := 25
const CATEGORY := {"tool": "Инструмент", "weapon": "Оружие", "crop": "Урожай", "seed": "Семена", "food": "Еда",
	"fish": "Рыба", "forage": "Дары острова", "shellfish": "Моллюски и раки", "material": "Материал",
	"artisan": "Изделие", "ingredient": "Продукт", "potion": "Снадобье", "amulet": "Амулет", "clothes": "Одежда",
	"tackle": "Снасть", "bait": "Наживка", "decor": "Декор", "furniture": "Станок", "gift": "Подарок",
	"artifact": "Находка", "quest": "Сюжет", "keepsake": "Памятная вещь", "cargo": "Груз", "part": "Деталь маяка",
	"trash": "Хлам", "sapling": "Саженец", "marker": "Надгробие", "coffin": "Гроб", "remains": "Останки",
	"fuel": "Топливо", "egg": "Яйцо", "candle": "Свеча", "fertilizer": "Удобрение"}

var picked := -1
var _hover := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Events.inventory_changed.connect(queue_redraw)


func slot_at(pos: Vector2) -> int:
	var col := int(pos.x / STEP)
	var row := int(pos.y / STEP)
	if pos.x < 0 or pos.y < 0 or col >= Inventory.HOTBAR:
		return -1
	var index := row * Inventory.HOTBAR + col
	return index if index < Inventory.slots.size() else -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var at := slot_at(event.position)
		if at != _hover:
			_hover = at
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click(slot_at(event.position))
		accept_event()


# Picks a slot up, or swaps the picked one with this one.
func click(index: int) -> void:
	if index < 0:
		picked = -1
	elif picked < 0:
		picked = index if str(Inventory.slots[index]["id"]) != "" else -1
	else:
		Inventory.swap(picked, index)
		picked = -1
	queue_redraw()


func _draw() -> void:
	var rows := ceili(float(Inventory.slots.size()) / float(Inventory.HOTBAR))
	for index in Inventory.slots.size():
		var rect := Rect2((index % Inventory.HOTBAR) * STEP, (index / Inventory.HOTBAR) * STEP, 24, 24)
		HotbarHud.draw_slot(self, rect, Inventory.slots[index], index == picked or index == _hover)
	var shown := picked if picked >= 0 else _hover
	var card_y := rows * STEP + 6.0
	draw_style_box(UiKit.box("tooltip"), Rect2(0, card_y, Inventory.HOTBAR * STEP - 1, 58))
	if shown < 0 or str(Inventory.slots[shown]["id"]) == "":
		_line(Vector2(10, card_y + 16), "Наведите на предмет. Щелчок — взять, второй щелчок — поменять местами.", UiKit.MUTED, 280)
		return
	var slot: Dictionary = Inventory.slots[shown]
	var item := Data.by_id("items", str(slot["id"]))
	var tex := ItemIcon.texture(str(slot["id"]))
	if tex:
		draw_texture_rect(tex, Rect2(8, card_y + 8, 32, 32), false)
	else:
		draw_rect(Rect2(14, card_y + 14, 20, 20), UiKit.BRASS)
	var name := Loc.t(str(item.get("name", slot["id"])))
	if int(slot["count"]) > 1:
		name += "  ×%d" % int(slot["count"])
	_line(Vector2(48, card_y + 15), name, UiKit.GOLD, 200)
	var facts: Array[String] = [str(CATEGORY.get(str(item.get("category", "")), ""))]
	if int(item.get("price", 0)) > 0:
		facts.append("%d кр" % int(item["price"]))
	var edible: Dictionary = item.get("edible", {})
	if not edible.is_empty():
		facts.append("+%d сил" % int(edible.get("energy", 0)))
	_line(Vector2(48, card_y + 25), " · ".join(facts.filter(func(f: String) -> bool: return f != "")), Color("#9fb1b8"), 240)
	var desc := Loc.t(str(item.get("desc", "")))
	draw_multiline_string(UiKit.font(), Vector2(48, card_y + 36), desc, HORIZONTAL_ALIGNMENT_LEFT, 240, 8, 2,
		UiKit.PAPER)


func _line(at: Vector2, text: String, color: Color, width: float) -> void:
	draw_string(UiKit.font(), at + Vector2(0, 1), text, HORIZONTAL_ALIGNMENT_LEFT, width, 8, Color(0, 0, 0, 0.5))
	draw_string(UiKit.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, width, 8, color)
