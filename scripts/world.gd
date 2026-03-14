extends Node2D

const FarmEnemyScene = preload("res://scenes/farm_enemy.tscn")

const INTERACT_DISTANCE := 56.0
const DAY_DURATION := 180.0
const NIGHT_DURATION := 135.0
const SELL_PRICE := 12
const INITIAL_SEED_AMOUNT := 10
const VENDOR_SEED_BUNDLE_AMOUNT := 10
const VENDOR_SEED_BUNDLE_COST := int(VENDOR_SEED_BUNDLE_AMOUNT * SELL_PRICE * 0.5)
const GROWTH_STAGE_DURATION := 40.0
const HOTBAR_SIZE := 5
const BUCKET_MAX_CHARGES := 5
const WELL_THIRST_RESTORE := 34.0
const CROP_HUNGER_RESTORE := 24.0
const TREE_RESPAWN_DURATION := 55.0
const WOOD_PER_CHOP := 2
const GENERATOR_WOOD_PER_NIGHT := 30
const GENERATOR_FUEL_PER_WOOD := NIGHT_DURATION / float(GENERATOR_WOOD_PER_NIGHT)
const GENERATOR_FUEL_DRAIN_PER_SECOND := 1.0
const NIGHT_WARNING_DELAY := 5.0
const HOSTILE_COOLDOWN_DURATION := 5.0
const PLAYER_EXPULSION_OFFSET := Vector2(0, 72)
const PLAYER_COLLAPSE_COIN_PENALTY := 10
const PLAYER_VISION_RANGE := 280.0
const PLAYER_VISION_DOT_THRESHOLD := 0.45
const REFLECTOR_RADIUS := 212.0

const HUNGER_MAX := 100.0
const THIRST_MAX := 100.0
const HEALTH_MAX := 100.0
const HUNGER_DRAIN_PER_SECOND := 0.22
const THIRST_DRAIN_PER_SECOND := 0.34
const HEALTH_DECAY_PER_SECOND := 5.5
const HEALTH_RECOVERY_PER_SECOND := 1.2

const ITEM_BUCKET := "bucket"
const ITEM_AXE := "axe"
const ITEM_SEEDS := "seeds"
const ITEM_CROP := "crop"
const ITEM_WOOD := "wood"
const ITEM_BREAD := "pao"

const STOVE_COOK_DURATION := 30.0
const STOVE_WHEAT_COST := 2
const BREAD_HUNGER_RESTORE := 44.0
const BREAD_HEALTH_RESTORE := 8.0
const CROP_PROGRESS_BAR_WIDTH := 28.0
const CROP_PROGRESS_BAR_HEIGHT := 3.0
const CROP_PROGRESS_BAR_Y := -22.0

const PLOT_EMPTY := 0
const PLOT_STAGE1_DRY := 1
const PLOT_STAGE1_GROWING := 2
const PLOT_STAGE2_DRY := 3
const PLOT_STAGE2_GROWING := 4
const PLOT_MATURE := 5

enum HostileEventState {
	IDLE,
	WARNING,
	ACTIVE,
	COOLDOWN,
}

enum TutorialPhase {
	AWAIT_APPROACH,
	IN_DIALOGUE,
	IDLE,
	NIGHT_WARN,
	NIGHT_RUN_GENERATOR,
	DYING,
	DEAD,
}

const TUTORIAL_NPC_SPEED := 70.0
const TUTORIAL_NPC_NAME := "Caim"
const TUTORIAL_LINES := [
	"Sobrevivente. Ainda bem que voce chegou.",
	"Esta terra devora os despreparados. Mas pode ser domada.",
	"Veja os canteiros: plante sementes com [F], regue com o balde, colha quando amarelo.",
	"Venda a colheita na caixa vermelha. O vendedor vende sementes por moedas.",
	"O fogao dentro de casa transforma 2 trigos em pao - mais nutritivo que comer cru.",
	"A noite traz o Goatman. Corte lenha e deposite no gerador. Trinta madeiras duram a noite.",
	"Os refletores o afastam. Sem luz, voce e presa. Cuide da fome e da sede.",
	"E tudo que sei. Sobreviva.",
]

@onready var world_visuals: Node2D = $WorldVisuals
@onready var outside_door: Area2D = $OutsideDoor
@onready var inside_door: Area2D = $InsideDoor
@onready var player: PlayerController = $Player
@onready var outside_spawn: Marker2D = $Markers/OutsideSpawn
@onready var inside_spawn: Marker2D = $Markers/InsideSpawn
@onready var enemy_spawn: Marker2D = $Markers/EnemySpawn
@onready var enemy_route_markers: Node2D = $Markers/EnemyRoute
@onready var well: Area2D = $Well
@onready var plots_container: Node2D = $CropField/Plots
@onready var seed_bag: Area2D = $SeedBag
@onready var seed_bag_visual: Polygon2D = $SeedBag/Visual
@onready var sell_box: Area2D = $SellBox
@onready var sell_box_visual: Polygon2D = $SellBox/Visual
@onready var well_visual: Polygon2D = $Well/Visual
@onready var vendor: Area2D = $Vendor
@onready var vendor_visual: Polygon2D = $Vendor/Visual
@onready var trees_container: Node2D = $Trees
@onready var transition_layer: CanvasLayer = $TransitionLayer
@onready var night_rect: ColorRect = $TransitionLayer/NightRect
@onready var prompt_panel: Panel = $TransitionLayer/PromptPanel
@onready var prompt_label: Label = $TransitionLayer/PromptPanel/PromptLabel
@onready var stamina_fill: ColorRect = $TransitionLayer/StaminaPanel/StaminaFill
@onready var stamina_backdrop: ColorRect = $TransitionLayer/StaminaPanel/StaminaBackdrop
@onready var stamina_segments: Node2D = $TransitionLayer/StaminaPanel/StaminaSegments
@onready var stamina_status: Label = $TransitionLayer/StaminaPanel/StaminaStatus
@onready var day_label: Label = $TransitionLayer/DayLabel
@onready var phase_label: Label = $TransitionLayer/PhaseLabel
@onready var inventory_label: Label = $TransitionLayer/InventoryLabel
@onready var coins_label: Label = $TransitionLayer/CoinsLabel
@onready var alert_label: Label = $TransitionLayer/AlertLabel
@onready var hotbar_slots := [
	$TransitionLayer/HotbarPanel/Slot1,
	$TransitionLayer/HotbarPanel/Slot2,
	$TransitionLayer/HotbarPanel/Slot3,
	$TransitionLayer/HotbarPanel/Slot4,
	$TransitionLayer/HotbarPanel/Slot5,
]
@onready var fade_rect: ColorRect = $TransitionLayer/FadeRect
@onready var hostile_audio: AudioStreamPlayer = $HostileAudio

var _teleport_cooldown := 0.0
var _is_transitioning := false
var _plots: Array[Dictionary] = []
var _active_interaction: Dictionary = {}
var _coins := 12
var _day_number := 1
var _is_night := false
var _phase_elapsed := 0.0
var _cycle_cheat_held := false
var _hotbar: Array[Dictionary] = []
var _selected_hotbar_index := 0
var _highlight_lines: Dictionary = {}
var _hostile_state := HostileEventState.IDLE
var _hostile_state_timer := 0.0
var _hostile_trigger_timer := NIGHT_WARNING_DELAY
var _hostile_route: Array[Vector2] = []
var _hostile_alert_text := ""
var _active_enemy: FarmEnemy = null
var _free_seed_claim_available := true
var _hunger := HUNGER_MAX
var _thirst := THIRST_MAX
var _health := HEALTH_MAX
var _status_labels: Dictionary = {}
var _generator_area: Area2D = null
var _generator_visual: Polygon2D = null
var _generator_glow: Polygon2D = null
var _reflector_positions: Array[Vector2] = []
var _reflector_visuals: Array[Polygon2D] = []
var _generator_fuel := 0.0
var _generator_active := false
var _wood_sources: Array[Dictionary] = []
var _stove_area: Area2D = null
var _stove_visual: Polygon2D = null
var _stove_fire: Polygon2D = null
var _stove_progress_bar_bg: Polygon2D = null
var _stove_progress_bar_fill: Polygon2D = null
var _stove_cooking := false
var _stove_timer := 0.0
var _stove_bread_ready := false
var _tutorial_phase := TutorialPhase.AWAIT_APPROACH
var _tutorial_npc_body: Node2D = null
var _tutorial_npc_visual_head: Polygon2D = null
var _tutorial_npc_visual_body: Polygon2D = null
var _tutorial_npc_area: Area2D = null
var _tutorial_dialogue_index := 0
var _tutorial_night_timer := 0.0
var _tutorial_night_step := 0
var _first_night_done := false
var _tutorial_dialogue_panel: Panel = null
var _tutorial_dialogue_name_label: Label = null
var _tutorial_dialogue_text_label: Label = null


