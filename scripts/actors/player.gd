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
const TOOL_DURATION := 0.34

@onready var sprite: Sprite2D = $Body
@onready var tool_art: Node2D = $ToolArt


func _ready() -> void:
	if Game.player_state.is_empty():
		global_position = Router.spawn
	else:
		restore_state(Game.player_state)
	_update_sprite(false)


func _physics_process(delta: float) -> void:
	if Cutscenes.playing or Clock.paused:
		velocity = Vector2.ZERO
		return
	if tool_time > 0.0:
		tool_time = maxf(0.0, tool_time - delta)
		tool_art.queue_redraw()
	if _dodge_t > 0.0:
		_dodge_t -= delta
		move_and_slide()
		_update_sprite(true)
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.1:
		facing = dir.normalized()
	var spd := slow_speed if Input.is_action_pressed("walk_slow") else walk_speed
	if is_tired():
		spd *= float(Game.balance("fatigue_speed", 0.9))
	velocity = dir * spd
	move_and_slide()
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
	tool_time = TOOL_DURATION * (float(Game.balance("fatigue_tool_time", 1.25)) if is_tired() else 1.0)
	_update_sprite(false)
	tool_art.queue_redraw()


func max_health() -> float:
	return float(Game.balance("health_max", 100)) + 5.0 * float(Skills.level("diving"))


# Food restores energy and health (8.6); returns the eaten item id or "".
func eat_selected() -> String:
	var index := Inventory.selected_hotbar
	var id := str(Inventory.slots[index]["id"])
	var edible: Dictionary = Data.by_id("items", id).get("edible", {})
	if edible.is_empty() or not Inventory.take_slot(index, 1):
		return ""
	energy = minf(energy + float(edible.get("energy", 0)), Game.max_energy())
	health = minf(health + float(edible.get("health", 0)), max_health())
	return id


func _place_selected(at: Vector2) -> bool:
	if str(Data.by_id("items", Inventory.selected_id()).get("place", "")) == "":
		return false
	if global_position.distance_to(at) > Crafting.PLACE_REACH:
		return false
	if Crafting.place_selected(Router.current_map, at):
		var stations := get_tree().current_scene.get_node_or_null("Stations") as Stations
		if stations:
			stations.rebuild()
	return true


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
	if event.is_action_pressed("use_tool") and Router.current_map == "cape":
		var garden := get_tree().current_scene.get_node_or_null("Garden")
		if garden and garden.use_at(get_global_mouse_position(), self):
			get_viewport().set_input_as_handled()
			return
		if _place_selected(get_global_mouse_position()):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("dodge") and _dodge_t <= 0.0:
		_dodge_t = 0.18
		velocity = facing * dodge_speed
	if event.is_action_pressed("quick_eat"):
		var eaten := eat_selected()
		var hint := get_tree().current_scene.get_node_or_null("HUD/Hint") as Label
		if hint:
			hint.text = ("Съедено: %s" % Loc.t(str(Data.by_id("items", eaten)["name"]))) if eaten != "" \
				else "Это не едят. Даже на спор."
	if event.is_action_pressed("lantern"):
		lantern_on = not lantern_on
	if event.is_action_pressed("interact"):
		_try_interact()


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
