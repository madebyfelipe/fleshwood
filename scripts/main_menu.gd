extends Control

@onready var background: TextureRect = $Background
@onready var logo: TextureRect = $Logo
@onready var menu_container: VBoxContainer = $MenuContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var music: AudioStreamPlayer = $Music

const WORLD_SCENE := "res://scenes/world.tscn"
const OPTIONS_SCENE := "res://scenes/options_menu.tscn"

# Parallax: background (longe) se desloca mais; logo (próximo) se desloca menos
const BG_PARALLAX_OFFSET := 280.0
const LOGO_PARALLAX_OFFSET := 110.0

func _ready() -> void:
	# Texturas e layout definidos no .tscn — não sobrescrever aqui
	background.modulate.a = 0.0
	logo.modulate.a = 0.0
	menu_container.modulate.a = 0.0
	# Desloca para baixo antes da animação de entrada
	background.position.y += BG_PARALLAX_OFFSET
	logo.position.y += LOGO_PARALLAX_OFFSET
	_setup_animation()
	animation_player.play("intro")
	_fade_in_music()
	# Aplica configurações salvas (volume, resolução, fullscreen)
	OptionsMenu.aplicar_configuracoes_salvas()


func _setup_animation() -> void:
	var anim := Animation.new()
	anim.length = 2.5
	const SLIDE_DUR := 2.2

	# ── Posição Y — bezier ease-out (arranca rápido, desacelera ao final) ──────

	# Background: desloca 280px, sobe devagar (longe da câmera)
	# Tangente inicial íngreme (90% do percurso nos primeiros 10% do tempo),
	# tangente final plana (velocidade → 0 ao chegar na posição final)
	var bg_y := anim.add_track(Animation.TYPE_BEZIER)
	anim.track_set_path(bg_y, "Background:position:y")
	anim.bezier_track_insert_key(bg_y, 0.0, BG_PARALLAX_OFFSET,
		Vector2(0.0, 0.0),
		Vector2(SLIDE_DUR * 0.1, -BG_PARALLAX_OFFSET * 0.9))
	anim.bezier_track_insert_key(bg_y, SLIDE_DUR, 0.0,
		Vector2(-SLIDE_DUR * 0.55, 0.0),
		Vector2(0.0, 0.0))

	# Logo: desloca 110px, mesmo timing mas percurso menor (próximo da câmera)
	var logo_start_y: float = logo.position.y          # já deslocado em _ready
	var logo_end_y: float   = logo_start_y - LOGO_PARALLAX_OFFSET
	var logo_y := anim.add_track(Animation.TYPE_BEZIER)
	anim.track_set_path(logo_y, "Logo:position:y")
	anim.bezier_track_insert_key(logo_y, 0.0, logo_start_y,
		Vector2(0.0, 0.0),
		Vector2(SLIDE_DUR * 0.1, -LOGO_PARALLAX_OFFSET * 0.9))
	anim.bezier_track_insert_key(logo_y, SLIDE_DUR, logo_end_y,
		Vector2(-SLIDE_DUR * 0.55, 0.0),
		Vector2(0.0, 0.0))

	# ── Alpha — bezier ease-out (fade rápido, nivela suavemente em 1.0) ────────

	# Logo e Background: aparecem juntos a partir de t=0.8
	# Background: segura em 0 até t=0.8, depois 0 → 1 até t=2.0 (fade mais longo)
	var bg_a := anim.add_track(Animation.TYPE_BEZIER)
	anim.track_set_path(bg_a, "Background:modulate:a")
	anim.bezier_track_insert_key(bg_a, 0.0, 0.0,
		Vector2(0.0, 0.0), Vector2(0.3, 0.0))   # tangente plana — segura em 0
	anim.bezier_track_insert_key(bg_a, 0.8, 0.0,
		Vector2(-0.3, 0.0), Vector2(0.18, 0.6)) # arranca o fade
	anim.bezier_track_insert_key(bg_a, 2.0, 1.0,
		Vector2(-0.4, 0.0), Vector2(0.0, 0.0))

	# Logo: segura em 0 até t=0.8, depois 0 → 1 até t=1.6 (fade mais curto)
	var logo_a := anim.add_track(Animation.TYPE_BEZIER)
	anim.track_set_path(logo_a, "Logo:modulate:a")
	anim.bezier_track_insert_key(logo_a, 0.0, 0.0,
		Vector2(0.0, 0.0), Vector2(0.3, 0.0))   # tangente plana — segura em 0
	anim.bezier_track_insert_key(logo_a, 0.8, 0.0,
		Vector2(-0.3, 0.0), Vector2(0.12, 0.6)) # arranca o fade
	anim.bezier_track_insert_key(logo_a, 1.6, 1.0,
		Vector2(-0.28, 0.0), Vector2(0.0, 0.0))

	# MenuContainer: segura em 0 até t=2.0, depois 0 → 1 até t=2.5
	var menu_a := anim.add_track(Animation.TYPE_BEZIER)
	anim.track_set_path(menu_a, "MenuContainer:modulate:a")
	anim.bezier_track_insert_key(menu_a, 0.0, 0.0,
		Vector2(0.0, 0.0), Vector2(0.5, 0.0))   # tangente plana
	anim.bezier_track_insert_key(menu_a, 2.0, 0.0,
		Vector2(-0.5, 0.0), Vector2(0.1, 0.5))  # arranca o fade
	anim.bezier_track_insert_key(menu_a, 2.5, 1.0,
		Vector2(-0.15, 0.0), Vector2(0.0, 0.0))

	var lib := AnimationLibrary.new()
	lib.add_animation("intro", anim)
	animation_player.add_animation_library("", lib)


func _fade_in_music() -> void:
	music.volume_db = -80.0
	music.play()
	create_tween() \
		.tween_property(music, "volume_db", -6.0, 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_new_game_pressed() -> void:
	print("New Game")
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_load_game_pressed() -> void:
	print("Load Game")


func _on_options_pressed() -> void:
	var options: Control = load(OPTIONS_SCENE).instantiate()
	add_child(options)
	options.closed.connect(_on_options_closed.bind(options))


func _on_options_closed(_options_node: Control) -> void:
	pass  # painel já se destruiu via queue_free()


func _on_exit_pressed() -> void:
	get_tree().quit()
