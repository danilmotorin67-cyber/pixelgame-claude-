extends Area2D
class_name BigHull

# One of the big hulls in Wreck Bay (9): only a silver axe or better breaks it up.
var index: int = 0


func _ready() -> void:
	collision_layer = 9
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(44, 18)
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-24, -4), Vector2(22, -8), Vector2(18, 8), Vector2(-20, 8)]), Color("#4a3428"))
	for x in range(-18, 20, 6):
		draw_rect(Rect2(x, -14 + absi(x) / 4, 3, 16), Color("#6b4a32"))
	draw_rect(Rect2(-22, -3, 42, 2), Color("#8c6a4e"))
	draw_rect(Rect2(4, -20, 2, 14), Color("#3a2a20"))


func use_tool(player: Player, tool: String) -> String:
	if tool != "tool_axe":
		return ""
	match Crafting.chop_hull(index):
		"weak":
			return "Остов крепкий: такой разберёт только серебряный топор."
		"gone":
			return ""
		"done":
			player.spend_energy("axe")
			queue_free()
			return "Остов разобран: доски, плавник, железный лом и гвозди."
	player.spend_energy("axe")
	return "Старые шпангоуты трещат."
