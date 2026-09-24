extends Control

const SLOT_STEP := 25
const INK := Color("#121a26")
const BORDER := Color("#6c6e76")
const GOLD := Color("#ffc85a")


func _ready() -> void:
	Events.inventory_changed.connect(queue_redraw)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := int(event.position.x / SLOT_STEP)
		if index >= 0 and index < Inventory.HOTBAR:
			Inventory.select_hotbar(index)
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(-4, -3, 308, 33), INK)
	draw_rect(Rect2(-4, -3, 308, 1), Color("#b08f6c"))
	draw_rect(Rect2(-4, 29, 308, 1), Color("#b08f6c"))
	for index in Inventory.HOTBAR:
		var x := index * SLOT_STEP + 1
		var selected := index == Inventory.selected_hotbar
		draw_rect(Rect2(x, 1, 23, 26), GOLD if selected else BORDER)
		draw_rect(Rect2(x + 1, 2, 21, 24), Color("#24405a") if selected else Color("#1b2b3c"))
		var slot: Dictionary = Inventory.slots[index]
		var id := str(slot["id"])
		if id != "":
			_icon(x + 4, 5, id)
			if int(slot["count"]) > 1:
				var label := str(slot["count"])
				draw_string(ThemeDB.fallback_font, Vector2(x + 21, 24), label,
					HORIZONTAL_ALIGNMENT_RIGHT, 18, 8, Color("#fff8e1"))
		if index < 10:
			draw_rect(Rect2(x + 2, 3, 2, 1), GOLD if selected else Color("#9a9ca3"))


func _icon(x: int, y: int, id: String) -> void:
	if id == "tool_hoe":
		_px(x + 4, y, 2, 14, Color("#b08f6c"))
		_px(x + 1, y + 1, 9, 2, Color("#c9c8c2"))
		_px(x + 9, y + 1, 2, 5, Color("#6c6e76"))
	elif id == "tool_can":
		_px(x + 1, y + 5, 13, 9, Color("#45464e"))
		_px(x + 2, y + 6, 11, 7, Color("#3f7f8f"))
		_px(x + 4, y + 2, 6, 3, Color("#9a9ca3"))
		_px(x + 11, y + 4, 5, 2, Color("#c9c8c2"))
	elif id.begins_with("seed_"):
		_px(x + 3, y + 6, 10, 9, Color("#6b4a33"))
		_px(x + 4, y + 5, 8, 8, Color("#d8c49a"))
		_px(x + 7, y + 3, 2, 4, Color("#4e6e3a"))
		_px(x + 9, y + 3, 3, 2, Color("#7a964c"))
	elif id.begins_with("bread_"):
		_px(x + 1, y + 6, 14, 8, Color("#6b4a33"))
		_px(x + 2, y + 4, 12, 9, Color("#e9a64a"))
		_px(x + 3, y + 5, 8, 2, Color("#ffe9a8"))
	else:
		_px(x + 3, y + 4, 11, 11, Color("#b08f6c"))
		_px(x + 5, y + 6, 7, 7, Color("#ddd3bf"))
		_px(x + 7, y + 8, 3, 3, Color("#c9a24a"))


func _px(x: int, y: int, w: int, h: int, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)
