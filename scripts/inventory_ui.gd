## inventory_ui.gd
## UI do inventário: grade 5×3 + linha de hotbar, drag-and-drop unificado.
## Slots 0-14 → inventário (InventoryData). Slots 15-19 → hotbar (_hotbar em world.gd).
## O descarte ocorre ao soltar fora do painel.
class_name InventoryUI
extends CanvasLayer

signal closed

# ── Constantes de layout ──────────────────────────────────────────────────────
const INV_COLS    := 5
const INV_ROWS    := 3
const INV_COUNT   := INV_COLS * INV_ROWS   # 15
const HOT_COUNT   := 5
const TOTAL_SLOTS := INV_COUNT + HOT_COUNT # 20

const SLOT_SIZE  := 56
const SLOT_GAP   := 6
const PADDING    := 16
const TITLE_H    := 24
const SECTION_H  := 18   # altura do rótulo de seção
const SEPARATOR_H := 2
const HINT_H     := 14
const HOT_GAP    := 10   # espaço entre grade e hotbar

# ── Cores ─────────────────────────────────────────────────────────────────────
const C_BG          := Color(0.07, 0.07, 0.07, 0.93)
const C_BORDER      := Color(0.55, 0.42, 0.10, 0.85)
const C_SEPARATOR   := Color(0.40, 0.35, 0.15, 0.60)
const C_SLOT_NORMAL := Color(0.16, 0.16, 0.16, 1.0)
const C_SLOT_HOVER  := Color(0.28, 0.28, 0.28, 1.0)
const C_SLOT_DRAG   := Color(0.40, 0.30, 0.08, 1.0)   # slot de origem
const C_SLOT_DROP   := Color(0.20, 0.38, 0.20, 1.0)   # destino válido
const C_SLOT_HOT    := Color(0.13, 0.13, 0.18, 1.0)   # fundo hotbar normal
const C_SLOT_HOT_SEL := Color(0.48, 0.38, 0.08, 1.0)  # slot selecionado da hotbar
const C_DISCARD     := Color(0.55, 0.12, 0.12, 1.0)   # drag sobre área de descarte

# ── Estado ────────────────────────────────────────────────────────────────────
var data: InventoryData = null
## Referência direta ao Array _hotbar de world.gd (modificado em tempo real).
var _hotbar_ref: Array = []
## Mapa item_id → Texture2D, fornecido por world.gd.
var icon_map: Dictionary = {}
## Índice do slot da hotbar atualmente selecionado em jogo (15-19 no sistema unificado).
var _selected_hotbar: int = 15

var _slot_panels: Array[Panel] = []   # [0..19]: inv + hotbar
var _drag_from_index: int = -1
var _hovered_slot:    int = -1
var _drag_outside:    bool = false    # mouse saiu do painel enquanto arrasta

# Nós de UI
var _background:   Panel   = null
var _drag_icon:    TextureRect = null
var _drag_count:   Label   = null
var _drag_surface: Control = null


func _init(inventory_data: InventoryData, icons: Dictionary) -> void:
	data     = inventory_data
	icon_map = icons
	layer    = 10


func _ready() -> void:
	_build_ui()
	hide()


# ── Acesso unificado aos slots ────────────────────────────────────────────────

func _is_hotbar(idx: int) -> bool:
	return idx >= INV_COUNT


func _hbar_idx(idx: int) -> int:
	return idx - INV_COUNT


func _slot_id(idx: int) -> String:
	if _is_hotbar(idx):
		return str(_hotbar_ref[_hbar_idx(idx)].get("id", ""))
	return str(data.slots[idx].get("id", ""))


func _slot_qty(idx: int) -> int:
	if _is_hotbar(idx):
		return int(_hotbar_ref[_hbar_idx(idx)].get("count", 0))
	return int(data.slots[idx].get("quantity", 0))


func _slot_name(idx: int) -> String:
	if _is_hotbar(idx):
		return str(_hotbar_ref[_hbar_idx(idx)].get("label", ""))
	return str(data.slots[idx].get("name", ""))


