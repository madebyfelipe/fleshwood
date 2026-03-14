extends CharacterBody2D
class_name PlayerController

enum MovementState {
	NORMAL,
	SPRINTING,
	EXHAUSTED,
}

const MOVE_SPEED := 96.0
const SPRINT_SPEED := 300.0
const EXHAUSTED_SPEED := 52.0
const GROUND_ACCELERATION := 540.0
const GROUND_DECELERATION := 420.0
const TURN_ACCELERATION := 360.0
const SPRINT_ACCELERATION := 860.0
const SPRINT_DECELERATION := 1600.0
const SPRINT_TURN_ACCELERATION := 1400.0
const MAX_STAMINA := 10.0
const STAMINA_DRAIN_PER_SECOND := 3.2
const STAMINA_REGEN_PER_SECOND := 1.4
const EXHAUSTED_REGEN_DELAY := 2.4
const EXHAUSTED_EXIT_STAMINA_RATIO := 0.35
const CAMERA_SMOOTHING_SPEED := 14.0
@onready var camera: Camera2D = $Camera2D
@onready var sprite: AnimatedSprite2D = $Body
@onready var held_item_visual: Polygon2D = $HeldItemVisual
@onready var held_item_label: Label = $HeldItemLabel

var facing_direction := Vector2.DOWN
var movement_state := MovementState.NORMAL
var _movement_locked := false
var _default_camera_smoothing := true
var _stamina := MAX_STAMINA
var _regen_cooldown := 0.0
var _external_speed_multiplier := 1.0
var _external_stamina_regen_multiplier := 1.0


func _ready() -> void:
	camera.position_smoothing_speed = CAMERA_SMOOTHING_SPEED
	_default_camera_smoothing = camera.position_smoothing_enabled
	_ensure_input_actions()


func _physics_process(delta: float) -> void:
	var input_vector := _get_input_vector()
	var wants_to_sprint := _wants_to_sprint(input_vector)
	_update_movement_state(delta, input_vector, wants_to_sprint)
	_apply_movement(delta, input_vector)

	if input_vector != Vector2.ZERO:
		facing_direction = input_vector

	_update_animation(input_vector)
	move_and_slide()


func _ensure_input_actions() -> void:
	var actions := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_F],
		"sprint": [KEY_SHIFT],
	}

	for action_name in actions.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		for keycode in actions[action_name]:
			if _action_has_key(action_name, keycode):
				continue

			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action_name, event)

	if not _action_has_mouse_button("interact", MOUSE_BUTTON_LEFT):
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("interact", mouse_event)


