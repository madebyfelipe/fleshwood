extends Area2D
class_name FarmEnemy

signal route_finished
signal player_caught(body: Node)
signal repelled

const MOVE_SPEED := 132.0
const CHASE_SPEED := 186.0
const RETREAT_SPEED := 260.0

var _route_points: Array[Vector2] = []
var _route_index := 0
var _is_active := false
var _player: Node2D = null
var _vision_check: Callable = Callable()
var _light_check: Callable = Callable()
var _has_spotted_player := false
var _is_repelled := false
var _retreat_target := Vector2.ZERO


@onready var sprite: AnimatedSprite2D = $Body

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func start(spawn_position: Vector2, route_points: Array[Vector2], player: Node2D, vision_check: Callable, light_check: Callable) -> void:
	global_position = spawn_position
	_route_points = route_points.duplicate()
	_route_index = 0
	_player = player
	_vision_check = vision_check
	_light_check = light_check
	_has_spotted_player = false
	_is_repelled = false
	_retreat_target = spawn_position
	_is_active = not _route_points.is_empty()
	set_process(_is_active)

	if not _is_active:
		route_finished.emit()


func _process(delta: float) -> void:
	if not _is_active:
		return

	if not _has_spotted_player and _light_check.is_valid() and _light_check.call(global_position):
		_is_repelled = true

	if _is_repelled:
		_update_animation_state("fall")
		global_position = global_position.move_toward(_retreat_target, RETREAT_SPEED * delta)
		if global_position.distance_to(_retreat_target) <= 6.0:
			_is_active = false
			set_process(false)
			repelled.emit()
		return

	if not _has_spotted_player and _vision_check.is_valid() and _vision_check.call(global_position):
		_has_spotted_player = true

	if _has_spotted_player and is_instance_valid(_player):
		_update_animation_state("run")
		global_position = global_position.move_toward(_player.global_position, CHASE_SPEED * delta)
		return

	var target := _route_points[_route_index]
	_update_animation_state("idle")
	global_position = global_position.move_toward(target, MOVE_SPEED * delta)

	if global_position.distance_to(target) > 2.0:
		return

	global_position = target
	_route_index += 1
	if _route_index >= _route_points.size():
		_is_active = false
		set_process(false)
		route_finished.emit()


func _on_body_entered(body: Node) -> void:
	if _is_active:
		player_caught.emit(body)


func _update_animation_state(animation_name: String) -> void:
	if sprite.animation != animation_name:
		sprite.animation = animation_name
		sprite.play()