## Escreve dados em qualquer slot, convertendo para o formato correto.
func _write_slot(idx: int, item_id: String, item_name: String, qty: int) -> void:
	if _is_hotbar(idx):
		_hotbar_ref[_hbar_idx(idx)] = {"id": item_id, "label": item_name, "count": qty}
	else:
		data.slots[idx] = {"id": item_id, "name": item_name, "quantity": qty}


## Apaga qualquer slot, respeitando o formato de cada sistema.
func _clear_slot(idx: int) -> void:
	if _is_hotbar(idx):
		_hotbar_ref[_hbar_idx(idx)] = {"id": "", "label": "Vazio", "count": 0}
	else:
		data.slots[idx] = {"id": "", "name": "", "quantity": 0}


## Move/empilha/troca dois slots quaisquer (inventory ↔ hotbar transparente).
func _move_unified(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return

	var f_id   := _slot_id(from_idx)
	var f_qty  := _slot_qty(from_idx)
	var f_name := _slot_name(from_idx)
	var t_id   := _slot_id(to_idx)
	var t_qty  := _slot_qty(to_idx)
	var t_name := _slot_name(to_idx)

	if f_id == "":
		return

	if f_id == t_id:
		# Empilha no destino
		var space := InventoryData.MAX_STACK - t_qty
		var moved := mini(f_qty, space)
		_write_slot(to_idx, t_id, t_name, t_qty + moved)
		var remaining := f_qty - moved
		if remaining <= 0:
			_clear_slot(from_idx)
		else:
			_write_slot(from_idx, f_id, f_name, remaining)
	else:
		# Troca
		_write_slot(to_idx, f_id, f_name, f_qty)
		if t_id == "":
			_clear_slot(from_idx)
		else:
			_write_slot(from_idx, t_id, t_name, t_qty)


## Divide metade de `from_idx` em `to_idx`.
func _split_unified(from_idx: int, to_idx: int) -> void:
	if from_idx == to_idx:
		return

	var f_id   := _slot_id(from_idx)
	var f_qty  := _slot_qty(from_idx)
	var f_name := _slot_name(from_idx)
	if f_id == "" or f_qty <= 1:
		return

	var t_id  := _slot_id(to_idx)
	var t_qty := _slot_qty(to_idx)
	if t_id != "" and t_id != f_id:
		return

	var half := f_qty / 2
	_write_slot(from_idx, f_id, f_name, f_qty - half)
	_write_slot(to_idx, f_id, f_name, t_qty + half)


# ── Construção da UI ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var grid_w   := INV_COLS * SLOT_SIZE + (INV_COLS - 1) * SLOT_GAP
	var grid_h   := INV_ROWS * SLOT_SIZE + (INV_ROWS - 1) * SLOT_GAP
	var hot_w    := HOT_COUNT  * SLOT_SIZE + (HOT_COUNT - 1) * SLOT_GAP
	var panel_w  := grid_w + PADDING * 2
	var panel_h  := (PADDING
		+ TITLE_H + 6
		+ grid_h
		+ HOT_GAP + SEPARATOR_H + HOT_GAP
		+ SECTION_H + 4
		+ SLOT_SIZE
		+ HINT_H + PADDING)

	# Painel de fundo (centra na tela via anchors)
	_background = Panel.new()
	_background.name = "InventoryBackground"
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
	title.text = "Inventário"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.90, 0.78, 0.45))
	title.size = Vector2(panel_w - PADDING * 2, TITLE_H)
	title.position = Vector2(PADDING, PADDING * 0.5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_child(title)

	# ── Grade do inventário ──
	var grid_y := PADDING * 0.5 + TITLE_H + 6.0
	var grid_root := _make_section_root(Vector2(PADDING, grid_y), Vector2(grid_w, grid_h))
	_background.add_child(grid_root)

	for i in INV_COUNT:
		var col := i % INV_COLS
		var row := i / INV_COLS
		var panel := _create_slot_panel(i, col, row, false)
		_slot_panels.append(panel)
		grid_root.add_child(panel)

	# ── Separador ──
	var sep_y := grid_y + grid_h + HOT_GAP
	var sep := ColorRect.new()
	sep.color = C_SEPARATOR
	sep.size = Vector2(grid_w, SEPARATOR_H)
	sep.position = Vector2(PADDING, sep_y)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_child(sep)

	# ── Label "Hotbar" ──
	var hot_label_y := sep_y + SEPARATOR_H + HOT_GAP * 0.5
	var hot_label := Label.new()
	hot_label.text = "Hotbar  (itens equipados)"
	hot_label.add_theme_font_size_override("font_size", 10)
	hot_label.add_theme_color_override("font_color", Color(0.60, 0.55, 0.35))
	hot_label.size = Vector2(grid_w, SECTION_H)
	hot_label.position = Vector2(PADDING, hot_label_y)
	hot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_child(hot_label)

	# ── Linha da hotbar ──
	var hot_y   := hot_label_y + SECTION_H + 4.0
	var hot_x   := PADDING + (grid_w - hot_w) * 0.5  # centra na grade
	var hot_root := _make_section_root(Vector2(hot_x, hot_y), Vector2(hot_w, SLOT_SIZE))
	_background.add_child(hot_root)

	for i in HOT_COUNT:
		var global_idx := INV_COUNT + i
		var panel := _create_slot_panel(global_idx, i, 0, true)
		_slot_panels.append(panel)
		hot_root.add_child(panel)

	# ── Dica de controles ──
	var hint_y := hot_y + SLOT_SIZE + 6.0
	var hint := Label.new()
	hint.text = "Arrastar → mover   •   Clique-dir → dividir   •   Soltar fora → descartar   •   E/ESC → fechar"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	hint.size = Vector2(panel_w - PADDING * 2, HINT_H)
	hint.position = Vector2(PADDING, hint_y)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.add_child(hint)

	# ── Preview de drag (cobre a tela, ignora mouse) ──
	_drag_surface = Control.new()
	_drag_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drag_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_surface.z_index = 50
	add_child(_drag_surface)

	_drag_icon = TextureRect.new()
	_drag_icon.size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
	_drag_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_drag_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_drag_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_icon.modulate = Color(1, 1, 1, 0.80)
	_drag_icon.visible = false
	_drag_surface.add_child(_drag_icon)

	_drag_count = Label.new()
	_drag_count.add_theme_font_size_override("font_size", 10)
	_drag_count.add_theme_color_override("font_color", Color.WHITE)
	_drag_count.add_theme_color_override("font_shadow_color", Color.BLACK)
	_drag_count.add_theme_constant_override("shadow_offset_x", 1)
	_drag_count.add_theme_constant_override("shadow_offset_y", 1)
	_drag_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_count.visible = false
	_drag_surface.add_child(_drag_count)


func _make_section_root(pos: Vector2, sz: Vector2) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _create_slot_panel(index: int, col: int, row: int, is_hotbar: bool) -> Panel:
	var panel := Panel.new()
	panel.name = "Slot%d" % index
	panel.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.position = Vector2(col * (SLOT_SIZE + SLOT_GAP), row * (SLOT_SIZE + SLOT_GAP))
	panel.add_theme_stylebox_override("panel", _slot_style(index))

	# Ícone
	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.size = Vector2(SLOT_SIZE - 8, SLOT_SIZE - 8)
	icon_rect.position = Vector2(4, 4)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon_rect)

	# Contador
	var count_lbl := Label.new()
	count_lbl.name = "Count"
	count_lbl.add_theme_font_size_override("font_size", 9)
	count_lbl.add_theme_color_override("font_color", Color.WHITE)
	count_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	count_lbl.add_theme_constant_override("shadow_offset_x", 1)
	count_lbl.add_theme_constant_override("shadow_offset_y", 1)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	count_lbl.size = Vector2(SLOT_SIZE - 4, SLOT_SIZE - 4)
	count_lbl.position = Vector2(2, 2)
	count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(count_lbl)

	# Número do slot da hotbar (1-5)
	if is_hotbar:
		var num_lbl := Label.new()
		num_lbl.name = "SlotNum"
		num_lbl.text = str(_hbar_idx(index) + 1)
		num_lbl.add_theme_font_size_override("font_size", 8)
		num_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.35, 0.85))
		num_lbl.position = Vector2(3, 2)
		num_lbl.size = Vector2(14, 12)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(num_lbl)

	panel.gui_input.connect(_on_slot_gui_input.bind(index))
	panel.mouse_entered.connect(_on_slot_mouse_entered.bind(index))
	panel.mouse_exited.connect(_on_slot_mouse_exited.bind(index))
	return panel