func _ready() -> void:
	randomize()
	_ensure_input_actions()
	_configure_overlay()
	_setup_hotbar()
	_cache_farm_plots()
	_cache_enemy_route()
	_create_runtime_farm_nodes()
	_cache_tree_sources()
	_setup_interaction_highlights()
	_build_stamina_segments()
	_build_survival_ui()
	_build_tutorial_ui()
	player.global_position = outside_spawn.global_position
	_refresh_generator_visuals()
	_refresh_ui()

	outside_door.body_entered.connect(_on_outside_door_body_entered)
	inside_door.body_entered.connect(_on_inside_door_body_entered)


func _process(delta: float) -> void:
	_teleport_cooldown = max(_teleport_cooldown - delta, 0.0)
	_update_cycle_cheat()
	_update_day_cycle(delta)
	_update_plot_growth(delta)
	_update_tutorial_npc(delta)
	_update_stove(delta)
	_update_wood_sources(delta)
	_update_generator(delta)
	_update_survival_stats(delta)
	_update_hostile_event(delta)
	_update_active_interaction()
	_apply_survival_modifiers()
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_interact()
	elif event.is_action_pressed("use_item"):
		_try_use_selected_item()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_selected_hotbar_index = wrapi(_selected_hotbar_index - 1, 0, HOTBAR_SIZE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_selected_hotbar_index = wrapi(_selected_hotbar_index + 1, 0, HOTBAR_SIZE)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_O:
			_trigger_hostile_warning_debug()
			return
		_try_hotbar_selection(event.physical_keycode)


func _ensure_input_actions() -> void:
	if not InputMap.has_action("use_item"):
		InputMap.add_action("use_item")

	if not _action_has_key("use_item", KEY_Q):
		var event := InputEventKey.new()
		event.physical_keycode = KEY_Q
		InputMap.action_add_event("use_item", event)


func _action_has_key(action_name: String, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _configure_overlay() -> void:
	night_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	night_rect.color = Color(0.054902, 0.0862745, 0.180392, 0.0)
	fade_rect.color = Color(0, 0, 0, 0)
	stamina_fill.visible = false
	stamina_backdrop.color = Color(0.12549, 0.219608, 0.305882, 1)


func _build_stamina_segments() -> void:
	for child in stamina_segments.get_children():
		child.queue_free()

	var segment_count := 10
	var gap := 2.0
	var total_width := 150.0
	var segment_width := (total_width - gap * float(segment_count - 1)) / float(segment_count)

	for index in range(segment_count):
		var segment := ColorRect.new()
		segment.name = "Segment%d" % index
		segment.position = Vector2(index * (segment_width + gap), 0)
		segment.size = Vector2(segment_width, 16)
		segment.color = Color(0.537255, 0.886275, 0.988235, 1)
		stamina_segments.add_child(segment)


func _build_survival_ui() -> void:
	_create_status_label("survival", Vector2(24, 176), 18)
	_create_status_label("generator", Vector2(24, 206), 17)


func _create_status_label(label_id: String, label_position: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.position = label_position
	label.size = Vector2(420, 26)
	label.add_theme_font_size_override("font_size", font_size)
	transition_layer.add_child(label)
	_status_labels[label_id] = label


func _cache_enemy_route() -> void:
	_hostile_route.clear()

	for child in enemy_route_markers.get_children():
		if child is Marker2D:
			_hostile_route.append((child as Marker2D).global_position)


func _cache_farm_plots() -> void:
	_plots.clear()

	for plot_area in plots_container.get_children():
		if not (plot_area is Area2D):
			continue

		var soil := plot_area.get_node_or_null("Soil") as Polygon2D
		var crop := plot_area.get_node_or_null("Crop") as Polygon2D
		if soil == null or crop == null:
			continue

		var bar_bg := Polygon2D.new()
		bar_bg.color = Color(0.12, 0.12, 0.12, 0.88)
		bar_bg.polygon = PackedVector2Array([
			Vector2(-14, CROP_PROGRESS_BAR_Y),
			Vector2(14, CROP_PROGRESS_BAR_Y),
			Vector2(14, CROP_PROGRESS_BAR_Y + CROP_PROGRESS_BAR_HEIGHT),
			Vector2(-14, CROP_PROGRESS_BAR_Y + CROP_PROGRESS_BAR_HEIGHT),
		])
		bar_bg.z_index = 10
		bar_bg.visible = false
		plot_area.add_child(bar_bg)

		var bar_fill := Polygon2D.new()
		bar_fill.color = Color(0.42, 0.82, 0.38, 1)
		bar_fill.polygon = PackedVector2Array([
			Vector2(-14, CROP_PROGRESS_BAR_Y),
			Vector2(-14, CROP_PROGRESS_BAR_Y),
			Vector2(-14, CROP_PROGRESS_BAR_Y + CROP_PROGRESS_BAR_HEIGHT),
			Vector2(-14, CROP_PROGRESS_BAR_Y + CROP_PROGRESS_BAR_HEIGHT),
		])
		bar_fill.z_index = 11
		bar_fill.visible = false
		plot_area.add_child(bar_fill)

		var plot_data: Dictionary = {
			"area": plot_area,
			"soil": soil,
			"crop": crop,
			"state": PLOT_EMPTY,
			"growth_timer": 0.0,
			"bar_bg": bar_bg,
			"bar_fill": bar_fill,
		}
		_plots.append(plot_data)
		_update_plot_visual(plot_data)


func _create_runtime_farm_nodes() -> void:
	_create_generator()
	_create_reflectors()
	_create_stove()
	_create_tutorial_npc()


func _create_stove() -> void:
	_stove_area = Area2D.new()
	_stove_area.name = "Stove"
	_stove_area.position = Vector2(1950, 370)
	add_child(_stove_area)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(44, 34)
	collision.shape = shape
	_stove_area.add_child(collision)

	_stove_visual = Polygon2D.new()
	_stove_visual.color = Color(0.22, 0.18, 0.14, 1)
	_stove_visual.polygon = PackedVector2Array([
		Vector2(-18, -13), Vector2(18, -13),
		Vector2(20, 11), Vector2(-20, 11),
	])
	_stove_area.add_child(_stove_visual)

	_stove_fire = Polygon2D.new()
	_stove_fire.color = Color(1.0, 0.52, 0.1, 0.0)
	_stove_fire.polygon = PackedVector2Array([
		Vector2(-7, 2), Vector2(7, 2),
		Vector2(5, -9), Vector2(0, -3), Vector2(-5, -9),
	])
	_stove_fire.z_index = 1
	_stove_area.add_child(_stove_fire)

	_stove_progress_bar_bg = Polygon2D.new()
	_stove_progress_bar_bg.color = Color(0.12, 0.12, 0.12, 0.88)
	_stove_progress_bar_bg.polygon = PackedVector2Array([
		Vector2(-18, -20), Vector2(18, -20),
		Vector2(18, -17), Vector2(-18, -17),
	])
	_stove_progress_bar_bg.z_index = 10
	_stove_progress_bar_bg.visible = false
	_stove_area.add_child(_stove_progress_bar_bg)

	_stove_progress_bar_fill = Polygon2D.new()
	_stove_progress_bar_fill.color = Color(1.0, 0.68, 0.18, 1)
	_stove_progress_bar_fill.polygon = PackedVector2Array([
		Vector2(-18, -20), Vector2(-18, -20),
		Vector2(-18, -17), Vector2(-18, -17),
	])
	_stove_progress_bar_fill.z_index = 11
	_stove_progress_bar_fill.visible = false
	_stove_area.add_child(_stove_progress_bar_fill)


func _cache_tree_sources() -> void:
	_wood_sources.clear()

	for child in trees_container.get_children():
		var tree_root := child as Node2D
		if tree_root == null:
			continue

		var interact_area := tree_root.get_node_or_null("InteractArea") as Area2D
		var visual := tree_root.get_node_or_null("Visual") as Polygon2D
		if interact_area == null or visual == null:
			continue

		_wood_sources.append({
			"node": tree_root,
			"area": interact_area,
			"visual": visual,
			"available": true,
			"respawn_timer": 0.0,
		})


func _create_generator() -> void:
	_generator_area = Area2D.new()
	_generator_area.name = "Generator"
	_generator_area.position = Vector2(520, 468)
	add_child(_generator_area)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(54, 42)
	collision.shape = shape
	_generator_area.add_child(collision)

	_generator_visual = Polygon2D.new()
	_generator_visual.color = Color(0.364706, 0.380392, 0.396078, 1)
	_generator_visual.polygon = PackedVector2Array([
		Vector2(-22, -16),
		Vector2(22, -16),
		Vector2(24, 14),
		Vector2(-24, 14),
	])
	_generator_area.add_child(_generator_visual)

	_generator_glow = Polygon2D.new()
	_generator_glow.color = Color(1.0, 0.878431, 0.431373, 0.0)
	_generator_glow.polygon = PackedVector2Array([
		Vector2(-26, -20),
		Vector2(26, -20),
		Vector2(28, 18),
		Vector2(-28, 18),
	])
	_generator_glow.z_index = -1
	_generator_area.add_child(_generator_glow)


func _create_reflectors() -> void:
	_reflector_positions = [
		Vector2(286, 610),
		Vector2(560, 610),
	]
	_reflector_visuals.clear()

	for reflector_position in _reflector_positions:
		var glow := Polygon2D.new()
		glow.position = reflector_position
		glow.color = Color(0.980392, 0.901961, 0.596078, 0.0)
		glow.polygon = PackedVector2Array([
			Vector2(-72, 16),
			Vector2(-36, -140),
			Vector2(0, -200),
			Vector2(36, -140),
			Vector2(72, 16),
		])
		glow.z_index = 1
		world_visuals.add_child(glow)
		_reflector_visuals.append(glow)


func _setup_interaction_highlights() -> void:
	_highlight_lines.clear()
	_register_polygon_highlight(seed_bag_visual)
	_register_polygon_highlight(sell_box_visual)
	_register_polygon_highlight(well_visual)
	_register_polygon_highlight(vendor_visual)
	_register_polygon_highlight(_generator_visual)
	_register_polygon_highlight(_stove_visual)
	for plot in _plots:
		_register_polygon_highlight(plot["soil"])
	for source in _wood_sources:
		_register_polygon_highlight(source["visual"])


func _register_polygon_highlight(polygon_node: Polygon2D) -> void:
	var line := Line2D.new()
	line.name = "Highlight"
	line.width = 2.5
	line.default_color = Color.WHITE
	line.closed = true
	line.visible = false
	line.z_index = polygon_node.z_index + 1
	for point in polygon_node.polygon:
		line.add_point(point)
	polygon_node.add_child(line)
	_highlight_lines[polygon_node] = line


func _update_day_cycle(delta: float) -> void:
	_phase_elapsed += delta
	var current_duration := NIGHT_DURATION if _is_night else DAY_DURATION

	if _phase_elapsed >= current_duration:
		_advance_day_phase()

	var target_alpha := 0.5 if _is_night else 0.0
	var color := night_rect.color
	color.a = move_toward(color.a, target_alpha, delta * 0.7)
	night_rect.color = color


func _update_cycle_cheat() -> void:
	var cheat_pressed := (
		Input.is_physical_key_pressed(KEY_A)
		and Input.is_physical_key_pressed(KEY_R)
		and Input.is_physical_key_pressed(KEY_Q)
	)

	if cheat_pressed and not _cycle_cheat_held:
		_phase_elapsed = NIGHT_DURATION if _is_night else DAY_DURATION
		_cycle_cheat_held = true
	elif not cheat_pressed:
		_cycle_cheat_held = false


func _advance_day_phase() -> void:
	_phase_elapsed = 0.0
	if _is_night:
		_day_number += 1
		_is_night = false
		_stop_hostile_event(false)
		_generator_active = false
		_hostile_alert_text = ""
	else:
		_is_night = true
		_schedule_next_hostile_event()
		if _day_number == 1 and not _first_night_done and _tutorial_phase != TutorialPhase.DEAD:
			_begin_tutorial_night_sequence()


func _schedule_next_hostile_event() -> void:
	_hostile_state = HostileEventState.IDLE
	_hostile_state_timer = 0.0
	_hostile_trigger_timer = NIGHT_WARNING_DELAY
	_hostile_alert_text = ""


func _trigger_hostile_warning_debug() -> void:
	if not _is_night or _is_transitioning:
		return

	if _hostile_state != HostileEventState.IDLE or _hostile_route.is_empty():
		return

	_begin_hostile_warning()


func _update_plot_growth(delta: float) -> void:
	for plot in _plots:
		var state := int(plot["state"])
		if state != PLOT_STAGE1_GROWING and state != PLOT_STAGE2_GROWING:
			_update_plot_progress_bar(plot, 0.0, false)
			continue

		plot["growth_timer"] = float(plot["growth_timer"]) + delta
		var ratio := minf(float(plot["growth_timer"]) / GROWTH_STAGE_DURATION, 1.0)
		_update_plot_progress_bar(plot, ratio, true)

		if float(plot["growth_timer"]) < GROWTH_STAGE_DURATION:
			continue

		plot["growth_timer"] = 0.0
		if state == PLOT_STAGE1_GROWING:
			plot["state"] = PLOT_STAGE2_DRY
		else:
			plot["state"] = PLOT_MATURE

		_update_plot_visual(plot)


func _update_plot_progress_bar(plot: Dictionary, ratio: float, visible: bool) -> void:
	var bar_bg := plot["bar_bg"] as Polygon2D
	var bar_fill := plot["bar_fill"] as Polygon2D
	bar_bg.visible = visible
	bar_fill.visible = visible and ratio > 0.001
	if not visible:
		return
	var half := CROP_PROGRESS_BAR_WIDTH * 0.5
	var fill_x := -half + ratio * CROP_PROGRESS_BAR_WIDTH
	bar_fill.polygon = PackedVector2Array([
		Vector2(-half, CROP_PROGRESS_BAR_Y),
		Vector2(fill_x, CROP_PROGRESS_BAR_Y),
		Vector2(fill_x, CROP_PROGRESS_BAR_Y + CROP_PROGRESS_BAR_HEIGHT),
		Vector2(-half, CROP_PROGRESS_BAR_Y + CROP_PROGRESS_BAR_HEIGHT),
	])
	bar_fill.color = Color(0.42 + ratio * 0.46, 0.82 - ratio * 0.16, 0.38 - ratio * 0.25, 1)


func _update_wood_sources(delta: float) -> void:
	for source in _wood_sources:
		if bool(source["available"]):
			continue

		source["respawn_timer"] = float(source["respawn_timer"]) - delta
		if float(source["respawn_timer"]) > 0.0:
			continue

		source["available"] = true
		var visual := source["visual"] as Polygon2D
		visual.color = Color(0.266667, 0.482353, 0.247059, 1)


func _update_generator(delta: float) -> void:
	if not _generator_active:
		_refresh_generator_visuals()
		return

	if _generator_fuel > 0.0:
		_generator_fuel = max(_generator_fuel - GENERATOR_FUEL_DRAIN_PER_SECOND * delta, 0.0)

	if _generator_fuel <= 0.0:
		_generator_fuel = 0.0
		_generator_active = false
		_hostile_alert_text = "Os refletores apagaram."

	_refresh_generator_visuals()


func _update_stove(delta: float) -> void:
	if not _stove_cooking:
		return
	_stove_timer = minf(_stove_timer + delta, STOVE_COOK_DURATION)
	_refresh_stove_visuals(_stove_timer / STOVE_COOK_DURATION)
	if _stove_timer >= STOVE_COOK_DURATION:
		_stove_cooking = false
		_stove_timer = 0.0
		_stove_bread_ready = true
		_refresh_stove_visuals(0.0)
		_hostile_alert_text = "O pao ficou pronto. Va ao fogao busca-lo."


func _refresh_stove_visuals(ratio: float) -> void:
	if _stove_visual == null:
		return
	if _stove_bread_ready:
		_stove_visual.color = Color(0.72, 0.54, 0.22, 1)
		_stove_fire.color.a = 0.0
		_stove_progress_bar_bg.visible = false
		_stove_progress_bar_fill.visible = false
		return
	_stove_visual.color = Color(0.22, 0.18, 0.14, 1)
	_stove_fire.color.a = 0.9 if _stove_cooking else 0.0
	_stove_progress_bar_bg.visible = _stove_cooking
	_stove_progress_bar_fill.visible = _stove_cooking and ratio > 0.001
	if not _stove_cooking:
		return
	var fill_x := -18.0 + ratio * 36.0
	_stove_progress_bar_fill.polygon = PackedVector2Array([
		Vector2(-18, -20), Vector2(fill_x, -20),
		Vector2(fill_x, -17), Vector2(-18, -17),
	])


func _update_survival_stats(delta: float) -> void:
	var hunger_rate := HUNGER_DRAIN_PER_SECOND
	var thirst_rate := THIRST_DRAIN_PER_SECOND
	if player.is_sprinting():
		hunger_rate *= 1.25
		thirst_rate *= 1.45
	if _is_night:
		thirst_rate *= 1.1

	_hunger = max(_hunger - hunger_rate * delta, 0.0)
	_thirst = max(_thirst - thirst_rate * delta, 0.0)

	if _hunger <= 0.0 or _thirst <= 0.0:
		_health = max(_health - HEALTH_DECAY_PER_SECOND * delta, 0.0)
	elif _hunger >= 60.0 and _thirst >= 60.0 and not player.is_sprinting():
		_health = min(_health + HEALTH_RECOVERY_PER_SECOND * delta, HEALTH_MAX)

	if _health <= 0.0 and not _is_transitioning:
		_start_player_collapse("Voce caiu exausto na fazenda.")


func _apply_survival_modifiers() -> void:
	var speed_multiplier := 1.0
	var stamina_regen_multiplier := 1.0

	if _hunger < 40.0:
		speed_multiplier -= 0.08
		stamina_regen_multiplier -= 0.18
	if _thirst < 40.0:
		speed_multiplier -= 0.12
		stamina_regen_multiplier -= 0.28
	if _health < 35.0:
		speed_multiplier -= 0.14
		stamina_regen_multiplier -= 0.1

	player.set_survival_modifiers(speed_multiplier, stamina_regen_multiplier)


func _update_hostile_event(delta: float) -> void:
	if not _is_night:
		return

	match _hostile_state:
		HostileEventState.IDLE:
			if _is_farm_defended():
				_hostile_alert_text = "Refletores ativos. A fazenda respira."
				return

			_hostile_trigger_timer = max(_hostile_trigger_timer - delta, 0.0)
			if _hostile_trigger_timer <= 0.0 and not _is_transitioning and not _hostile_route.is_empty():
				_begin_hostile_warning()
		HostileEventState.WARNING:
			if _is_farm_defended():
				_hostile_state = HostileEventState.COOLDOWN
				_hostile_state_timer = 4.0
				_hostile_alert_text = "A criatura ronda, mas nao atravessa a luz."
				return

			_hostile_state_timer = max(_hostile_state_timer - delta, 0.0)
			if _hostile_state_timer <= 0.0 and not _is_transitioning:
				_spawn_hostile_enemy()
		HostileEventState.ACTIVE:
			if _active_enemy == null and not _is_transitioning:
				_hostile_state = HostileEventState.COOLDOWN
				_hostile_state_timer = HOSTILE_COOLDOWN_DURATION
		HostileEventState.COOLDOWN:
			_hostile_state_timer = max(_hostile_state_timer - delta, 0.0)
			if _hostile_state_timer <= 0.0:
				_hostile_state = HostileEventState.IDLE
				_hostile_trigger_timer = 3.5 if _is_farm_defended() else NIGHT_WARNING_DELAY
				if _is_farm_defended():
					_hostile_alert_text = "A luz ainda segura a noite."
				else:
					_hostile_alert_text = ""


func _begin_hostile_warning() -> void:
	_hostile_state = HostileEventState.WARNING
	_hostile_state_timer = NIGHT_WARNING_DELAY
	_hostile_alert_text = "Um berrar ecoa alem da cerca."
	if hostile_audio.stream != null:
		hostile_audio.play()


func _spawn_hostile_enemy() -> void:
	hostile_audio.stop()
	_clear_active_enemy()

	if _hostile_route.is_empty():
		_hostile_state = HostileEventState.IDLE
		return

	_hostile_state = HostileEventState.ACTIVE
	_hostile_alert_text = "Goatman avancou pela escuridao."
	_active_enemy = FarmEnemyScene.instantiate() as FarmEnemy
	add_child(_active_enemy)
	_active_enemy.start(
		enemy_spawn.global_position,
		_hostile_route,
		player,
		Callable(self, "_is_enemy_in_player_vision"),
		Callable(self, "_is_position_in_light")
	)
	_active_enemy.route_finished.connect(_on_enemy_route_finished)
	_active_enemy.player_caught.connect(_on_enemy_player_caught)
	_active_enemy.repelled.connect(_on_enemy_repelled)


func _on_enemy_route_finished() -> void:
	_stop_hostile_event(true)
	_hostile_alert_text = "Os passos cessam por um instante."


func _on_enemy_repelled() -> void:
	_stop_hostile_event(true)
	_hostile_alert_text = "A luz empurrou o Goatman de volta."


func _on_enemy_player_caught(body: Node) -> void:
	if body != player or _is_transitioning:
		return

	_stop_hostile_event(true)
	_start_player_expulsion()


func _start_player_expulsion() -> void:
	_is_transitioning = true
	_teleport_cooldown = 0.45
	player.set_movement_locked(true)
	player.snap_camera_for_room_transition()
	_update_prompt("")
	_active_interaction = {}
	_health = max(_health - 22.0, 18.0)
	_hunger = max(_hunger - 8.0, 0.0)
	_thirst = max(_thirst - 12.0, 0.0)

	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "color:a", 1.0, 0.16)
	fade_in.finished.connect(
		func() -> void:
			player.global_position = outside_spawn.global_position + PLAYER_EXPULSION_OFFSET
			player.camera.force_update_scroll()

			var fade_out := create_tween()
			fade_out.tween_interval(0.12)
			fade_out.tween_property(fade_rect, "color:a", 0.0, 0.2)
			fade_out.finished.connect(
				func() -> void:
					player.restore_camera_after_room_transition()
					player.set_movement_locked(false)
					_is_transitioning = false
			)
	)


func _start_player_collapse(reason: String) -> void:
	_is_transitioning = true
	_teleport_cooldown = 0.45
	player.set_movement_locked(true)
	player.snap_camera_for_room_transition()
	_update_prompt("")
	_active_interaction = {}
	_coins = max(_coins - PLAYER_COLLAPSE_COIN_PENALTY, 0)
	_stop_hostile_event(true)
	_hostile_alert_text = reason

	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "color:a", 1.0, 0.22)
	fade_in.finished.connect(
		func() -> void:
			_health = 65.0
			_hunger = 55.0
			_thirst = 55.0
			player.global_position = outside_spawn.global_position
			player.camera.force_update_scroll()

			var fade_out := create_tween()
			fade_out.tween_interval(0.18)
			fade_out.tween_property(fade_rect, "color:a", 0.0, 0.24)
			fade_out.finished.connect(
				func() -> void:
					player.restore_camera_after_room_transition()
					player.set_movement_locked(false)
					_is_transitioning = false
			)
	)


func _stop_hostile_event(start_cooldown: bool) -> void:
	hostile_audio.stop()
	_clear_active_enemy()
	_hostile_trigger_timer = 0.0

	if start_cooldown and _is_night:
		_hostile_state = HostileEventState.COOLDOWN
		_hostile_state_timer = HOSTILE_COOLDOWN_DURATION
	else:
		_hostile_state = HostileEventState.IDLE
		_hostile_state_timer = 0.0


func _clear_active_enemy() -> void:
	if is_instance_valid(_active_enemy):
		_active_enemy.queue_free()
	_active_enemy = null


func _is_enemy_in_player_vision(enemy_position: Vector2) -> bool:
	var offset := enemy_position - player.global_position
	var distance := offset.length()
	if distance <= 0.001 or distance > PLAYER_VISION_RANGE:
		return false

	if player.global_position.distance_to(inside_spawn.global_position) < 256.0:
		return false

	var facing := player.get_facing_direction()
	var direction_to_enemy := offset / distance
	return facing.dot(direction_to_enemy) >= PLAYER_VISION_DOT_THRESHOLD


func _is_position_in_light(world_position: Vector2) -> bool:
	if not _generator_active or _generator_fuel <= 0.0:
		return false

	for reflector_position in _reflector_positions:
		if world_position.distance_to(reflector_position) <= REFLECTOR_RADIUS:
			return true

	return false


func _is_farm_defended() -> bool:
	return _generator_active and _generator_fuel > 0.0


func _update_active_interaction() -> void:
	if _is_transitioning:
		_active_interaction = {}
		_update_prompt("")
		return

	if _tutorial_phase == TutorialPhase.IN_DIALOGUE:
		_active_interaction = {"type": "tutorial_npc", "distance": 0.0, "plot_index": -1}
		_update_prompt("F para continuar")
		_update_interaction_highlights()
		return

	var best_interaction: Dictionary = {}
	var best_distance := INF

	if _tutorial_npc_area != null and _tutorial_phase == TutorialPhase.IDLE:
		var npc_interaction := _consider_interaction(best_interaction, best_distance, "tutorial_npc", _tutorial_npc_area.global_position)
		if not npc_interaction.is_empty():
			best_interaction = npc_interaction
			best_distance = best_interaction["distance"]

	best_interaction = _consider_interaction(best_interaction, best_distance, "seed_bag", seed_bag.global_position)
	if not best_interaction.is_empty():
		best_distance = best_interaction["distance"]

	var well_interaction := _consider_interaction(best_interaction, best_distance, "well", well.global_position)
	if not well_interaction.is_empty():
		best_interaction = well_interaction
		best_distance = best_interaction["distance"]

	var sell_interaction := _consider_interaction(best_interaction, best_distance, "sell_box", sell_box.global_position)
	if not sell_interaction.is_empty():
		best_interaction = sell_interaction
		best_distance = best_interaction["distance"]

	var vendor_interaction := _consider_interaction(best_interaction, best_distance, "vendor", vendor.global_position)
	if not vendor_interaction.is_empty():
		best_interaction = vendor_interaction
		best_distance = best_interaction["distance"]

	var generator_interaction := _consider_interaction(best_interaction, best_distance, "generator", _generator_area.global_position)
	if not generator_interaction.is_empty():
		best_interaction = generator_interaction
		best_distance = best_interaction["distance"]

	var stove_interaction := _consider_interaction(best_interaction, best_distance, "stove", _stove_area.global_position)
	if not stove_interaction.is_empty():
		best_interaction = stove_interaction
		best_distance = best_interaction["distance"]

	for wood_index in range(_wood_sources.size()):
		var wood_area := _wood_sources[wood_index]["area"] as Area2D
		var wood_interaction := _consider_interaction(best_interaction, best_distance, "wood_source", wood_area.global_position, wood_index)
		if not wood_interaction.is_empty():
			best_interaction = wood_interaction
			best_distance = best_interaction["distance"]

	for plot_index in range(_plots.size()):
		var plot_area := _plots[plot_index]["area"] as Area2D
		var plot_interaction := _consider_interaction(best_interaction, best_distance, "plot", plot_area.global_position, plot_index)
		if not plot_interaction.is_empty():
			best_interaction = plot_interaction
			best_distance = best_interaction["distance"]

	_active_interaction = best_interaction
	_update_prompt(_get_prompt_for_interaction(_active_interaction))
	_update_interaction_highlights()


func _consider_interaction(current_best: Dictionary, best_distance: float, interaction_type: String, target_position: Vector2, plot_index: int = -1) -> Dictionary:
	var prompt_text := _get_prompt_for_type(interaction_type, plot_index)
	if prompt_text.is_empty():
		return current_best

	var distance := player.global_position.distance_to(target_position)
	if distance > INTERACT_DISTANCE or distance >= best_distance:
		return current_best

	return {
		"type": interaction_type,
		"distance": distance,
		"plot_index": plot_index,
	}


func _get_prompt_for_interaction(interaction: Dictionary) -> String:
	if interaction.is_empty():
		return ""

	return _get_prompt_for_type(interaction["type"], interaction.get("plot_index", -1))


func _get_prompt_for_type(interaction_type: String, plot_index: int = -1) -> String:
	match interaction_type:
		"seed_bag":
			if _free_seed_claim_available:
				return "F para pegar %d sementes iniciais" % INITIAL_SEED_AMOUNT
			return ""
		"well":
			if _get_selected_item_id() == ITEM_BUCKET and _has_item(ITEM_BUCKET):
				var bucket_slot := _find_slot_index(ITEM_BUCKET)
				var charges: int = int(_hotbar[bucket_slot]["count"]) if bucket_slot >= 0 else 0
				if charges < BUCKET_MAX_CHARGES:
					return "F para beber e encher o balde"
			return "F para beber agua"
		"tutorial_npc":
			return "F para falar com %s" % TUTORIAL_NPC_NAME
		"sell_box":
			var crop_count := _get_item_count(ITEM_CROP)
			if crop_count > 0:
				return "F para vender %d colheitas" % crop_count
		"vendor":
			if _coins >= VENDOR_SEED_BUNDLE_COST:
				return "F para comprar %d sementes (%d moedas)" % [VENDOR_SEED_BUNDLE_AMOUNT, VENDOR_SEED_BUNDLE_COST]
			return "Vendedor: %d sementes custam %d moedas" % [VENDOR_SEED_BUNDLE_AMOUNT, VENDOR_SEED_BUNDLE_COST]
		"generator":
			var wood_count := _get_item_count(ITEM_WOOD)
			if _get_selected_item_id() == ITEM_WOOD and wood_count > 0:
				return "F para depositar %d madeiras no gerador" % wood_count
			if wood_count > 0:
				return "Equipe a lenha para abastecer o gerador"
			if _generator_fuel <= 0.0:
				return "Traga lenha para ligar os refletores"
			return "F para %s os refletores" % ("desligar" if _generator_active else "ligar")
		"stove":
			if _stove_cooking:
				return "Cozinhando pao... %ds restantes" % [int(ceilf(STOVE_COOK_DURATION - _stove_timer))]
			if _stove_bread_ready:
				return "F para pegar o pao"
			if _get_item_count(ITEM_CROP) >= STOVE_WHEAT_COST:
				return "F para assar pao (2 trigos)"
			return "Fogao: precisa de 2 trigos"
		"wood_source":
			if not bool(_wood_sources[plot_index]["available"]):
				return ""
			if _get_selected_item_id() == ITEM_AXE and _has_item(ITEM_AXE):
				return "F para cortar lenha"
			if _has_item(ITEM_AXE):
				return "Equipe o machado para cortar"
		"plot":
			var plot_state := int(_plots[plot_index]["state"])
			if plot_state == PLOT_EMPTY and _get_selected_item_id() == ITEM_SEEDS and _get_item_count(ITEM_SEEDS) > 0:
				return "F para plantar"
			if plot_state == PLOT_EMPTY and _get_item_count(ITEM_SEEDS) > 0:
				return "Equipe as sementes para plantar"
			if (plot_state == PLOT_STAGE1_DRY or plot_state == PLOT_STAGE2_DRY) and _get_selected_item_id() == ITEM_BUCKET and _get_item_count(ITEM_BUCKET) > 0:
				return "F para regar"
			if (plot_state == PLOT_STAGE1_DRY or plot_state == PLOT_STAGE2_DRY) and _get_item_count(ITEM_BUCKET) > 0:
				return "Equipe o balde para regar"
			if plot_state == PLOT_MATURE:
				return "F para colher"

	return ""


func _update_prompt(prompt_text: String) -> void:
	prompt_panel.visible = not prompt_text.is_empty()
	prompt_label.text = prompt_text


func _update_interaction_highlights() -> void:
	for key in _highlight_lines.keys():
		var line: Line2D = _highlight_lines[key]
		if is_instance_valid(line):
			line.visible = false

	if _active_interaction.is_empty():
		return

	match _active_interaction["type"]:
		"tutorial_npc":
			if is_instance_valid(_tutorial_npc_visual_body):
				_show_highlight(_tutorial_npc_visual_body)
		"seed_bag":
			_show_highlight(seed_bag_visual)
		"well":
			_show_highlight(well_visual)
		"sell_box":
			_show_highlight(sell_box_visual)
		"vendor":
			_show_highlight(vendor_visual)
		"generator":
			_show_highlight(_generator_visual)
		"stove":
			_show_highlight(_stove_visual)
		"wood_source":
			var source_index: int = _active_interaction["plot_index"]
			_show_highlight(_wood_sources[source_index]["visual"])
		"plot":
			var plot_index: int = _active_interaction["plot_index"]
			_show_highlight(_plots[plot_index]["soil"])


func _show_highlight(polygon_node: Polygon2D) -> void:
	if _highlight_lines.has(polygon_node):
		var line: Line2D = _highlight_lines[polygon_node]
		line.visible = true


func _try_interact() -> void:
	if _is_transitioning or _active_interaction.is_empty():
		return

	match _active_interaction["type"]:
		"tutorial_npc":
			_interact_with_tutorial_npc()
		"seed_bag":
			if _free_seed_claim_available:
				if _add_item(ITEM_SEEDS, "Sementes", INITIAL_SEED_AMOUNT):
					_free_seed_claim_available = false
		"well":
			_thirst = min(_thirst + WELL_THIRST_RESTORE, THIRST_MAX)
			var bucket_slot := _find_slot_index(ITEM_BUCKET)
			if bucket_slot >= 0 and _get_selected_item_id() == ITEM_BUCKET:
				_hotbar[bucket_slot]["count"] = BUCKET_MAX_CHARGES
		"sell_box":
			var sold_amount := _get_item_count(ITEM_CROP)
			_coins += sold_amount * SELL_PRICE
			_remove_item(ITEM_CROP, sold_amount)
		"vendor":
			if _coins >= VENDOR_SEED_BUNDLE_COST:
				if _add_item(ITEM_SEEDS, "Sementes", VENDOR_SEED_BUNDLE_AMOUNT):
					_coins -= VENDOR_SEED_BUNDLE_COST
		"generator":
			_interact_with_generator()
		"stove":
			_interact_with_stove()
		"wood_source":
			_harvest_wood_source(_active_interaction["plot_index"])
		"plot":
			_interact_with_plot(_active_interaction["plot_index"])

	_update_active_interaction()
	_refresh_ui()


func _interact_with_generator() -> void:
	var wood_count := _get_item_count(ITEM_WOOD)
	if _get_selected_item_id() == ITEM_WOOD and wood_count > 0:
		_remove_item(ITEM_WOOD, wood_count)
		_generator_fuel += GENERATOR_FUEL_PER_WOOD * wood_count
		_generator_active = true
		var nights := _generator_fuel / NIGHT_DURATION
		_hostile_alert_text = "%d madeiras depositadas (~%.1f noites)." % [wood_count, nights]
		_refresh_generator_visuals()
		return

	if _generator_fuel <= 0.0:
		return

	_generator_active = not _generator_active
	_hostile_alert_text = "Refletores ligados." if _generator_active else "Refletores desligados."
	_refresh_generator_visuals()


func _interact_with_stove() -> void:
	if _stove_bread_ready:
		if not _add_item(ITEM_BREAD, "Pao", 1):
			_show_inventory_full_alert()
			return
		_stove_bread_ready = false
		_refresh_stove_visuals(0.0)
		return

	if _stove_cooking:
		return
	if _get_item_count(ITEM_CROP) < STOVE_WHEAT_COST:
		return
	if not _remove_item(ITEM_CROP, STOVE_WHEAT_COST):
		return
	_stove_cooking = true
	_stove_timer = 0.0
	_refresh_stove_visuals(0.0)


func _show_inventory_full_alert() -> void:
	_hostile_alert_text = "Inventario cheio. Libere espaco antes de pegar o pao."


func _harvest_wood_source(source_index: int) -> void:
	var source := _wood_sources[source_index]
	if not bool(source["available"]):
		return
	if _get_selected_item_id() != ITEM_AXE:
		return
	if not _add_item(ITEM_WOOD, "Lenha", WOOD_PER_CHOP):
		return

	source["available"] = false
	source["respawn_timer"] = TREE_RESPAWN_DURATION
	var visual := source["visual"] as Polygon2D
	visual.color = Color(0.27451, 0.27451, 0.27451, 1)


func _interact_with_plot(plot_index: int) -> void:
	var plot := _plots[plot_index]
	var state := int(plot["state"])

	match state:
		PLOT_EMPTY:
			if _get_selected_item_id() != ITEM_SEEDS or not _remove_item(ITEM_SEEDS, 1):
				return
			plot["state"] = PLOT_STAGE1_DRY
			plot["growth_timer"] = 0.0
		PLOT_STAGE1_DRY, PLOT_STAGE2_DRY:
			if _get_selected_item_id() != ITEM_BUCKET or not _remove_item(ITEM_BUCKET, 1):
				return
			plot["state"] = PLOT_STAGE1_GROWING if state == PLOT_STAGE1_DRY else PLOT_STAGE2_GROWING
			plot["growth_timer"] = 0.0
		PLOT_MATURE:
			if not _add_item(ITEM_CROP, "Trigo", 1):
				return
			plot["state"] = PLOT_EMPTY
			plot["growth_timer"] = 0.0
		_:
			return

	_update_plot_visual(plot)


func _update_plot_visual(plot: Dictionary) -> void:
	var soil := plot["soil"] as Polygon2D
	var crop := plot["crop"] as Polygon2D

	match int(plot["state"]):
		PLOT_EMPTY:
			soil.color = Color("624630")
			crop.visible = false
		PLOT_STAGE1_DRY:
			soil.color = Color("624630")
			crop.visible = true
			crop.color = Color("4f7f2f")
			crop.scale = Vector2(0.7, 0.7)
		PLOT_STAGE1_GROWING:
			soil.color = Color("4c3f33")
			crop.visible = true
			crop.color = Color("63a53d")
			crop.scale = Vector2(0.9, 0.9)
		PLOT_STAGE2_DRY:
			soil.color = Color("624630")
			crop.visible = true
			crop.color = Color("7ab255")
			crop.scale = Vector2(1.05, 1.05)
		PLOT_STAGE2_GROWING:
			soil.color = Color("4c3f33")
			crop.visible = true
			crop.color = Color("90c96b")
			crop.scale = Vector2(1.2, 1.2)
		PLOT_MATURE:
			soil.color = Color("4c3f33")
			crop.visible = true
			crop.color = Color("d9d35f")
			crop.scale = Vector2(1.35, 1.35)


func _try_use_selected_item() -> void:
	var item_id := _get_selected_item_id()
	match item_id:
		ITEM_CROP:
			if _remove_item(ITEM_CROP, 1):
				_hunger = min(_hunger + CROP_HUNGER_RESTORE, HUNGER_MAX)
				_health = min(_health + 4.0, HEALTH_MAX)
		ITEM_BREAD:
			if _remove_item(ITEM_BREAD, 1):
				_hunger = min(_hunger + BREAD_HUNGER_RESTORE, HUNGER_MAX)
				_health = min(_health + BREAD_HEALTH_RESTORE, HEALTH_MAX)
		ITEM_BUCKET:
			if _remove_item(ITEM_BUCKET, 1):
				_thirst = min(_thirst + 18.0, THIRST_MAX)
				_health = min(_health + 2.0, HEALTH_MAX)


func _refresh_ui() -> void:
	day_label.text = "Dia %d" % _day_number
	var phase_remaining := int(ceil((NIGHT_DURATION if _is_night else DAY_DURATION) - _phase_elapsed))
	phase_label.text = "%s %ds" % [("Noite" if _is_night else "Dia"), max(phase_remaining, 0)]
	coins_label.text = "Moedas: %d" % _coins
	inventory_label.text = "Equipado: %s | Q usa item | %s" % [_get_selected_slot_label(), _get_seed_stock_text()]
	_refresh_stamina_ui()
	_refresh_hotbar_ui()
	_refresh_player_held_item()
	_refresh_hostile_ui()
	_refresh_survival_ui()
	_refresh_generator_visuals()


func _refresh_hostile_ui() -> void:
	alert_label.visible = not _hostile_alert_text.is_empty()
	alert_label.text = _hostile_alert_text


func _refresh_survival_ui() -> void:
	var survival_label := _status_labels.get("survival", null) as Label
	if survival_label != null:
		survival_label.text = "FOME %d  |  SEDE %d  |  VIDA %d" % [int(round(_hunger)), int(round(_thirst)), int(round(_health))]
		if _health < 30.0 or _thirst < 25.0:
			survival_label.modulate = Color(1.0, 0.596078, 0.596078, 1)
		elif _hunger < 40.0:
			survival_label.modulate = Color(0.984314, 0.85098, 0.564706, 1)
		else:
			survival_label.modulate = Color.WHITE

	var generator_label := _status_labels.get("generator", null) as Label
	if generator_label != null:
		if _generator_fuel > 0.0:
			var mode_text := "ATIVO" if _generator_active else "PRONTO"
			var wood_equiv := int(_generator_fuel / GENERATOR_FUEL_PER_WOOD)
			var nights_left := _generator_fuel / NIGHT_DURATION
			generator_label.text = "GERADOR %s  |  ~%d madeiras  |  ~%.1f noites" % [mode_text, wood_equiv, nights_left]
			generator_label.modulate = Color(0.992157, 0.894118, 0.588235, 1)
		else:
			generator_label.text = "GERADOR VAZIO  |  LENHA: %d" % _get_item_count(ITEM_WOOD)
			generator_label.modulate = Color(0.807843, 0.807843, 0.807843, 1)


func _refresh_generator_visuals() -> void:
	if _generator_visual == null or _generator_glow == null:
		return

	_generator_visual.color = Color(0.45098, 0.435294, 0.317647, 1) if _generator_active else Color(0.364706, 0.380392, 0.396078, 1)
	_generator_glow.color = Color(1.0, 0.878431, 0.431373, 0.28) if _generator_active else Color(1.0, 0.878431, 0.431373, 0.0)

	for glow in _reflector_visuals:
		glow.color = Color(0.980392, 0.901961, 0.596078, 0.22) if _generator_active else Color(0.980392, 0.901961, 0.596078, 0.0)


func _get_seed_stock_text() -> String:
	if _free_seed_claim_available:
		return "Bolsa inicial: %d sementes" % INITIAL_SEED_AMOUNT
	return "Vendedor: %d sementes por %d moedas" % [VENDOR_SEED_BUNDLE_AMOUNT, VENDOR_SEED_BUNDLE_COST]


func _refresh_stamina_ui() -> void:
	var ratio := player.get_stamina_ratio()
	var segment_count := 10
	var filled_segments := int(ceil(ratio * segment_count))
	var segment_color := Color(0.537255, 0.886275, 0.988235, 1)
	if player.is_exhausted():
		segment_color = Color(0.901961, 0.478431, 0.478431, 1)
		stamina_status.text = "CD"
	elif player.is_sprinting():
		segment_color = Color(0.988235, 0.760784, 0.352941, 1)
		stamina_status.text = "RUN"
	elif player.is_stamina_on_cooldown():
		segment_color = Color(0.682353, 0.866667, 0.941176, 1)
		stamina_status.text = "REC"
	else:
		stamina_status.text = "STA"

	for index in range(segment_count):
		var segment := stamina_segments.get_node("Segment%d" % index) as ColorRect
		segment.visible = index < filled_segments
		segment.color = segment_color


func _on_outside_door_body_entered(body: Node) -> void:
	if body != player or _teleport_cooldown > 0.0 or _is_transitioning:
		return

	_start_room_transition(inside_spawn.global_position)


func _on_inside_door_body_entered(body: Node) -> void:
	if body != player or _teleport_cooldown > 0.0 or _is_transitioning:
		return

	_start_room_transition(outside_spawn.global_position)


func _start_room_transition(target_position: Vector2) -> void:
	_is_transitioning = true
	_teleport_cooldown = 0.45
	player.set_movement_locked(true)
	player.snap_camera_for_room_transition()
	_update_prompt("")

	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "color:a", 1.0, 0.2)
	fade_in.finished.connect(
		func() -> void:
			player.global_position = target_position
			player.camera.force_update_scroll()

			var fade_out := create_tween()
			fade_out.tween_property(fade_rect, "color:a", 0.0, 0.2)
			fade_out.finished.connect(
				func() -> void:
					player.restore_camera_after_room_transition()
					player.set_movement_locked(false)
					_is_transitioning = false
			)
	)


