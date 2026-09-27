extends Control
class_name HotbarHud

const SLOT_STEP := 25
const INK := Color("#121a26")
const BORDER := Color("#6c6e76")
const GOLD := Color("#ffc85a")


func _ready() -> void:
	Events.inventory_changed.connect(queue_redraw)
	Events.farm_changed.connect(queue_redraw)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := int(event.position.x / SLOT_STEP)
		if index >= 0 and index < Inventory.HOTBAR:
			Inventory.select_hotbar(index)
			accept_event()


func _draw() -> void:
	draw_style_box(UiKit.box("panel"), Rect2(-5, -4, 310, 33))
	for index in Inventory.HOTBAR:
		var x := index * SLOT_STEP + 1
		var selected := index == Inventory.selected_hotbar
		HotbarHud.draw_slot(self, Rect2(x, 1, 24, 24), Inventory.slots[index] if index < Inventory.slots.size() else {},
			selected)
		var slot: Dictionary = Inventory.slots[index] if index < Inventory.slots.size() else {}
		if str(slot.get("id", "")) == "tool_can":
			var share := float(Farm.can_water) / float(maxi(Farm.can_capacity(), 1))
			draw_rect(Rect2(x + 4, 21, 16, 2), Color("#1b2b3c"))
			draw_rect(Rect2(x + 4, 21, roundi(16.0 * share), 2), Color("#6fb3c9"))


# One inventory slot: the frame (gold when selected), the item icon, its quality star and count.
static func draw_slot(canvas: CanvasItem, rect: Rect2, slot: Dictionary, selected: bool) -> void:
	var frame := "slot_selected" if selected and UiKit.has_box("slot_selected") else "slot"
	canvas.draw_style_box(UiKit.box(frame if UiKit.has_box(frame) else "inset"), rect)
	if selected and frame != "slot_selected":
		canvas.draw_rect(rect.grow(-0.5), GOLD, false, 1.0)
	var id := str(slot.get("id", ""))
	if id == "":
		return
	var cell := Rect2(rect.position + (rect.size - Vector2(16, 16)) / 2.0, Vector2(16, 16))
	if not ItemIcon.draw(canvas, id, cell):
		canvas.draw_rect(cell.grow(-3), Color("#b08f6c"))
		canvas.draw_rect(cell.grow(-5), Color("#ddd3bf"))
	var quality := int(slot.get("quality", 0))
	if quality > 0:
		UiKit.draw_icon(canvas, ["star_silver", "star_gold", "star_violet"][clampi(quality - 1, 0, 2)],
			rect.position + Vector2(1, rect.size.y - 10), 9.0)
	if int(slot.get("count", 0)) > 1:
		var label := str(slot["count"])
		var at := rect.position + Vector2(rect.size.x - 2, rect.size.y - 2)
		canvas.draw_string(UiKit.font(), at + Vector2(-20, 1), label, HORIZONTAL_ALIGNMENT_RIGHT, 20, 8, Color(0, 0, 0, 0.8))
		canvas.draw_string(UiKit.font(), at + Vector2(-20, 0), label, HORIZONTAL_ALIGNMENT_RIGHT, 20, 8, Color("#fff8e1"))
