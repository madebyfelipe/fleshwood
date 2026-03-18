extends CharacterBody2D
class_name PlayerController

signal axe_impact

enum MovementState {
	NORMAL,
	SPRINTING,
	EXHAUSTED,
}

const MOVE_SPEED := 96.0
const SPRINT_SPEED := 150.0
const EXHAUSTED_SPEED := 52.0
const GROUND_ACCELERATION := 540.0
const GROUND_DECELERATION := 420.0
const TURN_ACCELERATION := 360.0
const SPRINT_ACCELERATION := 860.0
const SPRINT_DECELERATION := 3000.0
const SPRINT_TURN_ACCELERATION := 1400.0
const MAX_STAMINA := 10.0
const STAMINA_DRAIN_PER_SECOND := 3.2
const STAMINA_REGEN_PER_SECOND := 1.4
const EXHAUSTED_REGEN_DELAY := 2.4
const EXHAUSTED_EXIT_STAMINA_RATIO := 0.35
const CAMERA_SMOOTHING_SPEED := 14.0
@onready var camera: Camera2D = $Camera2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
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
var _animation_speed_multiplier := 1.0
var _footstep_player: AudioStreamPlayer
var _footstep_timer := 0.0
var _swing_axe_player: AudioStreamPlayer
var _is_swinging := false
var _attack_cooldown_frames := 0

# ── Ansiedade (chase sequence) ────────────────────────────────────────────────
var _anxiety_intensity := 0.0
var _shake_time := 0.0
const SHAKE_MAX_OFFSET := 5.0
const SHAKE_FREQUENCY := 22.0
const ZOOM_PULSE_MAGNITUDE := 0.04
const ZOOM_PULSE_FREQUENCY := 1.8

# ── Lanterna ───────────────────────────────────────────────────────────────────
const _FLASHLIGHT_SHADER := """
shader_type canvas_item;
varying float v_y;
varying float v_x;
void vertex() {
	v_y = VERTEX.y;
	v_x = VERTEX.x;
}
void fragment() {
	float len = 320.0;
	float t = clamp(v_y / len, 0.0, 1.0);
	float hw = 80.0 * t;
	float edge_t = hw > 0.0 ? clamp(abs(v_x) / hw, 0.0, 1.0) : 1.0;
	float edge_soft = 1.0 - smoothstep(0.6, 1.0, edge_t);
	float length_fade = 1.0 - pow(t, 1.4);
	COLOR.a *= length_fade * edge_soft;
}
"""
var _flashlight_cone: Polygon2D = null
var _flashlight_on := false


func _ready() -> void:
	camera.position_smoothing_speed = CAMERA_SMOOTHING_SPEED
	_default_camera_smoothing = camera.position_smoothing_enabled
	_ensure_input_actions()
	_setup_footstep_audio()
	_setup_axe_animation()
	_setup_idle_animations()
	_setup_run_animations()
	_setup_flashlight_cone()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_frame_changed)


func _setup_idle_animations() -> void:
	var frames := animated_sprite.sprite_frames
	for dir in ["east", "north", "south", "west"]:
		var anim := StringName("idle_" + dir)
		if frames.has_animation(anim):
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 6.0)
		frames.set_animation_loop(anim, true)
		for i in range(4):
			var path := "res://assets/Characters/Prota/animations/breathing-idle/%s/frame_%03d.png" % [dir, i]
			frames.add_frame(anim, load(path) as Texture2D)


func _setup_run_animations() -> void:
	var frames := animated_sprite.sprite_frames
	var dir_map: Dictionary = {
		"east": "run_east", "north": "run_north",
		"north-east": "run_north_east", "north-west": "run_north_west",
		"south": "run_south", "south-east": "run_south_east",
		"south-west": "run_south_west", "west": "run_west",
	}
	for folder: String in dir_map.keys():
		var anim := StringName(dir_map[folder])
		if frames.has_animation(anim):
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 10.0)
		frames.set_animation_loop(anim, true)
		for i in range(8):
			var path := "res://assets/Characters/Prota/animations/running-8-frames/%s/frame_%03d.png" % [folder, i]
			frames.add_frame(anim, load(path) as Texture2D)