func _setup_hotbar() -> void:
	_hotbar = [
		{"id": ITEM_BUCKET, "label": "Balde", "count": BUCKET_MAX_CHARGES},
		{"id": ITEM_AXE, "label": "Machado", "count": 1},
		{"id": "", "label": "Vazio", "count": 0},
		{"id": "", "label": "Vazio", "count": 0},
		{"id": "", "label": "Vazio", "count": 0},
	]


func _try_hotbar_selection(keycode: int) -> void:
	var mapping := {
		KEY_1: 0,
		KEY_2: 1,
		KEY_3: 2,
		KEY_4: 3,
		KEY_5: 4,
	}
	if mapping.has(keycode):
		_selected_hotbar_index = mapping[keycode]


func _find_slot_index(item_id: String) -> int:
	for index in range(_hotbar.size()):
		if _hotbar[index]["id"] == item_id:
			return index
	return -1


func _has_item(item_id: String) -> bool:
	return _find_slot_index(item_id) >= 0


func _get_item_count(item_id: String) -> int:
	var slot_index := _find_slot_index(item_id)
	if slot_index < 0:
		return 0
	return int(_hotbar[slot_index]["count"])


func _add_item(item_id: String, label: String, amount: int) -> bool:
	var slot_index := _find_slot_index(item_id)
	if slot_index >= 0:
		_hotbar[slot_index]["count"] = int(_hotbar[slot_index]["count"]) + amount
		return true

	for index in range(_hotbar.size()):
		if _hotbar[index]["id"] == "":
			_hotbar[index] = {"id": item_id, "label": label, "count": amount}
			return true

	return false


