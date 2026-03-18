## darkwatcher_shop_ui.gd
## Loja do Observador — abre após o diálogo do Darkwatcher.
## Grade de múltiplos slots, similar ao InventoryUI.
class_name DarkwatcherShopUI
extends CanvasLayer

signal closed

const SLOT_SIZE    := 56
const SLOT_GAP     := 8
const SLOT_ROW_STEP := SLOT_SIZE + 30  # espaço vertical por célula (slot + nome + preço)
const PADDING      := 14
const TITLE_H      := 24
const COLS         := 3

const C_BG           := Color(0.07, 0.07, 0.07, 0.93)
const C_BORDER       := Color(0.55, 0.42, 0.10, 0.85)
const C_SLOT_NORMAL  := Color(0.16, 0.16, 0.16, 1.0)
const C_SLOT_HOVER   := Color(0.28, 0.28, 0.28, 1.0)
const C_SLOT_DISABLED := Color(0.10, 0.10, 0.10, 1.0)
const C_ERROR        := Color(0.75, 0.22, 0.22, 1.0)
const C_GOLD         := Color(0.90, 0.78, 0.45)

## Callable() -> int  — retorna moedas atuais do jogador.
var _get_coins: Callable
## Callable(item_id: String, price: int) -> bool  — tenta comprar; retorna true se ok.
var _try_buy: Callable
## Callable(item_id: String) -> bool  — retorna true se o item está disponível para compra.
var _can_buy: Callable
## Array de Dictionaries: { id, name, short, price, icon: Texture2D|null }
var _items: Array = []

var _background:    Panel = null
var _coins_label:   Label = null
var _feedback_lbl:  Label = null
var _slot_panels:   Array = []
var _hovered_index: int   = -1
var _feedback_timer: float = 0.0


func _init(get_coins: Callable, try_buy: Callable, can_buy: Callable, items: Array) -> void:
	_get_coins = get_coins
	_try_buy   = try_buy
	_can_buy   = can_buy
	_items     = items
	layer = 11


func _ready() -> void:
	_build_ui()
	hide()


