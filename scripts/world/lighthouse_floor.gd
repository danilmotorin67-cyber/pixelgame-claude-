extends Node2D

const TILE := 16
const WIDTH := 20
const HEIGHT := 12
const TOWER_DOOR := Vector2(724, 290)
const LAYOUT := {
	"lh_1": [["stairs_up", 17, 2], ["exit_door", 10, 11], ["fortuna", 10, 1]],
	"lh_2": [["stairs_down", 2, 2], ["stairs_up", 17, 2], ["barrel", 5, 5], ["repair", 13, 5]],
	"lh_3": [["stairs_down", 2, 2], ["stairs_up", 17, 2], ["desk", 10, 3], ["bunk", 4, 8],
		["barometer", 14, 2], ["calendar", 7, 2]],
	"lh_4": [["stairs_down", 2, 2], ["lamp", 10, 5], ["mechanism", 6, 6], ["glass", 14, 4], ["gallery", 10, 11]],
}
const TITLES := {"lh_1": "Маяк · прихожая", "lh_2": "Маяк · кладовая", "lh_3": "Маяк · вахтенная",
	"lh_4": "Маяк · фонарная"}

var width: int = WIDTH


func _ready() -> void:
	var bounds := StaticBody2D.new()
	bounds.name = "Walls"
	bounds.collision_layer = 1
	bounds.collision_mask = 0
	add_child(bounds)
	_wall(bounds, Vector2(WIDTH * TILE / 2.0, TILE / 2.0), Vector2(WIDTH * TILE, TILE))
	_wall(bounds, Vector2(WIDTH * TILE / 2.0, HEIGHT * TILE - TILE / 2.0), Vector2(WIDTH * TILE, TILE))
	_wall(bounds, Vector2(TILE / 2.0, HEIGHT * TILE / 2.0), Vector2(TILE, HEIGHT * TILE))
	_wall(bounds, Vector2(WIDTH * TILE - TILE / 2.0, HEIGHT * TILE / 2.0), Vector2(TILE, HEIGHT * TILE))
	var map_id := Router.current_map
	for entry in LAYOUT.get(map_id, []):
		var obj := TowerObject.new()
		obj.kind = str(entry[0])
		obj.name = obj.kind.capitalize().replace(" ", "")
		obj.position = Vector2(int(entry[1]) * TILE + 8, int(entry[2]) * TILE + 8)
		add_child(obj)
	if map_id == "lh_4":
		var checklist := RitualChecklist.new()
		checklist.name = "RitualChecklist"
		get_parent().get_node("HUD").add_child.call_deferred(checklist)
	queue_redraw()


func _wall(body: StaticBody2D, at: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = at
	body.add_child(collision)


func _draw() -> void:
	draw_rect(Rect2(-160, -120, WIDTH * TILE + 320, HEIGHT * TILE + 240), Color("#121a26"))
	for y in HEIGHT:
		for x in WIDTH:
			var edge := x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1
			var at := Vector2(x * TILE, y * TILE)
			if edge:
				draw_rect(Rect2(at, Vector2(TILE, TILE)), Color("#9a9ca3"))
				draw_rect(Rect2(at + Vector2(1, 1), Vector2(TILE - 2, 6)), Color("#c9c8c2"))
			else:
				draw_rect(Rect2(at, Vector2(TILE, TILE)), Color("#6b4a32") if (x + y) % 2 == 0 else Color("#735037"))
				draw_rect(Rect2(at + Vector2(0, 15), Vector2(TILE, 1)), Color("#4a3428"))
	if Router.current_map == "lh_4":
		for x in range(1, WIDTH - 1):
			draw_rect(Rect2(x * TILE + 2, 2, 12, 10), Color("#2f5a76") if Game.flag("lantern_glass_repaired") or x % 3 != 0
				else Color("#45464e"))