func _remove_item(item_id: String, amount: int) -> bool:
	var slot_index := _find_slot_index(item_id)
	if slot_index < 0 or int(_hotbar[slot_index]["count"]) < amount:
		return false

	_hotbar[slot_index]["count"] = int(_hotbar[slot_index]["count"]) - amount
	if int(_hotbar[slot_index]["count"]) <= 0 and item_id != ITEM_BUCKET and item_id != ITEM_AXE:
		_hotbar[slot_index] = {"id": "", "label": "Vazio", "count": 0}
	elif item_id == ITEM_BUCKET and int(_hotbar[slot_index]["count"]) <= 0:
		_hotbar[slot_index]["count"] = 0
	return true


func _get_selected_slot_label() -> String:
	var slot := _hotbar[_selected_hotbar_index]
	if slot["id"] == "":
		return "Vazio"
	return "%d: %s" % [_selected_hotbar_index + 1, slot["label"]]


func _get_selected_item_id() -> String:
	return str(_hotbar[_selected_hotbar_index]["id"])


func _refresh_hotbar_ui() -> void:
	for index in range(min(_hotbar.size(), hotbar_slots.size())):
		var slot_panel: Panel = hotbar_slots[index]
		var icon_label: Label = slot_panel.get_node("Icon")
		var count_label: Label = slot_panel.get_node("Count")
		var slot: Dictionary = _hotbar[index]
		var is_selected := index == _selected_hotbar_index

		icon_label.text = _get_item_icon(str(slot["id"]))
		count_label.text = _get_slot_count_text(slot)

		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.12, 0.12, 0.9)
		style.set_corner_radius_all(6)
		style.border_width_left = 3 if is_selected else 1
		style.border_width_top = 3 if is_selected else 1
		style.border_width_right = 3 if is_selected else 1
		style.border_width_bottom = 3 if is_selected else 1
		style.border_color = Color.WHITE if is_selected else Color(0.35, 0.35, 0.35, 1)
		slot_panel.add_theme_stylebox_override("panel", style)


