## inventory_data.gd
## Dados puros do inventário — sem dependência de UI ou cena.
## 15 slots (5 colunas × 3 linhas), empilhável até MAX_STACK por slot.
class_name InventoryData
extends RefCounted

const SLOT_COUNT := 15
const MAX_STACK  := 99

## Cada slot: { "id": String, "name": String, "quantity": int }
var slots: Array[Dictionary] = []


func _init() -> void:
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = _empty_slot()


## Tenta adicionar `quantity` unidades de um item.
## Retorna o restante que não coube (0 = tudo adicionado).
func add_item(item_id: String, item_name: String, quantity: int) -> int:
	# Empilha em slots que já contêm o mesmo item
	for slot in slots:
		if slot["id"] == item_id and slot["quantity"] < MAX_STACK:
			var space: int = MAX_STACK - slot["quantity"]
			var added: int = mini(quantity, space)
			slot["quantity"] += added
			quantity -= added
			if quantity <= 0:
				return 0

	# Ocupa slots vazios
	for slot in slots:
		if slot["id"] == "":
			var added: int = mini(quantity, MAX_STACK)
			slot["id"]       = item_id
			slot["name"]     = item_name
			slot["quantity"] = added
			quantity -= added
			if quantity <= 0:
				return 0

	return quantity  # sobra que não coube


## Remove `quantity` unidades de um item. Retorna false se não houver quantidade suficiente.
func remove_item(item_id: String, quantity: int) -> bool:
	if get_item_count(item_id) < quantity:
		return false

	var remaining := quantity
	for i in slots.size():
		if slots[i]["id"] == item_id:
			var take: int = mini(remaining, slots[i]["quantity"])
			slots[i]["quantity"] -= take
			remaining -= take
			if slots[i]["quantity"] <= 0:
				slots[i] = _empty_slot()
			if remaining <= 0:
				break

	return true


## Quantidade total de um item em todos os slots.
func get_item_count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if slot["id"] == item_id:
			total += slot["quantity"]
	return total


## Move ou empilha um slot em outro. Troca se forem tipos diferentes.
func move_slot(from_index: int, to_index: int) -> void:
	if from_index == to_index:
		return

	var from_slot: Dictionary = slots[from_index]
	var to_slot:   Dictionary = slots[to_index]

	if from_slot["id"] == to_slot["id"] and from_slot["id"] != "":
		# Empilha no destino
		var space: int = MAX_STACK - to_slot["quantity"]
		var moved: int = mini(from_slot["quantity"], space)
		to_slot["quantity"]   += moved
		from_slot["quantity"] -= moved
		if from_slot["quantity"] <= 0:
			slots[from_index] = _empty_slot()
	else:
		# Troca os slots
		slots[from_index] = to_slot
		slots[to_index]   = from_slot


## Divide metade do slot `from_index` e coloca em `to_index`.
## Não faz nada se `to_index` já tiver um tipo diferente de item.
func split_slot(from_index: int, to_index: int) -> void:
	if from_index == to_index:
		return

	var from_slot: Dictionary = slots[from_index]
	if from_slot["id"] == "" or from_slot["quantity"] <= 1:
		return

	var to_slot: Dictionary = slots[to_index]
	if to_slot["id"] != "" and to_slot["id"] != from_slot["id"]:
		return

	var half: int = from_slot["quantity"] / 2
	from_slot["quantity"] -= half

	if to_slot["id"] == "":
		slots[to_index] = {
			"id":       from_slot["id"],
			"name":     from_slot["name"],
			"quantity": half,
		}
	else:
		to_slot["quantity"] = mini(to_slot["quantity"] + half, MAX_STACK)


## Esvazia um slot específico.
func clear_slot(index: int) -> void:
	slots[index] = _empty_slot()


## Retorna true se não houver nenhum slot livre.
func is_full() -> bool:
	for slot in slots:
		if slot["id"] == "":
			return false
	return true


func _empty_slot() -> Dictionary:
	return {"id": "", "name": "", "quantity": 0}
