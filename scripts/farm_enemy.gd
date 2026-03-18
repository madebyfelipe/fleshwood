extends Area2D
class_name FarmEnemy

signal route_finished
signal player_caught(body: Node)
signal repelled
signal player_spotted

const MOVE_SPEED    := 132.0
const CHASE_SPEED   := 186.0
const RETREAT_SPEED := 260.0

var _move_speed  := MOVE_SPEED
var _chase_speed := CHASE_SPEED

var _route_points: Array[Vector2] = []
var _route_index := 0
var _is_active := false
var _player: Node2D = null
var _vision_check: Callable = Callable()
var _light_check: Callable = Callable()
var _has_spotted_player := false
var _is_repelled := false
var _retreat_target := Vector2.ZERO
var _last_dir := Vector2.DOWN

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_sprite.sprite_frames = _build_sprite_frames()
	_play_idle(_last_dir)


func _build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")

	var walk_base := "res://assets/Characters/goatman/animations/scary-walk/"
	var rot_base  := "res://assets/Characters/goatman/rotations/"

	# Movimento: scary-walk nas 4 direções cardinais
	for dir: String in ["south", "north", "east", "west"]:
		var anim := StringName("walk_" + dir)
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 8.0)
		sf.set_animation_loop(anim, true)
		for i: int in 8:
			sf.add_frame(anim, load(walk_base + dir + "/frame_%03d.png" % i))

	# Idle: rotations em 8 direções (1 frame estático cada)
	var rot_map: Dictionary = {
		&"idle_south":    "south.png",
		&"idle_north":    "north.png",
		&"idle_east":     "east.png",
		&"idle_west":     "west.png",
		&"idle_se":       "south-east.png",
		&"idle_sw":       "south-west.png",
		&"idle_ne":       "north-east.png",
		&"idle_nw":       "north-west.png",
	}
	for anim: StringName in rot_map:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 1.0)
		sf.set_animation_loop(anim, false)
		sf.add_frame(anim, load(rot_base + rot_map[anim]))

	return sf


func start(spawn_position: Vector2, route_points: Array[Vector2], player: Node2D, vision_check: Callable, light_check: Callable, move_speed: float = MOVE_SPEED, chase_speed: float = CHASE_SPEED, spotted: bool = false) -> void:
	_move_speed  = move_speed
	_chase_speed = chase_speed
	global_position = spawn_position
	_route_points = route_points.duplicate()
	_route_index = 0
	_player = player
	_vision_check = vision_check
	_light_check = light_check
	_has_spotted_player = spotted
	_is_repelled = false
	_retreat_target = spawn_position
	_is_active = not _route_points.is_empty() or spotted
	set_process(_is_active)

	if spotted:
		player_spotted.emit()
	elif not _is_active:
		route_finished.emit()


func _process(delta: float) -> void:
	if not _is_active:
		return

	if _light_check.is_valid() and _light_check.call(global_position):
		_is_repelled = true

	if _is_repelled:
		var dir := (global_position - _retreat_target).normalized()
		_play_walk(dir if dir != Vector2.ZERO else -_last_dir)
		global_position = global_position.move_toward(_retreat_target, RETREAT_SPEED * delta)
		if global_position.distance_to(_retreat_target) <= 6.0:
			_is_active = false
			set_process(false)
			repelled.emit()
		return

	if not _has_spotted_player and _vision_check.is_valid() and _vision_check.call(global_position):
		_has_spotted_player = true
		player_spotted.emit()

	if _has_spotted_player and is_instance_valid(_player):
		var dir := (_player.global_position - global_position).normalized()
		_last_dir = dir
		_play_walk(dir)
		global_position = global_position.move_toward(_player.global_position, _chase_speed * delta)
		return

	var target := _route_points[_route_index]
	var dir := (target - global_position).normalized()
	if dir != Vector2.ZERO:
		_last_dir = dir
	_play_walk(dir)
	global_position = global_position.move_toward(target, _move_speed * delta)

	if global_position.distance_to(target) > 2.0:
		return

	global_position = target
	_route_index += 1
	if _route_index >= _route_points.size():
		_is_active = false
		set_process(false)
		_play_idle(_last_dir)
		route_finished.emit()


# Toca walk_south/north/east/west pelo eixo dominante do vetor
func _play_walk(dir: Vector2) -> void:
	_sprite.flip_h = false
	var anim: StringName
	if absf(dir.x) >= absf(dir.y):
		anim = &"walk_east" if dir.x >= 0.0 else &"walk_west"
	else:
		anim = &"walk_south" if dir.y >= 0.0 else &"walk_north"
	if _sprite.animation != anim:
		_sprite.play(anim)


# Idle em 8 direções a partir das rotations
func _play_idle(dir: Vector2) -> void:
	_sprite.flip_h = false
	var deg := fposmod(rad_to_deg(dir.angle()), 360.0)
	var anim: StringName
	if deg < 22.5 or deg >= 337.5:
		anim = &"idle_east"
	elif deg < 67.5:
		anim = &"idle_se"
	elif deg < 112.5:
		anim = &"idle_south"
	elif deg < 157.5:
		anim = &"idle_sw"
	elif deg < 202.5:
		anim = &"idle_west"
	elif deg < 247.5:
		anim = &"idle_nw"
	elif deg < 292.5:
		anim = &"idle_north"
	else:
		anim = &"idle_ne"
	_sprite.play(anim)


func _on_body_entered(body_node: Node) -> void:
	if _is_active:
		player_caught.emit(body_node)
