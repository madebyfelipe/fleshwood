extends Node2D

const FarmEnemyScene = preload("res://scenes/farm_enemy.tscn")
const DarkwatcherShopUIScript = preload("res://scripts/darkwatcher_shop_ui.gd")

var TEX_HOTBAR_SELECTED: Texture2D = null
var TEX_HOTBAR_NOT_SELECTED: Texture2D = null
var TEX_BAR_FRAME: Texture2D = null
var TEX_BAR_TILE: Texture2D = null
var TEX_ICON_BUCKET: Texture2D = null
var TEX_ICON_AXE: Texture2D = null
var TEX_ICON_SEEDS: Texture2D = null
var TEX_ICON_BREAD: Texture2D = null
var TEX_ICON_FLASHLIGHT: Texture2D = null

const INTERACT_DISTANCE := 56.0
const DAY_DURATION := 600.0
const NIGHT_DURATION := 300.0
const DAWN_HOUR := 7   # 07:00 — amanhecer
const DUSK_HOUR := 19  # 19:00 — anoitecer
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
const TREE_HITS_TO_FALL := 4
const GENERATOR_WOOD_PER_NIGHT := 30
const GENERATOR_FUEL_PER_WOOD := NIGHT_DURATION / float(GENERATOR_WOOD_PER_NIGHT)
const GENERATOR_FUEL_DRAIN_PER_SECOND := 1.0
const NIGHT_WARNING_DELAY := 5.0
const HOSTILE_COOLDOWN_DURATION := 5.0
const FOREST_DAY_WARNING_DELAY    := 35.0  # tempo de espera (IDLE) antes do aviso começar (dia)
const FOREST_NIGHT_WARNING_DURATION := 3.0  # duração da fase de aviso antes do spawn (noite)
const FOREST_DAY_WARNING_DURATION   := 12.0 # duração da fase de aviso antes do spawn (dia)
const PLAYER_EXPULSION_OFFSET := Vector2(0, 72)
const PLAYER_COLLAPSE_COIN_PENALTY := 10
const PLAYER_VISION_RANGE := 280.0
const PLAYER_VISION_DOT_THRESHOLD := 0.45
const REFLECTOR_RADIUS := 212.0
const FLASHLIGHT_RANGE := 320.0
const FLASHLIGHT_CONE_DOT := 0.82  # cos(35°) — cone total de ~70°
const LANTERN_BATTERY_MAX := NIGHT_DURATION / 4.0  # ~33.75s = 1/4 da duração da noite

# — Mimic (sabotageia o gerador)
const MIMIC_SPEED := 55.0
const MIMIC_FLEE_SPEED := 170.0
const MIMIC_FLEE_RADIUS := 96.0        # distância para fugir do player
const MIMIC_SABOTAGE_RADIUS := 40.0   # distância para desligar o gerador
const MIMIC_MIN_TRIGGER := 30.0       # quando pode aparecer na noite (segundos)
const MIMIC_MAX_TRIGGER := 80.0

# — Wendigo (anunciado, carrega o player; escala por noite)
const WENDIGO_PATROL_DURATION     := 60.0  # tempo total de presença no mapa
const WENDIGO_PATROL_SPEED        := 80.0  # velocidade de ronda
const WENDIGO_PATROL_DETECT_RANGE := 180.0 # proximidade que dispara a perseguição
const WENDIGO_CHARGE_SPEED        := 255.0
const WENDIGO_CHARGE_DURATION     := 7.0   # tempo de perseguição antes de voltar a rondar
const WENDIGO_COOLDOWN_MIN        := 38.0
const WENDIGO_COOLDOWN_MAX        := 65.0

const HUNGER_MAX := 100.0
const THIRST_MAX := 100.0
const HEALTH_MAX := 100.0
const HUNGER_DRAIN_PER_SECOND := 0.22

# ── Ansiedade (chase sequence) ────────────────────────────────────────────────
const MAX_ANXIETY_DISTANCE := 380.0
const MIN_ANXIETY_DISTANCE := 70.0
const ANXIETY_FADE_IN_SPEED := 2.0
const ANXIETY_FADE_OUT_SPEED := 1.2
const THIRST_DRAIN_PER_SECOND := 0.34
const HEALTH_DECAY_PER_SECOND := 5.5
const HEALTH_RECOVERY_PER_SECOND := 1.2

const ITEM_BUCKET := "bucket"
const ITEM_AXE := "axe"
const ITEM_SEEDS := "seeds"
const ITEM_CROP := "crop"
const ITEM_WOOD := "wood"
const ITEM_BREAD := "pao"
const ITEM_LANTERN := "lanterna"

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

enum MimicState {
	INACTIVE,    # aguardando o timer de spawn
	APPROACHING, # caminhando em direção ao gerador
	FLEEING,     # fugindo do player ou após sabotagem
	DONE,        # já apareceu esta noite
}

enum WendigoState {
	INACTIVE,    # aguardando cooldown
	PATROLLING,  # rondando a região inferior do mapa (até 60s)
	CHARGING,    # perseguindo o player
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

enum DarkwatcherPhase {
	INACTIVE,
	AWAIT_APPROACH,
	IN_DIALOGUE,
	DONE,
}

const TUTORIAL_NPC_SPEED := 70.0
const TUTORIAL_NPC_NAME := "Caim"
const TUTORIAL_LINES := [
	"Hey, son! It's great to have you around.",
	"I am far from a young man so I really appreciate your help with the ranch.",
	"I need you to plant the seeds I left inside. Plant them using [F], water with the bucket, harvest when yellow.",
	"Once it's finished, deposit them on the box by the left of the house. A man in suit will come by and get it every other day.",
	"If you feel hungry, feel free to use the wheat to make some bread using the cooking pot inside.",
	"Also, take my word for that: DO NOT go outside at night. I keep some lights around to help with it, but trust my word for that",
	"Can't say much about it, you'll have to take my word for that. Sorry, boy,",
	"Anyways, about that seeds, once you're finished we'll get some firewood in the forest.",
]

const DARKWATCHER_NAME := "Observador"
const DARKWATCHER_LINES := [
	"Greetings, young man.",
	"I do not recognize you, but I can tell you had some sort of deal with the old man who was before you.",
	"How'd I know? Some things are better left unknown...",
	"I have great news, though! You can use the coins I just gave you to get new tools for your new endeavor.",
	"What happened with the old man? You will find out, trust me. It's better we keep things professional, for both of us",
]

@onready var world_visuals: Node2D = $WorldVisuals
@onready var outside_door: Area2D = $OutsideDoor
@onready var inside_door: Area2D = $InsideDoor
@onready var forest_entrance: Area2D = $ForestEntrance
@onready var player: PlayerController = $Player
@onready var outside_spawn: Marker2D = $Markers/OutsideSpawn
@onready var inside_spawn: Marker2D = $Markers/InsideSpawn
@onready var forest_spawn: Marker2D = $Markers/ForestSpawn
@onready var forest_return: Marker2D = $Markers/ForestReturn
@onready var forest_exit: Area2D = $FlorestaDeCarne/ForestExit
@onready var enemy_spawn: Marker2D = $Markers/EnemySpawn
@onready var forest_enemy_spawn: Marker2D = $Markers/ForestEnemySpawn
@onready var forest_enemy_route_markers: Node2D = $Markers/ForestEnemyRoute
@onready var wendigo_spawn: Marker2D = $Markers/WendigoSpawn
@onready var wendigo_route_markers: Node2D = $Markers/WendigoRoute
@onready var wendigo_forest_spawn: Marker2D = $Markers/WendigoForestSpawn
@onready var wendigo_forest_route_markers: Node2D = $Markers/WendigoForestRoute
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
@onready var forest_trees: Node2D = $FlorestaDeCarne/Trees
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
@onready var tilemap_ground: TileMapLayer = $TileMapGround

var _teleport_cooldown := 0.0
var _is_transitioning := false
var _near_outside_door := false
var _near_inside_door := false
var _plots: Array[Dictionary] = []
var _active_interaction: Dictionary = {}
var _coins := 12
var _day_number := 1
var _is_night := false
var _in_forest := false
var _phase_elapsed := 0.0
var _cycle_cheat_held := false
var _hotbar: Array[Dictionary] = []
var _selected_hotbar_index := 0
var _highlight_lines: Dictionary = {}
var _hostile_state := HostileEventState.IDLE
var _hostile_state_timer := 0.0
var _hostile_trigger_timer := NIGHT_WARNING_DELAY
var _warning_plays_remaining := 0
var _hostile_route: Array[Vector2] = []
var _forest_hostile_route: Array[Vector2] = []
var _hostile_alert_text := ""
var _active_enemy: FarmEnemy = null
var _chase_audio: AudioStreamPlayer = null
var _free_seed_claim_available := true
var _hunger := HUNGER_MAX
var _thirst := THIRST_MAX
var _health := HEALTH_MAX
var _status_labels: Dictionary = {}
var _hunger_bar_fill: ColorRect = null
var _thirst_bar_fill: ColorRect = null
var _health_bar_fill: ColorRect = null
var _stamina_bar_clip: Control = null
var _stamina_bar_tile: TextureRect = null
@onready var _generator_area: Area2D = $Generator
@onready var _generator_visual: Polygon2D = $Generator/Visual
@onready var _generator_sprite: Sprite2D = $Generator/Sprite
@onready var _generator_glow: Polygon2D = $Generator/Glow
@onready var _reflectors_container: Node2D = $Reflectors
var _reflector_positions: Array[Vector2] = []
var _reflector_visuals: Array[Polygon2D] = []
var _night_shader_mat: ShaderMaterial = null
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
var _tutorial_npc_sprite: AnimatedSprite2D = null
var _tutorial_npc_area: Area2D = null
var _tutorial_dialogue_index := 0
var _tutorial_night_timer := 0.0
var _tutorial_night_step := 0
var _first_night_done := false
var _tutorial_dialogue_panel: Panel = null
var _tutorial_dialogue_name_label: Label = null
var _tutorial_dialogue_text_label: Label = null

var _darkwatcher_phase := DarkwatcherPhase.INACTIVE
var _darkwatcher_body: Node2D = null
var _darkwatcher_sprite: AnimatedSprite2D = null
var _darkwatcher_area: Area2D = null
var _darkwatcher_dialogue_index := 0
var _lantern_bought := false
var _flashlight_active := false
var _lantern_battery := LANTERN_BATTERY_MAX
var _battery_recharged_today := false

# — Alerta do gerador (timer para limpar a mensagem)
var _generator_alert_timer := 0.0
var _generator_hits := 0
var _generator_sabotaged := false

# — Mimic
var _mimic_state := MimicState.INACTIVE
var _mimic_node: Node2D = null
var _mimic_trigger_timer := 0.0
var _mimic_flee_timer := 0.0

# — Wendigo
var _wendigo_state := WendigoState.INACTIVE
var _wendigo_state_timer := 0.0
var _wendigo_patrol_timer  := 0.0   # timer geral de presença (60s)
var _wendigo_patrol_index  := 0     # waypoint atual da rota
var _wendigo_route: Array[Vector2] = []
var _wendigo_forest_route: Array[Vector2] = []
var _wendigo_in_forest := false  # true quando o Wendigo desta aparição spawnou na floresta
var _wendigo_node: Node2D = null
var _wendigo_sprite: AnimatedSprite2D = null
var _wendigo_appearances_tonight := 0
var _wendigo_max_tonight := 0
var _wendigo_cooldown_timer := 0.0

# ── Ansiedade (chase sequence) ────────────────────────────────────────────────
var _anxiety_layer: CanvasLayer = null
var _vignette_rect: ColorRect = null
var _tint_rect: ColorRect = null
var _anxiety_shader_mat: ShaderMaterial = null
var _anxiety_active := false
var _anxiety_current := 0.0
var _anxiety_pulse_time := 0.0

# ── Inventário ────────────────────────────────────────────────────────────────
var _inventory_data: InventoryData = null
var _inventory_ui:   InventoryUI   = null
var _item_icon_map:  Dictionary    = {}
var _darkwatcher_shop_ui = null


func _load_ui_textures() -> void:
	TEX_HOTBAR_SELECTED     = load("res://assets/interface/hotbar_selected.png") as Texture2D
	TEX_HOTBAR_NOT_SELECTED = load("res://assets/interface/hotbar_not_selected.png") as Texture2D
	TEX_BAR_FRAME           = load("res://assets/interface/progress.png") as Texture2D
	TEX_BAR_TILE            = load("res://assets/interface/bar.png") as Texture2D
	TEX_ICON_BUCKET         = load("res://assets/interface/icons/Milk_Bucket_JE2_BE2.png") as Texture2D
	TEX_ICON_AXE            = load("res://assets/interface/icons/Diamond_Axe_JE3_BE3.png") as Texture2D
	TEX_ICON_SEEDS          = load("res://assets/interface/icons/seed.png") as Texture2D
	TEX_ICON_BREAD          = load("res://assets/interface/icons/Bread_JE3_BE3.webp") as Texture2D
	TEX_ICON_FLASHLIGHT     = load("res://assets/interface/icons/flashlight.png") as Texture2D


func _ready() -> void:
	randomize()
	_load_ui_textures()
	_ensure_input_actions()
	_configure_overlay()
	_setup_hotbar()
	_setup_inventory()
	_cache_farm_plots()
	_cache_enemy_route()
	_cache_forest_enemy_route()
	_cache_wendigo_route()
	_create_runtime_farm_nodes()
	_cache_tree_sources()
	_setup_interaction_highlights()
	_build_stamina_bar()
	_build_survival_ui()
	_build_tutorial_ui()
	_create_anxiety_overlay()
	player.global_position = outside_spawn.global_position
	_refresh_generator_visuals()
	_refresh_ui()