func _build_ui() -> void:
	var rows := ceili(float(_items.size()) / float(COLS))
	var panel_w := PADDING * 2 + SLOT_SIZE * COLS + SLOT_GAP * (COLS - 1)
	# slots_area_h: espaço vertical para todos os slots + labels abaixo de cada linha
	var slots_area_h := rows * SLOT_ROW_STEP - (SLOT_ROW_STEP - SLOT_SIZE - 26)
	var panel_h := PADDING + TITLE_H + 8 + 16 + 12 + slots_area_h + 32 + PADDING

	_background = Panel.new()
	_background.add_theme_stylebox_override("panel", _make_panel_style())
	_background.size = Vector2(panel_w, panel_h)
	_background.anchor_left   = 0.5
	_background.anchor_top    = 0.5
	_background.anchor_right  = 0.5
	_background.anchor_bottom = 0.5
	_background.offset_left   = -panel_w * 0.5
	_background.offset_top    = -panel_h * 0.5
	_background.offset_right  =  panel_w * 0.5
	_background.offset_bottom =  panel_h * 0.5
	add_child(_background)

	# ── Título ──
	var title := Label.new()
	title.text = "Loja do Observador"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", C_GOLD)
	title.size = Vector2(panel_w - PADDING * 2, TITLE_H)
	title.position = Vector2(PADDING, PADDING * 0.5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_child(title)

	# ── Moedas do jogador ──
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 10)
	_coins_label.add_theme_color_override("font_color", Color(0.80, 0.75, 0.40))
	_coins_label.size = Vector2(panel_w - PADDING * 2, 16)
	_coins_label.position = Vector2(PADDING, PADDING * 0.5 + TITLE_H + 2)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_child(_coins_label)

	# ── Grade de slots ──
	var slots_y := PADDING + TITLE_H + 8 + 16 + 12

	for i in range(_items.size()):
		var col := i % COLS
		var row := i / COLS
		var sx := float(PADDING + col * (SLOT_SIZE + SLOT_GAP))
		var sy := float(slots_y + row * SLOT_ROW_STEP)
		var item: Dictionary = _items[i]

		var slot := Panel.new()
		slot.name = "Slot_%d" % i
		slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.position = Vector2(sx, sy)
		slot.add_theme_stylebox_override("panel", _make_slot_style(C_SLOT_NORMAL))
		_background.add_child(slot)
		_slot_panels.append(slot)

		# Ícone ou placeholder de texto
		if item.get("icon") != null:
			var icon := TextureRect.new()
			icon.texture = item["icon"]
			icon.anchor_left   = 0.0
			icon.anchor_top    = 0.0
			icon.anchor_right  = 1.0
			icon.anchor_bottom = 1.0
			icon.offset_left   = 4
			icon.offset_top    = 4
			icon.offset_right  = -4
			icon.offset_bottom = -4
			icon.expand_mode   = TextureRect.EXPAND_KEEP_SIZE
			icon.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter  = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)
		else:
			var short_lbl := Label.new()
			short_lbl.text = item.get("short", item["name"].left(3))
			short_lbl.add_theme_font_size_override("font_size", 8)
			short_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.80))
			short_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			short_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			short_lbl.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
			short_lbl.position = Vector2(2, 2)
			short_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(short_lbl)

		# Nome do item abaixo do slot
		var name_lbl := Label.new()
		name_lbl.text = item["name"]
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		name_lbl.size = Vector2(SLOT_SIZE, 12)
		name_lbl.position = Vector2(sx, sy + SLOT_SIZE + 2)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background.add_child(name_lbl)

		# Preço abaixo do nome
		var price_lbl := Label.new()
		price_lbl.name = "Price_%d" % i
		price_lbl.text = "%d moedas" % item["price"]
		price_lbl.add_theme_font_size_override("font_size", 8)
		price_lbl.add_theme_color_override("font_color", C_GOLD)
		price_lbl.size = Vector2(SLOT_SIZE, 12)
		price_lbl.position = Vector2(sx, sy + SLOT_SIZE + 14)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_background.add_child(price_lbl)

		var idx := i
		slot.gui_input.connect(func(ev: InputEvent) -> void: _on_slot_gui_input(ev, idx))
		slot.mouse_entered.connect(func() -> void: _on_slot_mouse_entered(idx))
		slot.mouse_exited.connect(func() -> void: _on_slot_mouse_exited(idx))

	# ── Feedback ──
	var feedback_y := slots_y + slots_area_h + 6
	_feedback_lbl = Label.new()
	_feedback_lbl.add_theme_font_size_override("font_size", 10)
	_feedback_lbl.add_theme_color_override("font_color", C_ERROR)
	_feedback_lbl.size = Vector2(panel_w - PADDING * 2, 14)
	_feedback_lbl.position = Vector2(PADDING, feedback_y)
	_feedback_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_lbl.visible = false
	_background.add_child(_feedback_lbl)

	# ── Dica de fechar ──
	var hint := Label.new()
	hint.text = "ESC — fechar"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.40, 0.40, 0.40))
	hint.size = Vector2(panel_w - PADDING * 2, 12)
	hint.position = Vector2(PADDING, panel_h - PADDING - 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_child(hint)


func _process(delta: float) -> void:
	if not visible:
		return
	if _feedback_timer > 0.0:
		_feedback_timer = max(_feedback_timer - delta, 0.0)
		if _feedback_timer <= 0.0:
			_feedback_lbl.visible = false
	if _coins_label != null and _get_coins.is_valid():
		_coins_label.text = "Suas moedas: %d" % _get_coins.call()
	_refresh_slots()


func _refresh_slots() -> void:
	for i in range(_slot_panels.size()):
		var item: Dictionary = _items[i]
		var available: bool = _can_buy.is_valid() and _can_buy.call(item["id"])
		var slot: Panel = _slot_panels[i]
		if not available:
			slot.add_theme_stylebox_override("panel", _make_slot_style(C_SLOT_DISABLED))
			slot.modulate = Color(0.45, 0.45, 0.45, 1.0)
		else:
			if i == _hovered_index:
				slot.add_theme_stylebox_override("panel", _make_slot_style(C_SLOT_HOVER))
			else:
				slot.add_theme_stylebox_override("panel", _make_slot_style(C_SLOT_NORMAL))
			slot.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _on_slot_gui_input(event: InputEvent, idx: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_attempt_purchase(idx)
		get_viewport().set_input_as_handled()


func _on_slot_mouse_entered(idx: int) -> void:
	_hovered_index = idx
	if _can_buy.is_valid() and _can_buy.call(_items[idx]["id"]):
		_slot_panels[idx].add_theme_stylebox_override("panel", _make_slot_style(C_SLOT_HOVER))


func _on_slot_mouse_exited(idx: int) -> void:
	if _hovered_index == idx:
		_hovered_index = -1
	if _can_buy.is_valid() and _can_buy.call(_items[idx]["id"]):
		_slot_panels[idx].add_theme_stylebox_override("panel", _make_slot_style(C_SLOT_NORMAL))


func _attempt_purchase(idx: int) -> void:
	var item: Dictionary = _items[idx]
	if not (_can_buy.is_valid() and _can_buy.call(item["id"])):
		_show_feedback("Item indisponível", Color(0.55, 0.55, 0.55))
		return
	if not _try_buy.is_valid():
		return
	var ok: bool = _try_buy.call(item["id"], item["price"])
	if ok:
		_show_feedback("%s adquirido!" % item["name"], Color(0.40, 0.80, 0.40))
	else:
		_show_feedback("Moedas insuficientes", C_ERROR)


func _show_feedback(msg: String, color: Color) -> void:
	_feedback_lbl.text = msg
	_feedback_lbl.add_theme_color_override("font_color", color)
	_feedback_lbl.visible = true
	_feedback_timer = 2.5


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


## Abre a loja.
func open() -> void:
	if _coins_label != null and _get_coins.is_valid():
		_coins_label.text = "Suas moedas: %d" % _get_coins.call()
	_feedback_lbl.visible = false
	_feedback_timer = 0.0
	_refresh_slots()
	show()


func _close() -> void:
	hide()
	closed.emit()


# ── Estilos ──────────────────────────────────────────────────────────────────

func _make_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG
	s.border_color = C_BORDER
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		s.set_border_width(side, 2)
	for corner in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT]:
		s.set_corner_radius(corner, 6)
	return s


func _make_slot_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color(0.38, 0.38, 0.38, 0.7)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		s.set_border_width(side, 1)
	for corner in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT]:
		s.set_corner_radius(corner, 3)
	return s