func _get_item_icon(item_id: String) -> String:
	match item_id:
		ITEM_BUCKET:
			return "BU"
		ITEM_AXE:
			return "AX"
		ITEM_SEEDS:
			return "SD"
		ITEM_CROP:
			return "TR"
		ITEM_WOOD:
			return "WD"
		ITEM_BREAD:
			return "PO"
		_:
			return "--"


func _get_slot_count_text(slot: Dictionary) -> String:
	var item_id := str(slot["id"])
	var count := int(slot["count"])
	if item_id == "":
		return ""
	if item_id == ITEM_BUCKET:
		return "%d/%d" % [count, BUCKET_MAX_CHARGES]
	if count <= 1:
		return ""
	return str(count)


func _build_tutorial_ui() -> void:
	_tutorial_dialogue_panel = Panel.new()
	_tutorial_dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_tutorial_dialogue_panel.offset_left = 40.0
	_tutorial_dialogue_panel.offset_right = -40.0
	_tutorial_dialogue_panel.offset_top = -148.0
	_tutorial_dialogue_panel.offset_bottom = -16.0
	_tutorial_dialogue_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.93)
	style.set_corner_radius_all(5)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.38, 0.28, 0.20, 1)
	_tutorial_dialogue_panel.add_theme_stylebox_override("panel", style)
	transition_layer.add_child(_tutorial_dialogue_panel)

	_tutorial_dialogue_name_label = Label.new()
	_tutorial_dialogue_name_label.position = Vector2(14, 10)
	_tutorial_dialogue_name_label.add_theme_font_size_override("font_size", 16)
	_tutorial_dialogue_name_label.modulate = Color(0.95, 0.82, 0.52, 1)
	_tutorial_dialogue_panel.add_child(_tutorial_dialogue_name_label)

	_tutorial_dialogue_text_label = Label.new()
	_tutorial_dialogue_text_label.position = Vector2(14, 40)
	_tutorial_dialogue_text_label.size = Vector2(900, 80)
	_tutorial_dialogue_text_label.add_theme_font_size_override("font_size", 15)
	_tutorial_dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tutorial_dialogue_panel.add_child(_tutorial_dialogue_text_label)

	var continue_hint := Label.new()
	continue_hint.position = Vector2(14, 118)
	continue_hint.add_theme_font_size_override("font_size", 12)
	continue_hint.modulate = Color(0.55, 0.55, 0.55, 1)
	continue_hint.text = "[F] continuar"
	continue_hint.name = "ContinueHint"
	_tutorial_dialogue_panel.add_child(continue_hint)