	hostile_audio.stream = load("res://assets/sfx/danger1.wav")
	hostile_audio.finished.connect(_on_warning_audio_finished)

	_chase_audio = AudioStreamPlayer.new()
	_chase_audio.stream = load("res://assets/sfx/chase sequence.wav")
	_chase_audio.volume_db = 0.0
	add_child(_chase_audio)

	outside_door.body_entered.connect(_on_outside_door_body_entered)
	outside_door.body_exited.connect(_on_outside_door_body_exited)
	inside_door.body_entered.connect(_on_inside_door_body_entered)
	inside_door.body_exited.connect(_on_inside_door_body_exited)
	forest_entrance.body_entered.connect(_on_forest_entrance_body_entered)
	forest_exit.body_entered.connect(_on_forest_exit_body_entered)


func _process(delta: float) -> void:
	_teleport_cooldown = max(_teleport_cooldown - delta, 0.0)
	_update_cycle_cheat()
	_update_day_cycle(delta)
	_update_plot_growth(delta)
	_update_tutorial_npc(delta)
	_update_darkwatcher_npc(delta)
	_update_stove(delta)
	_update_wood_sources(delta)
	_update_generator(delta)
	_update_survival_stats(delta)
	_update_hostile_event(delta)
	_update_mimic(delta)
	_update_wendigo(delta)
	_update_active_interaction()
	_apply_survival_modifiers()
	_update_anxiety(delta)
	_update_flashlight_battery(delta)
	_refresh_ui()
	_update_reflector_light_shader()


func _unhandled_input(event: InputEvent) -> void:
	# Toggle do inventário tem prioridade e bloqueia ações de jogo enquanto aberto
	if event.is_action_pressed("inventory"):
		_toggle_inventory()
		get_viewport().set_input_as_handled()
		return

	if _inventory_ui != null and _inventory_ui.visible:
		return  # bloqueia ações de jogo enquanto inventário está aberto

	if _darkwatcher_shop_ui != null and _darkwatcher_shop_ui.visible:
		return  # bloqueia ações de jogo enquanto loja está aberta

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
		if event.physical_keycode == KEY_TAB:
			_coins += 100
			_skip_tutorial_npc()
			return
		if event.physical_keycode == KEY_O:
			_trigger_hostile_warning_debug()
			return
		if event.physical_keycode == KEY_P:
			if _is_night and _wendigo_state == WendigoState.INACTIVE:
				_wendigo_cooldown_timer = 0.0
			return
		if event.physical_keycode == KEY_I:
			if _is_night and _mimic_state == MimicState.INACTIVE:
				_mimic_trigger_timer = 0.0
			return
		_try_hotbar_selection(event.physical_keycode)


func _ensure_input_actions() -> void:
	if not InputMap.has_action("use_item"):
		InputMap.add_action("use_item")

	if not _action_has_key("use_item", KEY_Q):
		var event := InputEventKey.new()
		event.physical_keycode = KEY_Q
		InputMap.action_add_event("use_item", event)

	if not InputMap.has_action("inventory"):
		InputMap.add_action("inventory")