# ── Estilos ───────────────────────────────────────────────────────────────────

func _make_panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = C_BG
	s.border_color = C_BORDER
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		s.set_border_width(side, 2)
	for corner in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT]:
		s.set_corner_radius(corner, 6)
	return s


func _make_slot_style(color: Color, border: Color = Color(0.38, 0.38, 0.38, 0.7), border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		s.set_border_width(side, border_w)
	for corner in [CORNER_TOP_LEFT, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT, CORNER_BOTTOM_RIGHT]:
		s.set_corner_radius(corner, 3)
	return s


## Retorna o estilo base para o slot no estado "normal".
func _slot_style(idx: int) -> StyleBoxFlat:
	if _is_hotbar(idx):
		if idx == _selected_hotbar:
			return _make_slot_style(C_SLOT_HOT_SEL, Color(0.85, 0.65, 0.15), 2)
		return _make_slot_style(C_SLOT_HOT, Color(0.45, 0.42, 0.25, 0.8))
	return _make_slot_style(C_SLOT_NORMAL)


# ── Eventos de slot ───────────────────────────────────────────────────────────

func _on_slot_mouse_entered(index: int) -> void:
	_hovered_slot = index
	_drag_outside = false
	if _drag_from_index < 0:
		_slot_panels[index].add_theme_stylebox_override("panel", _make_slot_style(C_SLOT_HOVER))
	elif index != _drag_from_index:
		_slot_panels[index].add_theme_stylebox_override("panel", _make_slot_style(C_SLOT_DROP))


func _on_slot_mouse_exited(index: int) -> void:
	if _hovered_slot == index:
		_hovered_slot = -1
	# Repõe estilo correto
	if index == _drag_from_index:
		_slot_panels[index].add_theme_stylebox_override("panel", _make_slot_style(C_SLOT_DRAG))
	else:
		_slot_panels[index].add_theme_stylebox_override("panel", _slot_style(index))


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return

	if event.button_index == MOUSE_BUTTON_LEFT:
		if _drag_from_index >= 0:
			_finish_drag(index)
		else:
			_start_drag(index)
		get_viewport().set_input_as_handled()

	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if _drag_from_index >= 0:
			# Clique-dir durante drag: divide metade no slot alvo
			_split_unified(_drag_from_index, index)
			_cancel_drag()
		else:
			# Divide para o primeiro slot compatível
			var target := _first_compatible_slot(index)
			if target >= 0:
				_split_unified(index, target)
			_refresh_all_slots()
		get_viewport().set_input_as_handled()


# ── Drag-and-drop ─────────────────────────────────────────────────────────────

func _start_drag(index: int) -> void:
	if _slot_id(index) == "":
		return
	_drag_from_index = index
	_drag_outside = false

	var qty := _slot_qty(index)
	_drag_icon.texture = _texture_for(index)
	_drag_icon.visible = true
	_drag_count.text    = "×%d" % qty if qty > 1 else ""
	_drag_count.visible = qty > 1

	_slot_panels[index].add_theme_stylebox_override("panel", _make_slot_style(C_SLOT_DRAG))
	_move_drag_preview(get_viewport().get_mouse_position())


func _finish_drag(to_index: int) -> void:
	if _drag_from_index < 0:
		return
	_move_unified(_drag_from_index, to_index)
	_end_drag()


func _discard_dragged_item() -> void:
	if _drag_from_index < 0:
		return
	_clear_slot(_drag_from_index)
	_end_drag()


func cancel_drag() -> void:
	_cancel_drag()


func _cancel_drag() -> void:
	if _drag_from_index < 0:
		return
	_end_drag()


func _end_drag() -> void:
	_drag_from_index = -1
	_drag_outside    = false
	_drag_icon.visible  = false
	_drag_count.visible = false
	_refresh_all_slots()


func _move_drag_preview(mouse_pos: Vector2) -> void:
	var offset := Vector2(-SLOT_SIZE * 0.5, -SLOT_SIZE * 0.5)
	_drag_icon.position  = mouse_pos + offset + Vector2(4, 4)
	_drag_count.position = mouse_pos + offset + Vector2(SLOT_SIZE - 22, SLOT_SIZE - 20)


func _first_compatible_slot(from_idx: int) -> int:
	var item_id := _slot_id(from_idx)
	# Prefere slot com mesmo item (não lotado) que não seja o próprio
	for i in TOTAL_SLOTS:
		if i != from_idx and _slot_id(i) == item_id and _slot_qty(i) < InventoryData.MAX_STACK:
			return i
	# Senão, primeiro slot vazio em qualquer lugar
	for i in TOTAL_SLOTS:
		if i != from_idx and _slot_id(i) == "":
			return i
	return -1


# ── Input global ──────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventMouseMotion:
		if _drag_from_index >= 0:
			_move_drag_preview(event.position)
			# Detecta se está fora do painel para feedback visual
			var was_outside := _drag_outside
			_drag_outside = not _background.get_global_rect().has_point(event.position)
			if _drag_outside != was_outside:
				_drag_icon.modulate = Color(0.9, 0.35, 0.35, 0.80) if _drag_outside else Color(1, 1, 1, 0.80)

	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _drag_from_index >= 0:
			if _hovered_slot >= 0 and not _drag_outside:
				_finish_drag(_hovered_slot)
			elif _drag_outside:
				_discard_dragged_item()
			else:
				_cancel_drag()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_cancel_drag()
		hide()
		closed.emit()
		get_viewport().set_input_as_handled()


# ── API pública ───────────────────────────────────────────────────────────────

## Passa a referência do array _hotbar de world.gd.
## Deve ser chamado uma vez em _setup_inventory(), após _setup_hotbar().
func set_hotbar(hotbar: Array) -> void:
	_hotbar_ref = hotbar


## Abre o inventário. `selected_hotbar` é o índice world.gd (0-4), convertido para 15-19.
func open(inventory_data: InventoryData, selected_hotbar: int = 0) -> void:
	data = inventory_data
	_selected_hotbar = INV_COUNT + selected_hotbar
	_cancel_drag()
	_refresh_all_slots()
	show()


# ── Atualização visual ────────────────────────────────────────────────────────

func _refresh_all_slots() -> void:
	for i in _slot_panels.size():
		_refresh_slot(i)


func _refresh_slot(index: int) -> void:
	if index >= _slot_panels.size():
		return

	var panel     := _slot_panels[index]
	var icon_rect := panel.get_node("Icon")  as TextureRect
	var count_lbl := panel.get_node("Count") as Label

	var item_id  := _slot_id(index)
	var item_qty := _slot_qty(index)
	icon_rect.texture = _texture_for(index) if item_id != "" else null
	count_lbl.text    = str(item_qty) if item_qty > 1 else ""

	# Cor do estilo
	var style: StyleBoxFlat
	if index == _drag_from_index:
		style = _make_slot_style(C_SLOT_DRAG)
	elif index == _hovered_slot and _drag_from_index >= 0:
		style = _make_slot_style(C_SLOT_DROP)
	elif index == _hovered_slot:
		style = _make_slot_style(C_SLOT_HOVER)
	else:
		style = _slot_style(index)
	panel.add_theme_stylebox_override("panel", style)


func _texture_for(index: int) -> Texture2D:
	return icon_map.get(_slot_id(index), null) as Texture2D