func _create_tutorial_npc() -> void:
	_tutorial_npc_body = Node2D.new()
	_tutorial_npc_body.name = "TutorialNPC"
	_tutorial_npc_body.position = outside_spawn.global_position + Vector2(80, -36)
	add_child(_tutorial_npc_body)

	_tutorial_npc_visual_body = Polygon2D.new()
	_tutorial_npc_visual_body.color = Color(0.52, 0.40, 0.30, 1)
	_tutorial_npc_visual_body.polygon = PackedVector2Array([
		Vector2(-6, -2), Vector2(6, -2),
		Vector2(7, 14), Vector2(-7, 14),
	])
	_tutorial_npc_body.add_child(_tutorial_npc_visual_body)

	_tutorial_npc_visual_head = Polygon2D.new()
	_tutorial_npc_visual_head.color = Color(0.82, 0.68, 0.54, 1)
	_tutorial_npc_visual_head.polygon = PackedVector2Array([
		Vector2(-5, -15), Vector2(5, -15),
		Vector2(6, -3), Vector2(-6, -3),
	])
	_tutorial_npc_body.add_child(_tutorial_npc_visual_head)

	_tutorial_npc_area = Area2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 44.0
	col.shape = shape
	_tutorial_npc_area.add_child(col)
	_tutorial_npc_body.add_child(_tutorial_npc_area)

	_register_polygon_highlight(_tutorial_npc_visual_body)