	if not _action_has_key("inventory", KEY_E):
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("inventory", ev)


func _action_has_key(action_name: String, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


const _NIGHT_SHADER := """
shader_type canvas_item;
uniform vec2 ref_pos_0 = vec2(-1.0, -1.0);
uniform vec2 ref_pos_1 = vec2(-1.0, -1.0);
uniform vec2 ref_pos_2 = vec2(-1.0, -1.0);
uniform float light_radius = 0.68;
uniform float light_radius_2 = 0.50;
uniform float light_on = 0.0;
uniform float light_on_2 = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	float light = 0.0;
	if (ref_pos_0.x >= 0.0) {
		vec2 d = (uv - ref_pos_0) * vec2(1.7778, 1.0);
		light = max(light, (1.0 - smoothstep(light_radius * 0.05, light_radius, length(d))) * light_on);
	}
	if (ref_pos_1.x >= 0.0) {
		vec2 d = (uv - ref_pos_1) * vec2(1.7778, 1.0);
		light = max(light, (1.0 - smoothstep(light_radius * 0.05, light_radius, length(d))) * light_on);
	}
	if (ref_pos_2.x >= 0.0) {
		vec2 d = (uv - ref_pos_2) * vec2(1.7778, 1.0);
		light = max(light, (1.0 - smoothstep(light_radius_2 * 0.05, light_radius_2, length(d))) * light_on_2);
	}
	COLOR.a *= 1.0 - light * 0.95;
}
"""

func _configure_overlay() -> void:
	night_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	night_rect.color = Color(0.054902, 0.0862745, 0.180392, 0.0)
	fade_rect.color = Color(0, 0, 0, 0)
	var shd := Shader.new()
	shd.code = _NIGHT_SHADER
	_night_shader_mat = ShaderMaterial.new()
	_night_shader_mat.shader = shd
	night_rect.material = _night_shader_mat
	stamina_fill.visible = false
	stamina_backdrop.color = Color(0.12549, 0.219608, 0.305882, 1)


func _build_stamina_bar() -> void:
	for child in stamina_segments.get_children():
		child.queue_free()
	stamina_segments.visible = false
	stamina_fill.visible = false

	var stamina_panel: Node = stamina_fill.get_parent()

	# Clip container — largura muda conforme ratio; clip_contents esconde o excesso
	var clip := Control.new()
	clip.position = Vector2(13, 11)
	clip.size = Vector2(150, 20)
	clip.clip_contents = true
	stamina_panel.add_child(clip)
	_stamina_bar_clip = clip

	# Tile da barra (bar.png), sempre 150px de largura; o clip faz o recorte
	if TEX_BAR_TILE != null:
		var tile := TextureRect.new()
		tile.texture = TEX_BAR_TILE
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_TILE
		tile.size = Vector2(150, 20)
		clip.add_child(tile)
		_stamina_bar_tile = tile

	# Frame por cima (draw_center=false → só a borda visível)
	if TEX_BAR_FRAME != null:
		var frame := NinePatchRect.new()
		frame.texture = TEX_BAR_FRAME
		frame.position = Vector2(10, 8)
		frame.size = Vector2(156, 24)
		frame.patch_margin_left = 8
		frame.patch_margin_right = 8
		frame.patch_margin_top = 8
		frame.patch_margin_bottom = 8
		frame.draw_center = false
		stamina_panel.add_child(frame)


func _build_survival_ui() -> void:
	_create_status_label("generator", Vector2(24, 176), 15)

	var bar_configs := [
		{"key": "hunger",  "label": "FOME", "color": Color(0.85, 0.55, 0.1, 1)},
		{"key": "thirst",  "label": "SEDE", "color": Color(0.25, 0.55, 0.9, 1)},
	]

	for i in range(bar_configs.size()):
		var cfg: Dictionary = bar_configs[i]
		var y := 606.0 + i * 32.0

		var lbl := Label.new()
		lbl.position = Vector2(16, y)
		lbl.size = Vector2(42, 26)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.text = cfg["label"]
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		transition_layer.add_child(lbl)

		var container := Control.new()
		container.position = Vector2(62, y)
		container.size = Vector2(140, 26)
		transition_layer.add_child(container)

		var bg := ColorRect.new()
		bg.position = Vector2(6, 6)
		bg.size = Vector2(128, 14)
		bg.color = Color(0.08, 0.08, 0.08, 0.9)
		container.add_child(bg)

		var fill := ColorRect.new()
		fill.position = Vector2(6, 6)
		fill.size = Vector2(128, 14)
		fill.color = cfg["color"]
		container.add_child(fill)

		var frame := NinePatchRect.new()
		frame.texture = TEX_BAR_FRAME
		frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		frame.patch_margin_left = 6
		frame.patch_margin_right = 6
		frame.patch_margin_top = 6
		frame.patch_margin_bottom = 6
		frame.draw_center = false
		container.add_child(frame)

		match cfg["key"]:
			"hunger": _hunger_bar_fill = fill
			"thirst": _thirst_bar_fill = fill


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


func _cache_forest_enemy_route() -> void:
	_forest_hostile_route.clear()

	for child in forest_enemy_route_markers.get_children():
		if child is Marker2D:
			_forest_hostile_route.append((child as Marker2D).global_position)


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
	_setup_reflectors()
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

	var all_tree_containers: Array[Node2D] = [trees_container, forest_trees]
	for container in all_tree_containers:
		_cache_trees_from(container)


func _cache_trees_from(container: Node2D) -> void:
	for child in container.get_children():
		var tree_root := child as Node2D
		if tree_root == null:
			continue

		var interact_area := tree_root.get_node_or_null("InteractArea") as Area2D
		var visual := tree_root.get_node_or_null("Visual") as Sprite2D
		var body := tree_root.get_node_or_null("Body") as StaticBody2D
		if interact_area == null or visual == null:
			continue

		_wood_sources.append({
			"node": tree_root,
			"area": interact_area,
			"visual": visual,
			"body": body,
			"available": true,
			"respawn_timer": 0.0,
			"hits": 0,
		})


func _setup_reflectors() -> void:
	_reflector_positions.clear()
	_reflector_visuals.clear()

	for reflector: Node2D in _reflectors_container.get_children():
		_reflector_positions.append(reflector.global_position)
		var cone := reflector.get_node_or_null("LightCone") as Polygon2D
		if cone != null:
			_reflector_visuals.append(cone)



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
	# árvores usam Sprite2D — não registram highlight de polígono


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

	var target_alpha := 0.78 if _is_night else 0.0
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


# Retorna o horário de jogo atual em minutos totais (0–1439).
# Dia:   07:00 (420) → 19:00 (1140) ao longo de DAY_DURATION segundos reais.
# Noite: 19:00 (1140) → 07:00 (420) ao longo de NIGHT_DURATION segundos reais.
func _get_game_minutes() -> float:
	if _is_night:
		var progress := clampf(_phase_elapsed / NIGHT_DURATION, 0.0, 1.0)
		return fmod(DUSK_HOUR * 60.0 + progress * (24 - DUSK_HOUR + DAWN_HOUR) * 60.0, 1440.0)
	else:
		var progress := clampf(_phase_elapsed / DAY_DURATION, 0.0, 1.0)
		return DAWN_HOUR * 60.0 + progress * (DUSK_HOUR - DAWN_HOUR) * 60.0


func _get_time_string() -> String:
	var total_min := int(_get_game_minutes())
	return "%02d:%02d" % [total_min / 60, total_min % 60]


func _advance_day_phase() -> void:
	_phase_elapsed = 0.0
	if _is_night:
		_day_number += 1
		_is_night = false
		_stop_hostile_event(false)
		_generator_active = false
		_generator_sabotaged = false
		_generator_hits = 0
		_hostile_alert_text = ""
		_clear_mimic()
		_mimic_state = MimicState.INACTIVE
		_clear_wendigo()
		_wendigo_state = WendigoState.INACTIVE
		_flashlight_active = false
		player.set_flashlight_on(false)
		_battery_recharged_today = false
		if _day_number == 2 and _darkwatcher_phase == DarkwatcherPhase.INACTIVE:
			_spawn_darkwatcher()
	else:
		_is_night = true
		_schedule_next_hostile_event()
		# Mimic: garante uma aparição por noite, horário aleatório
		_mimic_state = MimicState.INACTIVE
		_mimic_trigger_timer = randf_range(MIMIC_MIN_TRIGGER, MIMIC_MAX_TRIGGER)
		# Wendigo: escala com o número de noites (_day_number é o número da noite atual)
		_wendigo_appearances_tonight = 0
		_wendigo_max_tonight = _day_number / 2  # noite 1→0, noites 2-3→1, noites 4-5→2...
		_wendigo_state = WendigoState.INACTIVE
		_wendigo_state_timer = 0.0
		_wendigo_cooldown_timer = randf_range(WENDIGO_COOLDOWN_MIN, WENDIGO_COOLDOWN_MAX)
		if _day_number == 1 and not _first_night_done and _tutorial_phase != TutorialPhase.DEAD:
			_begin_tutorial_night_sequence()


func _schedule_next_hostile_event() -> void:
	_hostile_state = HostileEventState.IDLE
	_hostile_state_timer = 0.0
	_hostile_trigger_timer = NIGHT_WARNING_DELAY
	_hostile_alert_text = ""


func _trigger_hostile_warning_debug() -> void:
	if (not _is_night and not _in_forest) or _is_transitioning:
		return

	var active_route := _forest_hostile_route if _in_forest else _hostile_route
	if _hostile_state != HostileEventState.IDLE or active_route.is_empty():
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
		source["hits"] = 0
		var visual := source["visual"] as Sprite2D
		visual.visible = true
		visual.modulate = Color.WHITE
		visual.rotation = 0.0
		var body := source["body"] as StaticBody2D
		if body != null:
			body.collision_layer = 1
			body.collision_mask = 1


func _update_generator(delta: float) -> void:
	if _generator_alert_timer > 0.0:
		_generator_alert_timer = max(_generator_alert_timer - delta, 0.0)
		if _generator_alert_timer <= 0.0:
			_hostile_alert_text = ""

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


func _update_flashlight_battery(delta: float) -> void:
	# Auto-desliga se a lanterna não está selecionada na hotbar
	if _flashlight_active and _get_selected_item_id() != ITEM_LANTERN:
		_flashlight_active = false
		player.set_flashlight_on(false)
	# Drena bateria enquanto a lanterna está ligada
	if _flashlight_active:
		_lantern_battery = maxf(_lantern_battery - delta, 0.0)
		if _lantern_battery <= 0.0:
			_flashlight_active = false
			player.set_flashlight_on(false)


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
	if not _is_night and not _in_forest:
		return

	match _hostile_state:
		HostileEventState.IDLE:
			if not _in_forest and _is_farm_defended():
				return

			_hostile_trigger_timer = max(_hostile_trigger_timer - delta, 0.0)
			var active_route := _forest_hostile_route if _in_forest else _hostile_route
			if _hostile_trigger_timer <= 0.0 and not _is_transitioning and not active_route.is_empty():
				_begin_hostile_warning()
		HostileEventState.WARNING:
			if not _in_forest and _is_farm_defended():
				_hostile_state = HostileEventState.COOLDOWN
				_hostile_state_timer = 4.0
				_hostile_alert_text = "A criatura ronda, mas nao atravessa a luz."
				return

			_hostile_state_timer = max(_hostile_state_timer - delta, 0.0)
			if _hostile_state_timer <= 0.0 and not _is_transitioning:
				_spawn_hostile_enemy()
		HostileEventState.ACTIVE:
			# Gerador ligado durante perseguição ativa: Goatman é forçado a recuar
			if not _in_forest and _is_farm_defended() and is_instance_valid(_active_enemy):
				_stop_hostile_event(true)
				_hostile_alert_text = "Os refletores forçaram o Goatman a recuar!"
				return
			if _active_enemy == null and not _is_transitioning:
				_hostile_state = HostileEventState.COOLDOWN
				_hostile_state_timer = HOSTILE_COOLDOWN_DURATION
		HostileEventState.COOLDOWN:
			_hostile_state_timer = max(_hostile_state_timer - delta, 0.0)
			if _hostile_state_timer <= 0.0:
				_hostile_state = HostileEventState.IDLE
				if _in_forest:
					_hostile_trigger_timer = FOREST_DAY_WARNING_DELAY if not _is_night else NIGHT_WARNING_DELAY
					_hostile_alert_text = ""
				elif _is_farm_defended():
					_hostile_trigger_timer = 3.5
					_hostile_alert_text = "A luz ainda segura a noite."
				else:
					_hostile_trigger_timer = NIGHT_WARNING_DELAY
					_hostile_alert_text = ""


func _begin_hostile_warning() -> void:
	_hostile_state = HostileEventState.WARNING
	# Duração do aviso antes do spawn: floresta tem tempo diferente por dia/noite
	if _in_forest:
		_hostile_state_timer = FOREST_DAY_WARNING_DURATION if not _is_night else FOREST_NIGHT_WARNING_DURATION
	else:
		_hostile_state_timer = NIGHT_WARNING_DELAY
	_hostile_alert_text = "Um farfalhar entre as arvores. Algo espreitando." if _in_forest else "Um berrar ecoa alem da cerca."
	# Som de aviso só toca se o gerador estiver desligado
	if hostile_audio.stream != null and not _generator_active:
		_warning_plays_remaining = 5
		hostile_audio.play()


func _on_warning_audio_finished() -> void:
	if _warning_plays_remaining > 0:
		_warning_plays_remaining -= 1
		hostile_audio.play()


func _spawn_hostile_enemy() -> void:
	_warning_plays_remaining = 0
	hostile_audio.stop()
	_clear_active_enemy()

	# Fazenda protegida: gerador ligado bloqueia o spawn
	if not _in_forest and _is_farm_defended():
		_hostile_state = HostileEventState.COOLDOWN
		_hostile_state_timer = HOSTILE_COOLDOWN_DURATION
		return

	var spawn_pos := forest_enemy_spawn.global_position if _in_forest else enemy_spawn.global_position
	var route := _forest_hostile_route if _in_forest else _hostile_route
	var is_forest_day := _in_forest and not _is_night

	if route.is_empty():
		_hostile_state = HostileEventState.IDLE
		return

	# Perseguição imediata: fazenda sem gerador, ou floresta à noite
	# Floresta de dia: Goatman precisa ver o player (cone de visão)
	var spotted_immediately := (not _in_forest and not _generator_active) or (_in_forest and _is_night)

	_hostile_state = HostileEventState.ACTIVE
	_hostile_alert_text = "O Goatman espreita entre as arvores." if _in_forest else "Goatman avancou pela escuridao."
	_active_enemy = FarmEnemyScene.instantiate() as FarmEnemy
	add_child(_active_enemy)
	# Conectar sinais ANTES de start() para que player_spotted dispare corretamente
	# quando spotted_immediately=true (o sinal é emitido dentro de start())
	_active_enemy.route_finished.connect(_on_enemy_route_finished)
	_active_enemy.player_caught.connect(_on_enemy_player_caught)
	_active_enemy.repelled.connect(_on_enemy_repelled)
	_active_enemy.player_spotted.connect(_on_goatman_player_spotted)
	_active_enemy.start(
		spawn_pos,
		route,
		player,
		Callable(self, "_is_enemy_in_player_vision"),
		Callable(),  # Goatman não é repelido por luz — isso é comportamento do Wendigo
		110.0 if is_forest_day else FarmEnemy.MOVE_SPEED,
		140.0 if is_forest_day else FarmEnemy.CHASE_SPEED,
		spotted_immediately
	)


func _on_goatman_player_spotted() -> void:
	if _chase_audio and not _chase_audio.playing:
		_chase_audio.play()
	_anxiety_active = true


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
	_anxiety_active = false
	_anxiety_current = 0.0
	player.set_anxiety_intensity(0.0)
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
	_anxiety_active = false
	_anxiety_current = 0.0
	player.set_anxiety_intensity(0.0)
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
	_warning_plays_remaining = 0
	hostile_audio.stop()
	if _chase_audio and _chase_audio.playing:
		_chase_audio.stop()
	_clear_active_enemy()
	_hostile_trigger_timer = 0.0
	_anxiety_active = false  # fade-out suave via _update_anxiety

	if start_cooldown and (_is_night or _in_forest):
		_hostile_state = HostileEventState.COOLDOWN
		_hostile_state_timer = HOSTILE_COOLDOWN_DURATION
	else:
		_hostile_state = HostileEventState.IDLE
		_hostile_state_timer = 0.0


func _update_anxiety(delta: float) -> void:
	var target_intensity := 0.0
	# Ansiedade ambiente: baixa intensidade constante durante a noite
	if _is_night and not _is_transitioning:
		target_intensity = 0.15
	if _anxiety_active and _hostile_state == HostileEventState.ACTIVE and is_instance_valid(_active_enemy):
		var dist := player.global_position.distance_to(_active_enemy.global_position)
		var chase_intensity: float = 1.0 - clamp(
			(dist - MIN_ANXIETY_DISTANCE) / (MAX_ANXIETY_DISTANCE - MIN_ANXIETY_DISTANCE),
			0.0, 1.0
		)
		target_intensity = maxf(target_intensity, chase_intensity)
	# Wendigo em perseguição também dispara ansiedade baseada em distância
	if _wendigo_state == WendigoState.CHARGING and is_instance_valid(_wendigo_node):
		var dist := player.global_position.distance_to(_wendigo_node.global_position)
		var chase_intensity: float = 1.0 - clamp(
			(dist - MIN_ANXIETY_DISTANCE) / (MAX_ANXIETY_DISTANCE - MIN_ANXIETY_DISTANCE),
			0.0, 1.0
		)
		target_intensity = maxf(target_intensity, chase_intensity)

	var speed := ANXIETY_FADE_IN_SPEED if _anxiety_current < target_intensity else ANXIETY_FADE_OUT_SPEED
	_anxiety_current = move_toward(_anxiety_current, target_intensity, speed * delta)

	if _anxiety_current > 0.001:
		_anxiety_pulse_time += delta
		_anxiety_layer.visible = true
		_anxiety_shader_mat.set_shader_parameter("intensity", _anxiety_current)
		_anxiety_shader_mat.set_shader_parameter("pulse_time", _anxiety_pulse_time)
		_tint_rect.color = Color(0.35, 0.03, 0.03, _anxiety_current * 0.18)
		# Shake da câmera durante perseguição do Goatman ou do Wendigo
		var wendigo_chasing := _wendigo_state == WendigoState.CHARGING and is_instance_valid(_wendigo_node)
		var shake_intensity := _anxiety_current if (_anxiety_active or wendigo_chasing) else 0.0
		player.set_anxiety_intensity(shake_intensity)
	else:
		_anxiety_layer.visible = false
		_anxiety_current = 0.0
		_anxiety_pulse_time = 0.0
		player.set_anxiety_intensity(0.0)


func _clear_active_enemy() -> void:
	if is_instance_valid(_active_enemy):
		_active_enemy.queue_free()
	_active_enemy = null


# ─── Mimic ────────────────────────────────────────────────────────────────────

func _update_mimic(delta: float) -> void:
	if not _is_night:
		return

	match _mimic_state:
		MimicState.INACTIVE:
			_mimic_trigger_timer = max(_mimic_trigger_timer - delta, 0.0)
			if _mimic_trigger_timer <= 0.0:
				_spawn_mimic()

		MimicState.APPROACHING:
			if not is_instance_valid(_mimic_node):
				_mimic_state = MimicState.DONE
				return

			# Foge se o player chegar perto
			if _mimic_node.global_position.distance_to(player.global_position) <= MIMIC_FLEE_RADIUS:
				_hostile_alert_text = "Algo estranho disparou para as sombras."
				_mimic_flee_timer = 3.5
				_mimic_state = MimicState.FLEEING
				return

			# Chegou ao gerador → sabotagem
			var gen_pos := _generator_area.global_position
			if _mimic_node.global_position.distance_to(gen_pos) <= MIMIC_SABOTAGE_RADIUS:
				_generator_active = false
				_generator_sabotaged = true
				_generator_hits = 0
				_hostile_alert_text = "Os refletores apagaram. O Mimic sabotou o gerador!"
				# Garantir aviso completo antes do próximo spawn do Goatman
				if _hostile_state == HostileEventState.IDLE:
					_hostile_trigger_timer = NIGHT_WARNING_DELAY
				_mimic_flee_timer = 4.0
				_mimic_state = MimicState.FLEEING
				return

			var dir := (gen_pos - _mimic_node.global_position).normalized()
			_mimic_node.global_position += dir * MIMIC_SPEED * delta

		MimicState.FLEEING:
			if not is_instance_valid(_mimic_node):
				_mimic_state = MimicState.DONE
				return

			_mimic_flee_timer = max(_mimic_flee_timer - delta, 0.0)
			# Foge na direção oposta ao centro da fazenda
			var farm_center := Vector2(420, 520)
			var flee_dir := (_mimic_node.global_position - farm_center).normalized()
			_mimic_node.global_position += flee_dir * MIMIC_FLEE_SPEED * delta

			if _mimic_flee_timer <= 0.0:
				_clear_mimic()
				_mimic_state = MimicState.DONE

		MimicState.DONE:
			pass


func _spawn_mimic() -> void:
	_mimic_state = MimicState.APPROACHING

	_mimic_node = Node2D.new()
	_mimic_node.name = "Mimic"
	# Spawna no canto direito do mapa, fora dos refletores
	_mimic_node.global_position = Vector2(820, 468)

	# PLACEHOLDER — substituir por AnimatedSprite2D quando asset disponível
	var body := Polygon2D.new()
	body.color = Color(0.14, 0.13, 0.22, 0.92)
	body.polygon = PackedVector2Array([
		Vector2(-7, -9), Vector2(7, -9),
		Vector2(9, 7), Vector2(-9, 7),
	])
	_mimic_node.add_child(body)
	add_child(_mimic_node)


func _clear_mimic() -> void:
	if is_instance_valid(_mimic_node):
		_mimic_node.queue_free()
	_mimic_node = null


# ─── Wendigo ──────────────────────────────────────────────────────────────────

func _cache_wendigo_route() -> void:
	_wendigo_route.clear()
	for child in wendigo_route_markers.get_children():
		if child is Marker2D:
			_wendigo_route.append((child as Marker2D).global_position)
	_wendigo_forest_route.clear()
	for child in wendigo_forest_route_markers.get_children():
		if child is Marker2D:
			_wendigo_forest_route.append((child as Marker2D).global_position)


func _update_wendigo(delta: float) -> void:
	if not _is_night or _wendigo_max_tonight <= 0:
		return
	if _wendigo_appearances_tonight >= _wendigo_max_tonight:
		return

	# Player mudou de contexto (entrou/saiu da floresta) enquanto Wendigo estava ativo
	if _wendigo_state != WendigoState.INACTIVE and _in_forest != _wendigo_in_forest:
		_clear_wendigo()
		_resolve_wendigo_event()
		return

	match _wendigo_state:
		WendigoState.INACTIVE:
			_wendigo_cooldown_timer = max(_wendigo_cooldown_timer - delta, 0.0)
			if _wendigo_cooldown_timer <= 0.0:
				_spawn_wendigo()

		WendigoState.PATROLLING:
			if not is_instance_valid(_wendigo_node):
				_resolve_wendigo_event()
				return

			_wendigo_patrol_timer = max(_wendigo_patrol_timer - delta, 0.0)
			if _wendigo_patrol_timer <= 0.0:
				if _in_forest == _wendigo_in_forest:
					_hostile_alert_text = "O Wendigo voltou para as sombras."
				_clear_wendigo()
				_resolve_wendigo_event()
				return

			# Foge da lanterna durante a ronda
			if _is_position_in_light(_wendigo_node.global_position):
				if _in_forest == _wendigo_in_forest:
					_hostile_alert_text = "A luz afastou o Wendigo."
				_clear_wendigo()
				_resolve_wendigo_event()
				return

			# Inicia perseguição se o player se aproximar
			if _wendigo_node.global_position.distance_to(player.global_position) <= WENDIGO_PATROL_DETECT_RANGE:
				_wendigo_state = WendigoState.CHARGING
				_wendigo_state_timer = WENDIGO_CHARGE_DURATION
				if _in_forest == _wendigo_in_forest:
					_hostile_alert_text = "O Wendigo avancou!"
				return

			# Ronda entre waypoints — usa rota da floresta quando aplicável
			var active_wendigo_route := _wendigo_forest_route if _wendigo_in_forest else _wendigo_route
			if not active_wendigo_route.is_empty():
				var target := active_wendigo_route[_wendigo_patrol_index]
				var dir := (target - _wendigo_node.global_position).normalized()
				_wendigo_node.global_position = _wendigo_node.global_position.move_toward(target, WENDIGO_PATROL_SPEED * delta)
				if _wendigo_node.global_position.distance_to(target) <= 4.0:
					_wendigo_patrol_index = (_wendigo_patrol_index + 1) % active_wendigo_route.size()
				_wendigo_update_sprite_dir(dir)

		WendigoState.CHARGING:
			if not is_instance_valid(_wendigo_node):
				_resolve_wendigo_event()
				return

			# Timer geral de presença continua contando durante a perseguição
			_wendigo_patrol_timer = max(_wendigo_patrol_timer - delta, 0.0)
			if _wendigo_patrol_timer <= 0.0:
				if _in_forest == _wendigo_in_forest:
					_hostile_alert_text = "O Wendigo voltou para as sombras."
				_clear_wendigo()
				_resolve_wendigo_event()
				return

			var wpos := _wendigo_node.global_position

			# Luz repele — único jeito de despawnar antes dos 60s
			if _is_position_in_light(wpos):
				if _in_forest == _wendigo_in_forest:
					_hostile_alert_text = "A luz afastou o Wendigo."
				_clear_wendigo()
				_resolve_wendigo_event()
				return

			# Alcançou o player
			if wpos.distance_to(player.global_position) <= 38.0:
				_clear_wendigo()
				_resolve_wendigo_event()
				_start_player_expulsion()
				return

			# Chase timer esgotado — volta a rondar
			_wendigo_state_timer = max(_wendigo_state_timer - delta, 0.0)
			if _wendigo_state_timer <= 0.0:
				if _in_forest == _wendigo_in_forest:
					_hostile_alert_text = "Algo ronda as sombras ao sul..."
				_wendigo_state = WendigoState.PATROLLING
				return

			var dir := (player.global_position - wpos).normalized()
			_wendigo_node.global_position += dir * WENDIGO_CHARGE_SPEED * delta
			_wendigo_update_sprite_dir(dir)


func _wendigo_update_sprite_dir(dir: Vector2) -> void:
	if not is_instance_valid(_wendigo_sprite):
		return
	var anim: StringName
	if absf(dir.x) >= absf(dir.y):
		anim = &"run_east" if dir.x >= 0.0 else &"run_west"
	else:
		anim = &"run_south" if dir.y >= 0.0 else &"run_north"
	if _wendigo_sprite.animation != anim:
		_wendigo_sprite.play(anim)


func _spawn_wendigo() -> void:
	_wendigo_state = WendigoState.PATROLLING
	_wendigo_patrol_timer = WENDIGO_PATROL_DURATION
	_wendigo_patrol_index = 0
	_wendigo_in_forest = _in_forest
	# Alerta só aparece se o player estiver no mesmo contexto do Wendigo
	if _in_forest == _wendigo_in_forest:
		_hostile_alert_text = "Algo ronda as sombras ao sul..."

	_wendigo_node = Node2D.new()
	_wendigo_node.name = "Wendigo"
	_wendigo_node.global_position = (wendigo_forest_spawn if _in_forest else wendigo_spawn).global_position

	var wframes := SpriteFrames.new()
	wframes.remove_animation(&"default")
	var wdir_frames: Dictionary = {
		&"run_south": [
			"res://assets/Characters/Wendigo/animations/running-8-frames/south/frame_000.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/south/frame_001.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/south/frame_002.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/south/frame_003.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/south/frame_004.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/south/frame_005.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/south/frame_006.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/south/frame_007.png",
		],
		&"run_north": [
			"res://assets/Characters/Wendigo/animations/running-8-frames/north/frame_000.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/north/frame_001.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/north/frame_002.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/north/frame_003.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/north/frame_004.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/north/frame_005.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/north/frame_006.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/north/frame_007.png",
		],
		&"run_east": [
			"res://assets/Characters/Wendigo/animations/running-8-frames/east/frame_000.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/east/frame_001.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/east/frame_002.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/east/frame_003.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/east/frame_004.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/east/frame_005.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/east/frame_006.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/east/frame_007.png",
		],
		&"run_west": [
			"res://assets/Characters/Wendigo/animations/running-8-frames/west/frame_000.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/west/frame_001.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/west/frame_002.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/west/frame_003.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/west/frame_004.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/west/frame_005.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/west/frame_006.png",
			"res://assets/Characters/Wendigo/animations/running-8-frames/west/frame_007.png",
		],
	}
	for anim_name: StringName in wdir_frames:
		wframes.add_animation(anim_name)
		wframes.set_animation_loop(anim_name, true)
		wframes.set_animation_speed(anim_name, 10.0)
		for path: String in wdir_frames[anim_name]:
			var tex := load(path) as Texture2D
			if tex != null:
				wframes.add_frame(anim_name, tex)

	_wendigo_sprite = AnimatedSprite2D.new()
	_wendigo_sprite.sprite_frames = wframes
	_wendigo_sprite.play(&"run_south")
	_wendigo_node.add_child(_wendigo_sprite)
	add_child(_wendigo_node)


func _resolve_wendigo_event() -> void:
	_wendigo_appearances_tonight += 1
	_wendigo_state = WendigoState.INACTIVE
	_wendigo_state_timer = 0.0
	_wendigo_cooldown_timer = randf_range(WENDIGO_COOLDOWN_MIN, WENDIGO_COOLDOWN_MAX)


func _clear_wendigo() -> void:
	if is_instance_valid(_wendigo_node):
		_wendigo_node.queue_free()
	_wendigo_node = null
	_wendigo_sprite = null


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
	if _generator_active and _generator_fuel > 0.0:
		for reflector_position in _reflector_positions:
			if world_position.distance_to(reflector_position) <= REFLECTOR_RADIUS:
				return true

	if _flashlight_active:
		var to_pos := world_position - player.global_position
		var dist := to_pos.length()
		if dist <= FLASHLIGHT_RANGE:
			var facing := player.get_facing_direction()
			if dist < 1.0 or to_pos.normalized().dot(facing) >= FLASHLIGHT_CONE_DOT:
				return true

	return false


## Verifica apenas os refletores do gerador (sem lanterna).
## Usado pelo Goatman — quem foge da lanterna é o Wendigo.
func _is_position_in_reflector_light(world_position: Vector2) -> bool:
	if _generator_active and _generator_fuel > 0.0:
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

	if _darkwatcher_phase == DarkwatcherPhase.IN_DIALOGUE:
		_active_interaction = {"type": "darkwatcher", "distance": 0.0, "plot_index": -1}
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

	if _darkwatcher_area != null and _darkwatcher_phase in [DarkwatcherPhase.AWAIT_APPROACH, DarkwatcherPhase.DONE]:
		var dw_interaction := _consider_interaction(best_interaction, best_distance, "darkwatcher", _darkwatcher_area.global_position)
		if not dw_interaction.is_empty():
			best_interaction = dw_interaction
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
		var wood_node := _wood_sources[wood_index]["node"] as Node2D
		var wood_interaction := _consider_interaction(best_interaction, best_distance, "wood_source", wood_node.global_position, wood_index)
		if not wood_interaction.is_empty():
			best_interaction = wood_interaction
			best_distance = best_interaction["distance"]

	for plot_index in range(_plots.size()):
		var plot_area := _plots[plot_index]["area"] as Area2D
		var plot_interaction := _consider_interaction(best_interaction, best_distance, "plot", plot_area.global_position, plot_index)
		if not plot_interaction.is_empty():
			best_interaction = plot_interaction
			best_distance = best_interaction["distance"]

	if _near_outside_door:
		var door_interaction := _consider_interaction(best_interaction, best_distance, "door_enter", outside_door.global_position)
		if not door_interaction.is_empty():
			best_interaction = door_interaction
			best_distance = door_interaction["distance"]

	if _near_inside_door:
		var door_exit_interaction := _consider_interaction(best_interaction, best_distance, "door_exit", inside_door.global_position)
		if not door_exit_interaction.is_empty():
			best_interaction = door_exit_interaction

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
		"darkwatcher":
			return "F para falar com o %s" % DARKWATCHER_NAME
		"sell_box":
			var crop_count := _get_item_count(ITEM_CROP)
			if crop_count > 0:
				return "F para vender %d colheitas" % crop_count
		"vendor":
			if _coins >= VENDOR_SEED_BUNDLE_COST:
				return "F para comprar %d sementes (%d moedas)" % [VENDOR_SEED_BUNDLE_AMOUNT, VENDOR_SEED_BUNDLE_COST]
			return "Vendedor: %d sementes custam %d moedas" % [VENDOR_SEED_BUNDLE_AMOUNT, VENDOR_SEED_BUNDLE_COST]
		"generator":
			if _generator_sabotaged:
				return "F para reparar gerador (%d/%d)" % [_generator_hits, TREE_HITS_TO_FALL]
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
		"door_enter":
			return "F para entrar na cabana"
		"door_exit":
			return "F para sair"
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
			pass  # AnimatedSprite2D — sem highlight de polígono
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
		"darkwatcher":
			pass # AnimatedSprite2D — sem highlight de polígono
		"wood_source":
			pass # Sprite2D não usa highlight de polígono
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
		"darkwatcher":
			_interact_with_darkwatcher()
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
		"door_enter":
			_start_room_transition(inside_spawn.global_position)
		"door_exit":
			_start_room_transition(outside_spawn.global_position)

	_update_active_interaction()
	_refresh_ui()


func _interact_with_generator() -> void:
	# Reparo após sabotagem — 4 pressionamentos de F com custo de stamina, sem madeira
	if _generator_sabotaged:
		var stamina_cost := PlayerController.MAX_STAMINA / 8.0
		if not player.drain_stamina(stamina_cost):
			return
		_generator_hits += 1
		if _generator_hits < TREE_HITS_TO_FALL:
			_hostile_alert_text = "Reparando gerador... %d/%d" % [_generator_hits, TREE_HITS_TO_FALL]
			_generator_alert_timer = 2.0
			return
		_generator_hits = 0
		_generator_sabotaged = false
		_hostile_alert_text = "Gerador reparado! Pressione F para religar os refletores."
		_generator_alert_timer = 3.0
		return

	var wood_count := _get_item_count(ITEM_WOOD)
	if _get_selected_item_id() == ITEM_WOOD and wood_count > 0:
		_remove_item(ITEM_WOOD, wood_count)
		_generator_fuel += GENERATOR_FUEL_PER_WOOD * wood_count
		_generator_active = true
		var nights := _generator_fuel / NIGHT_DURATION
		_hostile_alert_text = "%d madeiras depositadas (~%.1f noites). Refletores ativos." % [wood_count, nights]
		_generator_alert_timer = 5.0
		_refresh_generator_visuals()
		return

	if _generator_fuel <= 0.0:
		return

	_generator_active = not _generator_active
	if _generator_active:
		_hostile_alert_text = "Refletores ligados."
		_generator_alert_timer = 5.0
	else:
		_hostile_alert_text = "Refletores desligados."
		_generator_alert_timer = 3.0
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
	_hostile_alert_text = "Inventario cheio! Abra [E] e libere espaco."


func _shake_tree_visual(visual: Sprite2D) -> void:
	var origin := visual.position
	var tween := create_tween()
	tween.tween_property(visual, "position", origin + Vector2(5, 0), 0.05)
	tween.tween_property(visual, "position", origin + Vector2(-5, 0), 0.05)
	tween.tween_property(visual, "position", origin + Vector2(3, 0), 0.04)
	tween.tween_property(visual, "position", origin, 0.04)


func _fell_tree_visual(visual: Sprite2D) -> void:
	# Pivot na base do sprite: visual.position.y (-8) + metade do sprite (24) = 16
	var tree_root := visual.get_parent() as Node2D
	var original_pos := visual.position

	var pivot := Node2D.new()
	pivot.position = Vector2(0.0, 16.0)
	tree_root.add_child(pivot)

	visual.reparent(pivot, false)
	visual.position = original_pos - pivot.position  # (0, -24)

	var tween := create_tween()
	tween.tween_property(pivot, "rotation", deg_to_rad(90.0), 0.5)
	tween.parallel().tween_property(visual, "modulate:a", 0.0, 0.65)
	tween.tween_callback(func() -> void:
		visual.reparent(tree_root, false)
		visual.position = original_pos
		visual.rotation = 0.0
		visual.visible = false
		pivot.queue_free()
	)


func _harvest_wood_source(source_index: int) -> void:
	var source := _wood_sources[source_index]
	if not bool(source["available"]):
		return
	if _get_selected_item_id() != ITEM_AXE:
		return
	if player.is_attack_on_cooldown():
		return
	var stamina_cost := PlayerController.MAX_STAMINA / 8.0
	if not player.drain_stamina(stamina_cost):
		return
	player.play_axe_swing(player.get_facing_direction())

	source["hits"] = int(source["hits"]) + 1
	var visual := source["visual"] as Sprite2D
	if int(source["hits"]) < TREE_HITS_TO_FALL:
		player.axe_impact.connect(func() -> void: _shake_tree_visual(visual), CONNECT_ONE_SHOT)
		return

	if not _add_item(ITEM_WOOD, "Lenha", WOOD_PER_CHOP):
		source["hits"] = int(source["hits"]) - 1
		return

	source["available"] = false
	source["respawn_timer"] = TREE_RESPAWN_DURATION
	source["hits"] = 0
	var body := source["body"] as StaticBody2D
	if body != null:
		body.collision_layer = 0
		body.collision_mask = 0
	player.axe_impact.connect(func() -> void: _fell_tree_visual(visual), CONNECT_ONE_SHOT)


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
		ITEM_LANTERN:
			if not _flashlight_active and _lantern_battery <= 0.0:
				pass  # bateria descarregada — não liga
			else:
				_flashlight_active = not _flashlight_active
				player.set_flashlight_on(_flashlight_active)


func _refresh_ui() -> void:
	day_label.text = "Dia %d" % _day_number
	phase_label.text = "%s  %s" % [("Noite" if _is_night else "Dia"), _get_time_string()]
	coins_label.text = "Moedas: %d" % _coins
	var lantern_suffix := ""
	if _get_selected_item_id() == ITEM_LANTERN:
		var bat_pct := int(_lantern_battery / LANTERN_BATTERY_MAX * 100.0)
		var state_str := "LIGADA" if _flashlight_active else ("SEM BATERIA" if _lantern_battery <= 0.0 else "DESLIGADA")
		lantern_suffix = "  [%s | Bat: %d%%]" % [state_str, bat_pct]
	inventory_label.text = "Equipado: %s%s | Q usa item | %s" % [_get_selected_slot_label(), lantern_suffix, _get_seed_stock_text()]
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
	if _hunger_bar_fill != null:
		_hunger_bar_fill.size.x = clampf(_hunger / HUNGER_MAX, 0.0, 1.0) * 128.0
		_hunger_bar_fill.modulate = Color(1.0, 0.596078, 0.596078, 1) if _hunger < 40.0 else Color.WHITE
	if _thirst_bar_fill != null:
		_thirst_bar_fill.size.x = clampf(_thirst / THIRST_MAX, 0.0, 1.0) * 128.0
		_thirst_bar_fill.modulate = Color(1.0, 0.596078, 0.596078, 1) if _thirst < 25.0 else Color.WHITE

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

	if _generator_sprite != null:
		_generator_sprite.modulate = Color(1.15, 1.05, 0.75) if _generator_active else Color(1, 1, 1)
	_generator_glow.color = Color(1.0, 0.878431, 0.431373, 0.28) if _generator_active else Color(1.0, 0.878431, 0.431373, 0.0)

	for cone in _reflector_visuals:
		cone.color = Color(0.980392, 0.901961, 0.596078, 0.38) if _generator_active else Color(0.980392, 0.901961, 0.596078, 0.0)

	if _night_shader_mat != null:
		_night_shader_mat.set_shader_parameter(&"light_on", 1.0 if (_generator_active and _is_night) else 0.0)
		_night_shader_mat.set_shader_parameter(&"light_on_2", 1.0 if (_flashlight_active and _is_night) else 0.0)


func _update_reflector_light_shader() -> void:
	if _night_shader_mat == null:
		return
	var ct := get_viewport().get_canvas_transform()
	var vp_size := get_viewport().get_visible_rect().size
	var p0 := Vector2(-1.0, -1.0)
	var p1 := Vector2(-1.0, -1.0)
	var p2 := Vector2(-1.0, -1.0)
	if _generator_active and _is_night:
		if _reflector_positions.size() > 0:
			p0 = ct * _reflector_positions[0] / vp_size
		if _reflector_positions.size() > 1:
			p1 = ct * _reflector_positions[1] / vp_size
	if _flashlight_active and _is_night:
		p2 = ct * player.global_position / vp_size
	_night_shader_mat.set_shader_parameter(&"ref_pos_0", p0)
	_night_shader_mat.set_shader_parameter(&"ref_pos_1", p1)
	_night_shader_mat.set_shader_parameter(&"ref_pos_2", p2)


func _get_seed_stock_text() -> String:
	if _free_seed_claim_available:
		return "Bolsa inicial: %d sementes" % INITIAL_SEED_AMOUNT
	return "Vendedor: %d sementes por %d moedas" % [VENDOR_SEED_BUNDLE_AMOUNT, VENDOR_SEED_BUNDLE_COST]


func _refresh_stamina_ui() -> void:
	var ratio := player.get_stamina_ratio()
	var stamina_color := Color(0.537255, 0.886275, 0.988235, 1)
	if player.is_exhausted():
		stamina_color = Color(0.901961, 0.478431, 0.478431, 1)
		stamina_status.text = "CD"
	elif player.is_sprinting():
		stamina_color = Color(0.988235, 0.760784, 0.352941, 1)
		stamina_status.text = "RUN"
	elif player.is_stamina_on_cooldown():
		stamina_color = Color(0.682353, 0.866667, 0.941176, 1)
		stamina_status.text = "REC"
	else:
		stamina_status.text = "STA"

	if _stamina_bar_clip != null:
		_stamina_bar_clip.size.x = clampf(ratio, 0.0, 1.0) * 150.0
	if _stamina_bar_tile != null:
		_stamina_bar_tile.modulate = stamina_color


func _on_outside_door_body_entered(body: Node) -> void:
	if body == player:
		_near_outside_door = true


func _on_outside_door_body_exited(body: Node) -> void:
	if body == player:
		_near_outside_door = false


func _on_inside_door_body_entered(body: Node) -> void:
	if body == player:
		_near_inside_door = true


func _on_inside_door_body_exited(body: Node) -> void:
	if body == player:
		_near_inside_door = false


func _on_forest_entrance_body_entered(body: Node) -> void:
	if body == player:
		_enter_forest()


func _enter_forest() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_teleport_cooldown = 1.5
	player.set_movement_locked(true)
	player.snap_camera_for_room_transition()
	_update_prompt("")
	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "color:a", 1.0, 0.3)
	fade_in.finished.connect(func() -> void:
		player.global_position = forest_spawn.global_position
		var fade_out := create_tween()
		fade_out.tween_interval(0.15)
		fade_out.tween_property(fade_rect, "color:a", 0.0, 0.3)
		fade_out.finished.connect(func() -> void:
			player.restore_camera_after_room_transition()
			player.set_movement_locked(false)
			_stop_hostile_event(false)
			_in_forest = true
			_hostile_state = HostileEventState.IDLE
			_hostile_trigger_timer = FOREST_DAY_WARNING_DELAY if not _is_night else NIGHT_WARNING_DELAY
			_is_transitioning = false
		)
	)


func _on_forest_exit_body_entered(body: Node) -> void:
	if body == player:
		_exit_forest()


func _exit_forest() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_teleport_cooldown = 1.5
	player.set_movement_locked(true)
	player.snap_camera_for_room_transition()
	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "color:a", 1.0, 0.3)
	fade_in.finished.connect(func() -> void:
		player.global_position = forest_return.global_position
		var fade_out := create_tween()
		fade_out.tween_interval(0.15)
		fade_out.tween_property(fade_rect, "color:a", 0.0, 0.3)
		fade_out.finished.connect(func() -> void:
			player.restore_camera_after_room_transition()
			player.set_movement_locked(false)
			_in_forest = false
			_stop_hostile_event(false)
			if _is_night:
				_hostile_trigger_timer = NIGHT_WARNING_DELAY  # janela de graça ao voltar para a fazenda
			_is_transitioning = false
		)
	)


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
	_build_hotbar_visuals()


