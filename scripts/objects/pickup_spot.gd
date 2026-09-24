extends Area2D
class_name PickupSpot

const COLORS := {
	"kelp": [Color("#2f5a3a"), Color("#4e6e3a")], "red_kelp": [Color("#8a3a3a"), Color("#b0584a")],
	"driftwood": [Color("#6b4a32"), Color("#b08f6c")], "scallop_shell": [Color("#e9dcc6"), Color("#c9b89a")],
	"sea_glass": [Color("#3f7f8f"), Color("#9fd8d0")], "cork_float": [Color("#b0784a"), Color("#d8a870")],
	"pumice": [Color("#9a9ca3"), Color("#c9c8c2")], "trash": [Color("#45464e"), Color("#6f6a60")],
	"amber": [Color("#c9782a"), Color("#ffc85a")],
}
const FORAGE_COLOR := [Color("#4e6e3a"), Color("#e9dcc6")]

var entry: Dictionary = {}
var beach: bool = false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	collision.shape = shape
	add_child(collision)


func set_available(dry: bool) -> void:
	visible = dry
	collision_layer = 8 if dry else 0


func _draw() -> void:
	var colors: Array = COLORS.get(str(entry.get("item", "")), FORAGE_COLOR)
	draw_rect(Rect2(-4, -1, 8, 3), colors[0])
	draw_rect(Rect2(-2, -3, 4, 2), colors[1])
	draw_rect(Rect2(-1, -2, 1, 1), Color("#fff8e1"))


func interact(_player: Player) -> void:
	var hint: Label = get_tree().current_scene.get_node_or_null("HUD/Hint")
	var id := str(entry["item"])
	var ok := Sea.collect_gift(Router.current_map, entry) if beach \
		else Farm.collect_wild(Router.current_map, entry)
	if hint:
		var name := Loc.t(str(Data.by_id("items", id).get("name", id)))
		hint.text = ("Подобрано: %s" % name) if ok else "Рюкзак полон."
	if ok:
		queue_free()