func _setup_axe_animation() -> void:
	var frames := animated_sprite.sprite_frames
	if frames.has_animation(&"axe_swing"):
		return
	frames.add_animation(&"axe_swing")
	frames.set_animation_speed(&"axe_swing", 12.0)
	frames.set_animation_loop(&"axe_swing", false)
	for i in range(9):
		var path := "res://assets/Characters/Prota/animations/custom-swinging an axe/east/frame_%03d.png" % i
		frames.add_frame(&"axe_swing", load(path) as Texture2D)


func _setup_footstep_audio() -> void:
	_footstep_player = AudioStreamPlayer.new()
	_footstep_player.stream = load("res://assets/sfx/footstep.wav")
	_footstep_player.volume_db = 0.0
	add_child(_footstep_player)
	_swing_axe_player = AudioStreamPlayer.new()
	_swing_axe_player.stream = load("res://assets/sfx/swingaxe.wav")
	_swing_axe_player.volume_db = 0.0
	add_child(_swing_axe_player)


func _physics_process(delta: float) -> void:
	var input_vector := _get_input_vector()
	var wants_to_sprint := _wants_to_sprint(input_vector)
	_update_movement_state(delta, input_vector, wants_to_sprint)
	_apply_movement(delta, input_vector)

	if input_vector != Vector2.ZERO:
		facing_direction = input_vector

	move_and_slide()
	_update_camera_anchor(delta)
	_update_animation_state()
	_update_footstep(delta, input_vector)
	_update_flashlight_visual()
	if _attack_cooldown_frames > 0:
		_attack_cooldown_frames -= 1


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
	if _movement_locked or _is_swinging:
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


func set_anxiety_intensity(intensity: float) -> void:
	_anxiety_intensity = clamp(intensity, 0.0, 1.0)


func _update_camera_anchor(delta: float = 0.0) -> void:
	# Só força global_position nas transições de sala (delta == 0.0)
	if delta == 0.0:
		camera.global_position = global_position.round()

	if _anxiety_intensity > 0.0:
		_shake_time += delta * SHAKE_FREQUENCY
		var shake_x := sin(_shake_time * 1.0) * SHAKE_MAX_OFFSET * _anxiety_intensity
		var shake_y := sin(_shake_time * 1.37) * SHAKE_MAX_OFFSET * _anxiety_intensity
		camera.offset = Vector2(shake_x, shake_y)
		var base_zoom := lerpf(2.0, 2.45, _anxiety_intensity)
		var zoom_pulse := sin(_shake_time * (ZOOM_PULSE_FREQUENCY / SHAKE_FREQUENCY) * TAU) * ZOOM_PULSE_MAGNITUDE * _anxiety_intensity
		camera.zoom = Vector2(base_zoom + zoom_pulse, base_zoom + zoom_pulse)
	else:
		_shake_time = 0.0
		camera.offset = Vector2.ZERO
		camera.zoom = Vector2(2.0, 2.0)

func set_held_item(item_id: String, short_label: String, color: Color) -> void:
	held_item_label.text = short_label
	held_item_visual.visible = false
	held_item_label.visible = false


func get_stamina_ratio() -> float:
	return _stamina / MAX_STAMINA


func drain_stamina(amount: float) -> bool:
	if _stamina < amount:
		return false
	_stamina -= amount
	_regen_cooldown = EXHAUSTED_REGEN_DELAY
	if _stamina <= 0.0:
		_enter_exhausted_state()
	return true


func get_facing_direction() -> Vector2:
	return facing_direction.normalized() if facing_direction != Vector2.ZERO else Vector2.DOWN


func is_stamina_on_cooldown() -> bool:
	return movement_state == MovementState.EXHAUSTED or _regen_cooldown > 0.0


func is_sprinting() -> bool:
	return movement_state == MovementState.SPRINTING


func is_exhausted() -> bool:
	return movement_state == MovementState.EXHAUSTED


func _on_animation_finished() -> void:
	if _is_swinging:
		_is_swinging = false


func _on_frame_changed() -> void:
	if _is_swinging and animated_sprite.frame == 5:
		_swing_axe_player.play()
		axe_impact.emit()


func _update_animation_state() -> void:
	if _is_swinging:
		return

	var speed_scale := 0.5 if movement_state == MovementState.EXHAUSTED else 1.0
	animated_sprite.speed_scale = speed_scale
	_animation_speed_multiplier = speed_scale

	if velocity.length() > 1.0:
		_update_sprite_direction()
	else:
		_update_idle_direction()
	animated_sprite.play()