func _setup_inventory() -> void:
	_item_icon_map = {
		ITEM_BUCKET:  TEX_ICON_BUCKET,
		ITEM_AXE:     TEX_ICON_AXE,
		ITEM_SEEDS:   TEX_ICON_SEEDS,
		ITEM_CROP:    TEX_ICON_SEEDS,
		ITEM_BREAD:   TEX_ICON_BREAD,
		ITEM_LANTERN: TEX_ICON_FLASHLIGHT,
	}
	_inventory_data = InventoryData.new()
	_inventory_ui   = InventoryUI.new(_inventory_data, _item_icon_map)
	add_child(_inventory_ui)
	# Passa referência direta ao _hotbar para edição em tempo real
	_inventory_ui.set_hotbar(_hotbar)
	_inventory_ui.closed.connect(_on_inventory_closed)

	var _dw_items := [
		{"id": ITEM_LANTERN, "name": "Lanterna",       "short": "Lnt", "price": 200, "icon": TEX_ICON_FLASHLIGHT},
		{"id": "bateria",    "name": "Recarga Bateria", "short": "Bat", "price": 100, "icon": null},
	]
	_darkwatcher_shop_ui = DarkwatcherShopUIScript.new(
		func() -> int: return _coins,
		_try_buy_from_darkwatcher,
		_can_buy_from_darkwatcher,
		_dw_items,
	)
	add_child(_darkwatcher_shop_ui)
	_darkwatcher_shop_ui.closed.connect(_on_darkwatcher_shop_closed)