func _action_has_key(action_name: String, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true

	return false


func _action_has_mouse_button(action_name: String, button_index: MouseButton) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventMouseButton and event.button_index == button_index:
			return true
	return false


func set_movement_locked(is_locked: bool) -> void:
	_movement_locked = is_locked
	if is_locked:
		movement_state = MovementState.NORMAL
		_regen_cooldown = max(_regen_cooldown, 0.0)
		_stamina = clamp(_stamina, 0.0, MAX_STAMINA)
		velocity = Vector2.ZERO


func snap_camera_for_room_transition() -> void:
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	_update_camera_anchor()


func restore_camera_after_room_transition() -> void:
	_update_camera_anchor()
	camera.reset_smoothing()
	camera.position_smoothing_enabled = _default_camera_smoothing


func _get_input_vector() -> Vector2:
	if _movement_locked:
		return Vector2.ZERO

	var horizontal := Input.get_axis("move_left", "move_right")
	var vertical := Input.get_axis("move_up", "move_down")
	var direction := Vector2(horizontal, vertical)
	return direction.normalized() if direction.length() > 1.0 else direction


func _wants_to_sprint(input_vector: Vector2) -> bool:
	return (
		not _movement_locked
		and input_vector != Vector2.ZERO
		and Input.is_action_pressed("sprint")
	)


func _update_movement_state(delta: float, input_vector: Vector2, wants_to_sprint: bool) -> void:
	var has_input := input_vector != Vector2.ZERO
	var exhausted_exit_stamina := MAX_STAMINA * EXHAUSTED_EXIT_STAMINA_RATIO

	if movement_state == MovementState.EXHAUSTED:
		if _regen_cooldown > 0.0:
			_regen_cooldown = max(_regen_cooldown - delta, 0.0)
		else:
			_stamina = min(_stamina + STAMINA_REGEN_PER_SECOND * delta, MAX_STAMINA)
			if _stamina >= exhausted_exit_stamina:
				movement_state = MovementState.NORMAL
		return

	if wants_to_sprint and has_input and _stamina > 0.0:
		movement_state = MovementState.SPRINTING
		_stamina = max(_stamina - STAMINA_DRAIN_PER_SECOND * delta, 0.0)
		if _stamina <= 0.0:
			_enter_exhausted_state()
	elif has_input:
		movement_state = MovementState.NORMAL
		_regenerate_stamina(delta)
	else:
		movement_state = MovementState.NORMAL
		_regenerate_stamina(delta)


func _apply_movement(delta: float, input_vector: Vector2) -> void:
	var target_velocity := input_vector * _get_target_speed()
	var rate := _get_acceleration_rate(input_vector)
	velocity = velocity.move_toward(target_velocity, rate * delta)

	if input_vector == Vector2.ZERO and velocity.length_squared() < 1.0:
		velocity = Vector2.ZERO


func _get_acceleration_rate(input_vector: Vector2) -> float:
	if input_vector == Vector2.ZERO:
		if movement_state == MovementState.SPRINTING:
			return SPRINT_DECELERATION
		return GROUND_DECELERATION

	if velocity == Vector2.ZERO:
		if movement_state == MovementState.SPRINTING:
			return SPRINT_ACCELERATION
		return GROUND_ACCELERATION

	var desired_direction := input_vector.normalized()
	var current_direction := velocity.normalized()
	if desired_direction.dot(current_direction) < 0.0:
		if movement_state == MovementState.SPRINTING:
			return SPRINT_TURN_ACCELERATION
		return TURN_ACCELERATION

	if movement_state == MovementState.SPRINTING:
		return SPRINT_ACCELERATION
	return GROUND_ACCELERATION


func _get_target_speed() -> float:
	var base_speed := MOVE_SPEED
	match movement_state:
		MovementState.SPRINTING:
			base_speed = SPRINT_SPEED
		MovementState.EXHAUSTED:
			base_speed = EXHAUSTED_SPEED
	return base_speed * _external_speed_multiplier


func _regenerate_stamina(delta: float) -> void:
	if _regen_cooldown > 0.0:
		_regen_cooldown = max(_regen_cooldown - delta, 0.0)
		return

	_stamina = min(_stamina + STAMINA_REGEN_PER_SECOND * _external_stamina_regen_multiplier * delta, MAX_STAMINA)


func _enter_exhausted_state() -> void:
	movement_state = MovementState.EXHAUSTED
	_regen_cooldown = EXHAUSTED_REGEN_DELAY


func _update_animation(input_vector: Vector2) -> void:
	var is_moving := input_vector != Vector2.ZERO

	if is_moving:
		if movement_state == MovementState.SPRINTING:
			sprite.animation = "run"
		elif movement_state == MovementState.EXHAUSTED:
			sprite.animation = "exhausted"
		else:
			sprite.animation = "walk"

		if not sprite.is_playing():
			sprite.play()
	else:
		sprite.animation = "idle"
		if not sprite.is_playing():
			sprite.play()


func _update_camera_anchor() -> void:
	camera.global_position = global_position.round()

func set_held_item(item_id: String, short_label: String, color: Color) -> void:
	held_item_label.text = short_label
	held_item_visual.color = color
	held_item_visual.visible = item_id != ""
	held_item_label.visible = item_id != ""


func get_stamina_ratio() -> float:
	return _stamina / MAX_STAMINA


func get_facing_direction() -> Vector2:
	return facing_direction.normalized() if facing_direction != Vector2.ZERO else Vector2.DOWN


func is_stamina_on_cooldown() -> bool:
	return movement_state == MovementState.EXHAUSTED or _regen_cooldown > 0.0


func is_sprinting() -> bool:
	return movement_state == MovementState.SPRINTING


func is_exhausted() -> bool:
	return movement_state == MovementState.EXHAUSTED


func set_survival_modifiers(speed_multiplier: float, stamina_regen_multiplier: float) -> void:
	_external_speed_multiplier = clamp(speed_multiplier, 0.35, 1.2)
	_external_stamina_regen_multiplier = clamp(stamina_regen_multiplier, 0.1, 2.0)