func _update_tutorial_npc(delta: float) -> void:
	if _tutorial_phase == TutorialPhase.DEAD:
		return

	match _tutorial_phase:
		TutorialPhase.AWAIT_APPROACH:
			if _tutorial_npc_body != null and player.global_position.distance_to(_tutorial_npc_body.global_position) < 72.0:
				_begin_tutorial_dialogue()
		TutorialPhase.NIGHT_WARN:
			_update_npc_night_warn(delta)
		TutorialPhase.NIGHT_RUN_GENERATOR:
			_update_npc_night_run_generator(delta)
		TutorialPhase.DYING:
			_update_npc_dying(delta)


func _update_npc_night_warn(delta: float) -> void:
	var dist := _tutorial_npc_body.global_position.distance_to(player.global_position)
	if dist > 52.0:
		var dir := _tutorial_npc_body.global_position.direction_to(player.global_position)
		_tutorial_npc_body.global_position += dir * TUTORIAL_NPC_SPEED * delta

	_tutorial_night_timer = maxf(_tutorial_night_timer - delta, 0.0)
	match _tutorial_night_step:
		0:
			if dist < 64.0:
				_tutorial_night_step = 1
				_tutorial_night_timer = 3.5
				_show_tutorial_dialogue("A noite caiu! Va para dentro agora!")
		1:
			if _tutorial_night_timer <= 0.0:
				_tutorial_night_step = 2
				_tutorial_night_timer = 3.0
				_show_tutorial_dialogue("Espera... o gerador. Eu esqueci de liga-lo!")
		2:
			if _tutorial_night_timer <= 0.0:
				_tutorial_night_step = 3
				_tutorial_night_timer = 2.5
				_show_tutorial_dialogue("Fique aqui dentro. Volto em um instante.")
		3:
			if _tutorial_night_timer <= 0.0:
				_tutorial_phase = TutorialPhase.NIGHT_RUN_GENERATOR
				_tutorial_night_step = 0
				_tutorial_night_timer = 0.0
				_close_tutorial_dialogue()