func _toggle_inventory() -> void:
	if _inventory_ui.visible:
		_inventory_ui.cancel_drag()
		_inventory_ui.hide()
		player.set_movement_locked(false)
	else:
		_inventory_ui.open(_inventory_data, _selected_hotbar_index)
		player.set_movement_locked(true)


func _on_inventory_closed() -> void:
	player.set_movement_locked(false)


func _open_darkwatcher_shop() -> void:
	if _darkwatcher_shop_ui == null or _darkwatcher_shop_ui.visible:
		return
	if _inventory_ui != null and _inventory_ui.visible:
		return
	player.set_movement_locked(true)
	_darkwatcher_shop_ui.open()


func _on_darkwatcher_shop_closed() -> void:
	player.set_movement_locked(false)


func _can_buy_from_darkwatcher(item_id: String) -> bool:
	match item_id:
		ITEM_LANTERN:
			return not _lantern_bought
		"bateria":
			return _lantern_bought and not _battery_recharged_today
	return false


func _try_buy_from_darkwatcher(item_id: String, price: int) -> bool:
	if _coins < price:
		return false
	match item_id:
		ITEM_LANTERN:
			if _lantern_bought:
				return false
			_coins -= price
			_add_item(ITEM_LANTERN, "Lanterna", 1)
			_lantern_bought = true
		"bateria":
			if not _lantern_bought or _battery_recharged_today:
				return false
			_coins -= price
			_lantern_battery = LANTERN_BATTERY_MAX
			_battery_recharged_today = true
		_:
			return false
	return true


