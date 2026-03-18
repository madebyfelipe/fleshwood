extends Control
class_name OptionsMenu

signal closed

const SETTINGS_PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

@onready var volume_slider: HSlider = $Panel/MarginContainer/VBox/VolumeRow/VolumeSlider
@onready var volume_value: Label = $Panel/MarginContainer/VBox/VolumeRow/VolumeValue
@onready var resolution_option: OptionButton = $Panel/MarginContainer/VBox/ResolutionRow/ResolutionOption
@onready var fullscreen_check: CheckButton = $Panel/MarginContainer/VBox/FullscreenRow/FullscreenCheck


func _ready() -> void:
	_popular_resolucoes()
	_carregar_configuracoes()


func _popular_resolucoes() -> void:
	resolution_option.clear()
	for res: Vector2i in RESOLUTIONS:
		resolution_option.add_item("%d × %d" % [res.x, res.y])


func _carregar_configuracoes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_aplicar_padroes()
		return

	var vol: float = cfg.get_value("audio", "volume_master", 1.0)
	volume_slider.value = vol * 100.0
	_atualizar_label_volume(vol * 100.0)

	var res_idx: int = cfg.get_value("video", "resolucao_idx", 0)
	resolution_option.selected = clampi(res_idx, 0, RESOLUTIONS.size() - 1)

	var tela_cheia: bool = cfg.get_value("video", "tela_cheia", false)
	fullscreen_check.button_pressed = tela_cheia


func _aplicar_padroes() -> void:
	volume_slider.value = 100.0
	_atualizar_label_volume(100.0)
	resolution_option.selected = 0
	fullscreen_check.button_pressed = false


func _atualizar_label_volume(val: float) -> void:
	volume_value.text = "%d%%" % int(val)


func _on_volume_slider_value_changed(value: float) -> void:
	_atualizar_label_volume(value)
	var vol := value / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol, 0.001)))


func _on_apply_pressed() -> void:
	_salvar_e_aplicar()


func _on_back_pressed() -> void:
	_salvar_e_aplicar()
	emit_signal("closed")
	queue_free()


func _salvar_e_aplicar() -> void:
	var vol := volume_slider.value / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol, 0.001)))

	var res_idx := resolution_option.selected
	var res := RESOLUTIONS[res_idx]
	DisplayServer.window_set_size(res)

	if fullscreen_check.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume_master", vol)
	cfg.set_value("video", "resolucao_idx", res_idx)
	cfg.set_value("video", "tela_cheia", fullscreen_check.button_pressed)
	cfg.save(SETTINGS_PATH)


# Chamado externamente para aplicar configurações salvas sem abrir o painel
static func aplicar_configuracoes_salvas() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return

	var vol: float = cfg.get_value("audio", "volume_master", 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol, 0.001)))

	var tela_cheia: bool = cfg.get_value("video", "tela_cheia", false)
	if tela_cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var res_idx: int = cfg.get_value("video", "resolucao_idx", 0)
	const RESS: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1366, 768),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
	]
	if res_idx >= 0 and res_idx < RESS.size():
		DisplayServer.window_set_size(RESS[res_idx])
