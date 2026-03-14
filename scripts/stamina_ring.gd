extends Node2D
class_name StaminaRing

@export var radius := 18.0
@export var thickness := 4.0
@export var outline_color := Color.WHITE
@export var outline_thickness := 1.5
@export var fill_color := Color(0.584314, 0.870588, 0.388235, 1)

var _ratio := 1.0


func set_ratio(value: float) -> void:
	_ratio = clampf(value, 0.0, 1.0)
	visible = _ratio < 0.999
	queue_redraw()


func _draw() -> void:
	if _ratio <= 0.0 and not visible:
		return

	var start_angle := -PI / 2.0
	var full_circle := TAU
	if _ratio > 0.0:
		draw_arc(Vector2.ZERO, radius, start_angle, start_angle + full_circle * _ratio, 48, outline_color, thickness + outline_thickness * 2.0)
		draw_arc(Vector2.ZERO, radius, start_angle, start_angle + full_circle * _ratio, 48, fill_color, thickness)