func _build_hotbar_visuals() -> void:
	if hotbar_slots.size() > 0:
		var hotbar_panel := hotbar_slots[0].get_parent() as Panel
		if hotbar_panel != null:
			hotbar_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	const SLOT_SIZE := 56
	const SLOT_GAP := 8
	var hotbar_panel := hotbar_slots[0].get_parent() as Control
	var panel_height: float = hotbar_panel.size.y if hotbar_panel != null else 64.0
	var panel_width: float = hotbar_panel.size.x if hotbar_panel != null else 516.0
	var total_w: float = hotbar_slots.size() * SLOT_SIZE + (hotbar_slots.size() - 1) * SLOT_GAP
	var start_x: float = (panel_width - total_w) / 2.0

	for index in range(hotbar_slots.size()):
		var slot_panel: Panel = hotbar_slots[index]

		slot_panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot_panel.position = Vector2(start_x + index * (SLOT_SIZE + SLOT_GAP), (panel_height - SLOT_SIZE) / 2.0)

		var icon_label: Label = slot_panel.get_node("Icon")
		icon_label.visible = false

		slot_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

		var slot_bg := TextureRect.new()
		slot_bg.name = "SlotBg"
		slot_bg.texture = TEX_HOTBAR_NOT_SELECTED
		slot_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot_panel.add_child(slot_bg)
		slot_panel.move_child(slot_bg, 0)

		var item_icon := TextureRect.new()
		item_icon.name = "ItemIcon"
		item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		item_icon.offset_left = 6
		item_icon.offset_top = 6
		item_icon.offset_right = -6
		item_icon.offset_bottom = -6
		slot_panel.add_child(item_icon)
		slot_panel.move_child(item_icon, 1)

		var count_label: Label = slot_panel.get_node("Count")
		count_label.position = Vector2(28, 38)
		count_label.size = Vector2(24, 14)
		slot_panel.move_child(count_label, slot_panel.get_child_count() - 1)


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
	if _find_slot_index(item_id) >= 0:
		return true
	return _inventory_data != null and _inventory_data.get_item_count(item_id) > 0


