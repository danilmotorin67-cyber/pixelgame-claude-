extends Area2D
class_name StationObject

var uid: int = 0
var station_id: String = ""


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 16)
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	match station_id:
		"workbench":
			draw_rect(Rect2(-10, -6, 20, 4), Color("#8c6a4e"))
			draw_rect(Rect2(-9, -2, 2, 7), Color("#6b4a32"))
			draw_rect(Rect2(7, -2, 2, 7), Color("#6b4a32"))
			draw_rect(Rect2(-6, -8, 5, 2), Color("#9a9ca3"))
		"hearth":
			draw_rect(Rect2(-9, -3, 18, 7), Color("#45464e"))
			draw_rect(Rect2(-5, -8, 10, 6), Color("#2a2a30"))
			draw_rect(Rect2(-3, -1, 6, 3), Color("#e9a64a"))
		"compost_pit":
			draw_rect(Rect2(-10, -5, 20, 10), Color("#6b4a32"))
			draw_rect(Rect2(-8, -3, 16, 6), Color("#4a3428"))
			draw_rect(Rect2(-6, -2, 5, 2), Color("#4e6e3a"))
		"chest", "big_chest", "receiver_chest":
			draw_rect(Rect2(-8, -6, 16, 11), Color("#6b4a32") if station_id == "chest" else Color("#4a3428"))
			draw_rect(Rect2(-8, -6, 16, 3), Color("#8c6a4e"))
			draw_rect(Rect2(-1, -3, 2, 3), Color("#ffc85a") if station_id != "receiver_chest" else Color("#b87333"))
		"tree":
			_draw_tree()
		"decor":
			_draw_decor()
		_:
			_draw_generic()
	var obj := Crafting.find(Router.current_map, uid)
	if Crafting.ready_jobs(obj) > 0 or not obj.get("stock", []).is_empty() or int(obj.get("fruit", 0)) > 0:
		draw_circle(Vector2(8, -10), 3, Color("#ffc85a"))


# Stations of 19.2 as small pixel machines: body, top and an accent in the station's colours.
const LOOKS := {
	"forge": ["#45464e", "#2a2a30", "#e9643a"], "renderer": ["#6b4a32", "#45464e", "#e9a64a"],
	"settling_tank": ["#8c6a4e", "#6b4a32", "#d9c07a"], "salt_pan": ["#9a9ca3", "#dfe9ea", "#e9a64a"],
	"brine_barrel": ["#6b4a32", "#8c6a4e", "#dfe9ea"], "smokehouse": ["#4a3428", "#2a2a30", "#9a9ca3"],
	"sawhorse": ["#8c6a4e", "#6b4a32", "#e4d9bd"], "tar_kiln": ["#2a2a30", "#45464e", "#8a3a2e"],
	"scutcher": ["#8c6a4e", "#b08f6c", "#e4d9bd"], "spinning_wheel": ["#8c6a4e", "#6b4a32", "#eee8da"],
	"loom": ["#6b4a32", "#8c6a4e", "#e4d9bd"], "ash_kiln": ["#45464e", "#9a9ca3", "#e9a64a"],
	"drying_rack": ["#8c6a4e", "#6b4a32", "#4e6e3a"], "glass_furnace": ["#8a3a2e", "#45464e", "#9fd3e0"],
	"optical_bench": ["#6b4a32", "#b87333", "#9fd3e0"], "carpentry_table": ["#8c6a4e", "#6b4a32", "#9a9ca3"],
	"stonecutter_table": ["#9a9ca3", "#6b6b73", "#dfe9ea"], "candle_mold": ["#b87333", "#8c6a4e", "#ffe9a8"],
	"butter_churn": ["#8c6a4e", "#b08f6c", "#ffe9a8"], "cheese_press": ["#8c6a4e", "#6b4a32", "#e9d27a"],
	"brewery": ["#6b4a32", "#b87333", "#c9a24a"], "wine_vat": ["#6b4a32", "#8a3a2e", "#7a2a4a"],
	"preserve_jars": ["#9fd3e0", "#dfe9ea", "#8a3a2e"], "still": ["#b87333", "#8c5a2a", "#dfe9ea"],
	"seed_box": ["#8c6a4e", "#6b4a32", "#4e6e3a"], "herbal_table": ["#6b4a32", "#4e6e3a", "#ae8dad"],
	"kitchen_stove": ["#2a2a30", "#45464e", "#e9a64a"], "mill": ["#9a9ca3", "#6b4a32", "#eee8da"],
	"cellar_barrel": ["#6b4a32", "#4a3428", "#b87333"], "beehive": ["#c9a24a", "#8c6a4e", "#2a2a30"],
	"eider_nest": ["#8c6a4e", "#e9d27a", "#6b5a4a"], "stone_wall": ["#9a9ca3", "#6b6b73", "#6b6b73"],
	"gull_scarer": ["#8c6a4e", "#dfe9ea", "#8a3a2e"], "watering_barrel": ["#6b4a32", "#3f7f8f", "#9a9ca3"],
	"cistern": ["#9a9ca3", "#3f7f8f", "#6b6b73"], "wind_pump": ["#8c6a4e", "#dfe9ea", "#9a9ca3"],
	"keeper_scarecrow": ["#8c6a4e", "#2f4a5c", "#e4d9bd"],
}