func _update_sprite_direction() -> void:
	var angle_deg := rad_to_deg(facing_direction.angle())
	var run := movement_state == MovementState.SPRINTING
	animated_sprite.flip_h = false
	# Godot angle(): DIREITA=0°, BAIXO=90°, ESQUERDA=±180°, CIMA=-90°
	if angle_deg >= -22.5 and angle_deg < 22.5:
		animated_sprite.animation = &"run_east" if run else &"walk_east"
	elif angle_deg >= 22.5 and angle_deg < 67.5:
		animated_sprite.animation = &"run_south_east" if run else &"walk_south_east"
	elif angle_deg >= 67.5 and angle_deg < 112.5:
		animated_sprite.animation = &"run_south" if run else &"walk_south"
	elif angle_deg >= 112.5 and angle_deg < 157.5:
		animated_sprite.animation = &"run_south_west" if run else &"walk_south_west"
	elif angle_deg >= 157.5 or angle_deg < -157.5:
		animated_sprite.animation = &"run_west" if run else &"walk_west"
	elif angle_deg >= -157.5 and angle_deg < -112.5:
		animated_sprite.animation = &"run_north_west" if run else &"walk_north_west"
	elif angle_deg >= -112.5 and angle_deg < -67.5:
		animated_sprite.animation = &"run_north" if run else &"walk_north"
	else:  # [-67.5, -22.5)
		animated_sprite.animation = &"run_north_east" if run else &"walk_north_east"


func _update_idle_direction() -> void:
	var angle_deg := rad_to_deg(facing_direction.angle())
	animated_sprite.flip_h = false
	# Idle só tem 4 direções cardinais; diagonais mapeiam para o cardinal mais próximo
	# W não existe → usa east com flip
	if angle_deg >= -67.5 and angle_deg < 67.5:
		animated_sprite.animation = &"idle_east"
	elif angle_deg >= 67.5 and angle_deg < 157.5:
		animated_sprite.animation = &"idle_south"
	elif angle_deg >= 157.5 or angle_deg < -157.5:
		animated_sprite.animation = &"idle_east"
		animated_sprite.flip_h = true
	else:  # [-157.5, -67.5) → norte e diagonais norte
		animated_sprite.animation = &"idle_north"


func _update_footstep(delta: float, input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO or velocity.length_squared() < 1.0:
		_footstep_timer = 0.0
		return

	var interval := 0.25 if movement_state == MovementState.SPRINTING else 0.375
	_footstep_timer += delta
	if _footstep_timer >= interval:
		_footstep_timer = fmod(_footstep_timer, interval)
		_footstep_player.play()


func play_axe_swing(direction: Vector2) -> void:
	_is_swinging = true
	_attack_cooldown_frames = 8
	animated_sprite.flip_h = direction.x < 0.0
	animated_sprite.play(&"axe_swing")


func is_attack_on_cooldown() -> bool:
	return _attack_cooldown_frames > 0 or _is_swinging


func set_survival_modifiers(speed_multiplier: float, stamina_regen_multiplier: float) -> void:
	_external_speed_multiplier = clamp(speed_multiplier, 0.35, 1.2)
	_external_stamina_regen_multiplier = clamp(stamina_regen_multiplier, 0.1, 2.0)


# ── Lanterna ───────────────────────────────────────────────────────────────────

func _setup_flashlight_cone() -> void:
	# PLACEHOLDER — o cone usa Polygon2D + shader; substituir sprite do item quando asset disponível
	var shd := Shader.new()
	shd.code = _FLASHLIGHT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shd

	_flashlight_cone = Polygon2D.new()
	_flashlight_cone.name = "FlashlightCone"
	# Cone de 180px, estreito na base e mais largo no meio — mesma forma do refletor, em escala menor
	_flashlight_cone.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(-80, 320), Vector2(80, 320),
	])
	_flashlight_cone.color = Color(0.98, 0.95, 0.80, 0.50)
	_flashlight_cone.material = mat
	_flashlight_cone.z_index = -1
	_flashlight_cone.visible = false
	add_child(_flashlight_cone)


func _update_flashlight_visual() -> void:
	if _flashlight_cone == null:
		return
	_flashlight_cone.visible = _flashlight_on
	if _flashlight_on:
		_flashlight_cone.rotation = facing_direction.angle() - PI / 2.0


func set_flashlight_on(on: bool) -> void:
	_flashlight_on = on


func is_flashlight_on() -> bool:
	return _flashlight_on