func _get_item_count(item_id: String) -> int:
	var slot_index := _find_slot_index(item_id)
	var hotbar_count := int(_hotbar[slot_index]["count"]) if slot_index >= 0 else 0
	var inv_count    := _inventory_data.get_item_count(item_id) if _inventory_data != null else 0
	return hotbar_count + inv_count


func _add_item(item_id: String, label: String, amount: int) -> bool:
	# Tenta empilhar na hotbar primeiro
	var slot_index := _find_slot_index(item_id)
	if slot_index >= 0:
		_hotbar[slot_index]["count"] = int(_hotbar[slot_index]["count"]) + amount
		return true

	# Ocupa slot vazio na hotbar
	for index in range(_hotbar.size()):
		if _hotbar[index]["id"] == "":
			_hotbar[index] = {"id": item_id, "label": label, "count": amount}
			return true

	# Hotbar cheia — transborda para o inventário
	if _inventory_data != null:
		var leftover := _inventory_data.add_item(item_id, label, amount)
		return leftover == 0

	return false


func _remove_item(item_id: String, amount: int) -> bool:
	if _get_item_count(item_id) < amount:
		return false

	var remaining := amount

	# Remove da hotbar primeiro
	var slot_index := _find_slot_index(item_id)
	if slot_index >= 0:
		var hotbar_count := int(_hotbar[slot_index]["count"])
		var take := mini(remaining, hotbar_count)
		_hotbar[slot_index]["count"] = hotbar_count - take
		remaining -= take
		var new_count := int(_hotbar[slot_index]["count"])
		if new_count <= 0 and item_id != ITEM_BUCKET and item_id != ITEM_AXE:
			_hotbar[slot_index] = {"id": "", "label": "Vazio", "count": 0}
		elif item_id == ITEM_BUCKET and new_count <= 0:
			_hotbar[slot_index]["count"] = 0

	# Remove o restante do inventário
	if remaining > 0 and _inventory_data != null:
		_inventory_data.remove_item(item_id, remaining)

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
		var slot_bg: TextureRect = slot_panel.get_node_or_null("SlotBg")
		var item_icon: TextureRect = slot_panel.get_node_or_null("ItemIcon")
		var count_label: Label = slot_panel.get_node("Count")
		var slot: Dictionary = _hotbar[index]
		var is_selected := index == _selected_hotbar_index

		if slot_bg != null:
			slot_bg.texture = TEX_HOTBAR_SELECTED if is_selected else TEX_HOTBAR_NOT_SELECTED
		if item_icon != null:
			item_icon.texture = _get_item_icon_texture(str(slot["id"]))

		count_label.text = _get_slot_count_text(slot)


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
		ITEM_LANTERN:
			return "LT"
		_:
			return "--"