func _draw_generic() -> void:
	var look: Array = LOOKS.get(station_id, ["#8c6a4e", "#6b4a32", "#e4d9bd"])
	draw_rect(Rect2(-9, -4, 18, 9), Color(str(look[0])))
	draw_rect(Rect2(-9, -7, 18, 3), Color(str(look[1])))
	draw_rect(Rect2(-3, -1, 6, 3), Color(str(look[2])))
	if station_id in ["gull_scarer", "keeper_scarecrow", "wind_pump"]:
		draw_rect(Rect2(-1, -18, 2, 14), Color(str(look[0])))
		draw_rect(Rect2(-7, -16, 14, 2), Color(str(look[1])))


func _draw_tree() -> void:
	var obj := Crafting.find(Router.current_map, uid)
	var info := Crafting.tree_info(obj)
	if str(obj.get("tree", "")) == "bog_cranberry":
		draw_rect(Rect2(-24, -24, 48, 48), Color("#3f5a36"))
		draw_rect(Rect2(-20, -20, 40, 40), Color("#4e6e3a"))
		if int(obj.get("fruit", 0)) > 0:
			for i in 8:
				draw_rect(Rect2(-16 + (i % 4) * 9, -12 + (i / 4) * 14, 2, 2), Color("#8a3a2e"))
		return
	var grown := bool(obj.get("grown", false))
	var h := 18.0 if grown else 6.0 + 12.0 * float(obj.get("age", 0)) / float(info.get("days", 28))
	draw_rect(Rect2(-1, -h * 0.5, 2, h * 0.5 + 4), Color("#6b4a32"))
	draw_circle(Vector2(0, -h * 0.6), h * 0.4, Color("#4e6e3a") if not str(obj.get("tree", "")).begins_with("bush") else Color("#5e7e4a"))
	if int(obj.get("fruit", 0)) > 0:
		var fruit := {"sea_buckthorn": "#e9a64a", "rowan_berry": "#c0392b", "apple": "#d64a3a", "cloudberry": "#f0b04a",
			"blueberry": "#3a4a8a", "lingonberry": "#a0283a"}.get(str(info.get("fruit", "")), "#c0392b") as String
		for i in 4:
			draw_rect(Rect2(-5 + i * 3, -h * 0.6 + (i % 2) * 3, 2, 2), Color(fruit))


func _draw_decor() -> void:
	var obj := Crafting.find(Router.current_map, uid)
	var id := str(obj.get("item", ""))
	var tint := Color.from_hsv(float(absi(id.hash()) % 360) / 360.0, 0.35, 0.75)
	match id:
		"fence_wood", "fence_stone", "fence_iron":
			var c := {"fence_wood": "#8c6a4e", "fence_stone": "#9a9ca3", "fence_iron": "#2a2a30"}[id] as String
			draw_rect(Rect2(-8, -2, 16, 2), Color(c))
			draw_rect(Rect2(-7, -8, 2, 10), Color(c))
			draw_rect(Rect2(5, -8, 2, 10), Color(c))
		"stone_path":
			draw_rect(Rect2(-7, -5, 14, 10), Color("#8c8a8a"))
		"statue_mourning":
			draw_rect(Rect2(-6, -2, 12, 6), Color("#9a9ca3"))
			draw_rect(Rect2(-3, -20, 6, 18), Color("#b9bcc3"))
			draw_circle(Vector2(0, -22), 3, Color("#b9bcc3"))
		"armeria", "heather":
			var petal := Color("#e07aa0") if id == "armeria" else Color("#9a6ab8")
			draw_rect(Rect2(-4, -2, 8, 4), Color("#4e6e3a"))
			for i in 4:
				draw_rect(Rect2(-5 + i * 3, -6 + (i % 2) * 2, 2, 2), petal)
		"memory_lantern":
			draw_rect(Rect2(-1, -14, 2, 16), Color("#2a2a30"))
			draw_rect(Rect2(-3, -18, 6, 5), Color("#ffe9a8"))
		_:
			draw_rect(Rect2(-6, -6, 12, 10), tint)
			draw_rect(Rect2(-6, -6, 12, 2), tint.lightened(0.3))


func interact(_player: Player) -> void:
	var hud: CanvasLayer = get_tree().current_scene.get_node("HUD")
	StationPanel.open(hud, uid)