func _update_npc_night_run_generator(delta: float) -> void:
	var gen_pos := _generator_area.global_position
	var dist := _tutorial_npc_body.global_position.distance_to(gen_pos)

	if dist > 18.0:
		var dir := _tutorial_npc_body.global_position.direction_to(gen_pos)
		_tutorial_npc_body.global_position += dir * TUTORIAL_NPC_SPEED * delta
		return

	_tutorial_night_timer = maxf(_tutorial_night_timer - delta, 0.0)
	match _tutorial_night_step:
		0:
			_tutorial_night_step = 1
			_tutorial_night_timer = 2.0
			_generator_fuel = GENERATOR_WOOD_PER_NIGHT * GENERATOR_FUEL_PER_WOOD
			_generator_active = true
			_refresh_generator_visuals()
			_show_tutorial_dialogue("Aqui... consegui. Os refletores estao ligados.")
		1:
			if _tutorial_night_timer <= 0.0:
				_tutorial_night_step = 2
				_tutorial_night_timer = 2.5
				if hostile_audio.stream != null:
					hostile_audio.play()
				_show_tutorial_dialogue("...")
		2:
			if _tutorial_night_timer <= 0.0:
				_tutorial_night_step = 3
				_tutorial_night_timer = 3.0
				hostile_audio.stop()
				_show_tutorial_dialogue("F- fuja. FUJA!")
		3:
			if _tutorial_night_timer <= 0.0:
				_tutorial_phase = TutorialPhase.DYING
				_tutorial_night_step = 0
				_tutorial_night_timer = 2.0
				_close_tutorial_dialogue()
				_hostile_alert_text = "%s foi arrastado para as trevas." % TUTORIAL_NPC_NAME


func _update_npc_dying(delta: float) -> void:
	_tutorial_night_timer = maxf(_tutorial_night_timer - delta, 0.0)
	var alpha := _tutorial_night_timer / 2.0
	_tutorial_npc_visual_body.color = Color(0.65, 0.08, 0.08, alpha)
	_tutorial_npc_visual_head.color = Color(0.82, 0.68, 0.54, alpha)

	if _tutorial_night_timer <= 0.0:
		_tutorial_phase = TutorialPhase.DEAD
		_first_night_done = true
		_tutorial_npc_body.queue_free()
		_tutorial_npc_body = null
		_hostile_state = HostileEventState.IDLE
		_hostile_trigger_timer = NIGHT_WARNING_DELAY


func _begin_tutorial_dialogue() -> void:
	_tutorial_phase = TutorialPhase.IN_DIALOGUE
	_tutorial_dialogue_index = 0
	_show_tutorial_dialogue(TUTORIAL_LINES[0])
	var hint := _tutorial_dialogue_panel.get_node_or_null("ContinueHint") as Label
	if hint != null:
		hint.visible = true


func _advance_tutorial_dialogue() -> void:
	_tutorial_dialogue_index += 1
	if _tutorial_dialogue_index >= TUTORIAL_LINES.size():
		_tutorial_phase = TutorialPhase.IDLE
		_close_tutorial_dialogue()
		return
	_show_tutorial_dialogue(TUTORIAL_LINES[_tutorial_dialogue_index])


func _interact_with_tutorial_npc() -> void:
	if _tutorial_phase == TutorialPhase.IN_DIALOGUE:
		_advance_tutorial_dialogue()
	elif _tutorial_phase == TutorialPhase.IDLE:
		_begin_tutorial_dialogue()


func _show_tutorial_dialogue(text: String) -> void:
	_tutorial_dialogue_panel.visible = true
	_tutorial_dialogue_name_label.text = TUTORIAL_NPC_NAME
	_tutorial_dialogue_text_label.text = text


func _close_tutorial_dialogue() -> void:
	_tutorial_dialogue_panel.visible = false


func _begin_tutorial_night_sequence() -> void:
	_tutorial_phase = TutorialPhase.NIGHT_WARN
	_tutorial_night_step = 0
	_tutorial_night_timer = 0.0
	_hostile_state = HostileEventState.COOLDOWN
	_hostile_state_timer = 9999.0


func _refresh_player_held_item() -> void:
	var item_id := _get_selected_item_id()
	var short_label := _get_item_icon(item_id)
	var color := _get_item_color(item_id)
	player.set_held_item(item_id, short_label, color)


func _get_item_color(item_id: String) -> Color:
	match item_id:
		ITEM_BUCKET:
			return Color(0.478431, 0.635294, 0.780392, 1)
		ITEM_AXE:
			return Color(0.639216, 0.403922, 0.247059, 1)
		ITEM_SEEDS:
			return Color(0.729412, 0.607843, 0.294118, 1)
		ITEM_CROP:
			return Color(0.831373, 0.811765, 0.372549, 1)
		ITEM_WOOD:
			return Color(0.572549, 0.384314, 0.239216, 1)
		ITEM_BREAD:
			return Color(0.874510, 0.745098, 0.447059, 1)
		_:
			return Color(0.4, 0.4, 0.4, 1)