func _get_item_icon_texture(item_id: String) -> Texture2D:
	match item_id:
		ITEM_BUCKET:
			return TEX_ICON_BUCKET
		ITEM_AXE:
			return TEX_ICON_AXE
		ITEM_SEEDS, ITEM_CROP:
			return TEX_ICON_SEEDS
		ITEM_BREAD:
			return TEX_ICON_BREAD
		ITEM_LANTERN:
			return TEX_ICON_FLASHLIGHT
		_:
			return null


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


func _create_anxiety_overlay() -> void:
	_anxiety_layer = CanvasLayer.new()
	_anxiety_layer.layer = 2  # acima da NightRect (layer 1), abaixo da HUD (layer 10)
	add_child(_anxiety_layer)

	_tint_rect = ColorRect.new()
	_tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint_rect.color = Color(0.35, 0.03, 0.03, 0.0)
	_tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anxiety_layer.add_child(_tint_rect)

	var shader_code := """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_time : hint_range(0.0, 100.0) = 0.0;
void fragment() {
    vec2 uv = (UV - vec2(0.5)) * 2.0;
    uv.x *= 1.777;
    float dist = length(uv);
    float pulse = sin(pulse_time * 6.2831) * 0.04 * intensity;
    float radius = mix(0.92, 0.60, intensity) + pulse;
    float softness = mix(0.45, 0.16, intensity);
    float vignette = smoothstep(radius, radius - softness, dist);
    float darkness = (1.0 - vignette) * mix(0.55, 0.90, intensity);
    COLOR = vec4(0.0, 0.0, 0.0, darkness * intensity);
}
"""
	var shader := Shader.new()
	shader.code = shader_code
	_anxiety_shader_mat = ShaderMaterial.new()
	_anxiety_shader_mat.shader = shader

	_vignette_rect = ColorRect.new()
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.color = Color.WHITE
	_vignette_rect.material = _anxiety_shader_mat
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anxiety_layer.add_child(_vignette_rect)

	_anxiety_layer.visible = false


func _make_shadow(width: float, height: float, y_offset: float) -> Polygon2D:
	var shadow := Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.38)
	shadow.position = Vector2(0.0, y_offset)
	var pts := PackedVector2Array()
	for i: int in 12:
		var angle := i * TAU / 12.0
		pts.append(Vector2(cos(angle) * width, sin(angle) * height))
	shadow.polygon = pts
	return shadow


func _create_tutorial_npc() -> void:
	_tutorial_npc_body = Node2D.new()
	_tutorial_npc_body.name = "TutorialNPC"
	_tutorial_npc_body.position = outside_spawn.global_position + Vector2(80, -36)
	add_child(_tutorial_npc_body)

	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var dir_map: Dictionary = {
		&"idle_south": "res://assets/Characters/old man consequences/rotations/south.png",
		&"idle_north": "res://assets/Characters/old man consequences/rotations/north.png",
		&"idle_east":  "res://assets/Characters/old man consequences/rotations/east.png",
		&"idle_west":  "res://assets/Characters/old man consequences/rotations/west.png",
	}
	for anim_name: StringName in dir_map:
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, true)
		frames.set_animation_speed(anim_name, 5.0)
		frames.add_frame(anim_name, load(dir_map[anim_name]))

	var npc_shadow := _make_shadow(7.0, 2.5, 14.0)
	_tutorial_npc_body.add_child(npc_shadow)

	_tutorial_npc_sprite = AnimatedSprite2D.new()
	_tutorial_npc_sprite.sprite_frames = frames
	_tutorial_npc_sprite.animation = &"idle_south"
	_tutorial_npc_sprite.scale = Vector2(1, 1)
	_tutorial_npc_body.add_child(_tutorial_npc_sprite)

	_tutorial_npc_area = Area2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 44.0
	col.shape = shape
	_tutorial_npc_area.add_child(col)
	_tutorial_npc_body.add_child(_tutorial_npc_area)



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
				_warning_plays_remaining = 0
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
	if is_instance_valid(_tutorial_npc_sprite):
		_tutorial_npc_sprite.modulate = Color(1.0, 0.12, 0.12, alpha)

	if _tutorial_night_timer <= 0.0:
		_tutorial_phase = TutorialPhase.DEAD
		_first_night_done = true
		_tutorial_npc_body.queue_free()
		_tutorial_npc_body = null
		_hostile_state = HostileEventState.IDLE
		_hostile_trigger_timer = NIGHT_WARNING_DELAY


## Pula toda a sequência do NPC tutorial (Tab de debug).
## Ativa o gerador como ocorreria no fluxo normal e mata o NPC imediatamente.
func _skip_tutorial_npc() -> void:
	if _tutorial_phase == TutorialPhase.DEAD:
		return
	_close_tutorial_dialogue()
	_warning_plays_remaining = 0
	hostile_audio.stop()
	# Garante que o gerador fica ligado (o NPC o ligaria na fase NIGHT_RUN_GENERATOR)
	if not _generator_active:
		_generator_fuel = GENERATOR_WOOD_PER_NIGHT * GENERATOR_FUEL_PER_WOOD
		_generator_active = true
		_refresh_generator_visuals()
	_tutorial_phase = TutorialPhase.DEAD
	_first_night_done = true
	if is_instance_valid(_tutorial_npc_body):
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
	_show_npc_dialogue(TUTORIAL_NPC_NAME, text)


func _show_npc_dialogue(speaker_name: String, text: String) -> void:
	_tutorial_dialogue_panel.visible = true
	_tutorial_dialogue_name_label.text = speaker_name
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
		ITEM_LANTERN:
			return Color(0.98, 0.92, 0.60, 1) if _flashlight_active else Color(0.55, 0.52, 0.35, 1)
		_:
			return Color(0.4, 0.4, 0.4, 1)


# ── Darkwatcher ──────────────────────────────────────────────────────────────

func _spawn_darkwatcher() -> void:
	_darkwatcher_body = Node2D.new()
	_darkwatcher_body.name = "Darkwatcher"
	_darkwatcher_body.position = outside_spawn.global_position + Vector2(-100, -48)
	add_child(_darkwatcher_body)

	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	var dir_files: Dictionary = {
		"south":      "res://assets/Characters/darkwatcher/rotations/south.png",
		"south-east": "res://assets/Characters/darkwatcher/rotations/south-east.png",
		"east":       "res://assets/Characters/darkwatcher/rotations/east.png",
		"north-east": "res://assets/Characters/darkwatcher/rotations/north-east.png",
		"north":      "res://assets/Characters/darkwatcher/rotations/north.png",
		"north-west": "res://assets/Characters/darkwatcher/rotations/north-west.png",
		"west":       "res://assets/Characters/darkwatcher/rotations/west.png",
		"south-west": "res://assets/Characters/darkwatcher/rotations/south-west.png",
	}

	for anim_name: String in dir_files.keys():
		frames.add_animation(anim_name)
		frames.set_animation_loop(anim_name, false)
		var tex := load(dir_files[anim_name]) as Texture2D
		if tex != null:
			frames.add_frame(anim_name, tex)

	var dw_shadow := _make_shadow(7.0, 2.5, 14.0)
	_darkwatcher_body.add_child(dw_shadow)

	_darkwatcher_sprite = AnimatedSprite2D.new()
	_darkwatcher_sprite.sprite_frames = frames
	_darkwatcher_sprite.play("south")
	_darkwatcher_body.add_child(_darkwatcher_sprite)

	_darkwatcher_area = Area2D.new()
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 44.0
	col.shape = shape
	_darkwatcher_area.add_child(col)
	_darkwatcher_body.add_child(_darkwatcher_area)

	_darkwatcher_phase = DarkwatcherPhase.AWAIT_APPROACH


func _update_darkwatcher_npc(_delta: float) -> void:
	if _darkwatcher_phase == DarkwatcherPhase.INACTIVE:
		return
	if not is_instance_valid(_darkwatcher_body):
		return

	_update_darkwatcher_facing()

	if _darkwatcher_phase == DarkwatcherPhase.AWAIT_APPROACH:
		if player.global_position.distance_to(_darkwatcher_body.global_position) < 72.0:
			_begin_darkwatcher_dialogue()


func _update_darkwatcher_facing() -> void:
	if not is_instance_valid(_darkwatcher_sprite):
		return
	var dir := _darkwatcher_body.global_position.direction_to(player.global_position)
	_darkwatcher_sprite.play(_dir8_from_angle(atan2(dir.y, dir.x)))


func _dir8_from_angle(angle_rad: float) -> String:
	var deg := fmod(rad_to_deg(angle_rad) + 360.0, 360.0)
	if deg < 22.5 or deg >= 337.5:
		return "east"
	elif deg < 67.5:
		return "south-east"
	elif deg < 112.5:
		return "south"
	elif deg < 157.5:
		return "south-west"
	elif deg < 202.5:
		return "west"
	elif deg < 247.5:
		return "north-west"
	elif deg < 292.5:
		return "north"
	else:
		return "north-east"


func _begin_darkwatcher_dialogue() -> void:
	_darkwatcher_phase = DarkwatcherPhase.IN_DIALOGUE
	_darkwatcher_dialogue_index = 0
	_show_npc_dialogue(DARKWATCHER_NAME, DARKWATCHER_LINES[0])
	var hint := _tutorial_dialogue_panel.get_node_or_null("ContinueHint") as Label
	if hint != null:
		hint.visible = true


func _advance_darkwatcher_dialogue() -> void:
	_darkwatcher_dialogue_index += 1
	if _darkwatcher_dialogue_index >= DARKWATCHER_LINES.size():
		_darkwatcher_phase = DarkwatcherPhase.DONE
		_close_tutorial_dialogue()
		_open_darkwatcher_shop()
		return
	_show_npc_dialogue(DARKWATCHER_NAME, DARKWATCHER_LINES[_darkwatcher_dialogue_index])


func _interact_with_darkwatcher() -> void:
	if _darkwatcher_phase == DarkwatcherPhase.IN_DIALOGUE:
		_advance_darkwatcher_dialogue()
	elif _darkwatcher_phase == DarkwatcherPhase.DONE:
		_open_darkwatcher_shop()
