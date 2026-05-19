## Control that fits a combatant AnimatedSprite2D inside battle HUD art bounds.
class_name CombatantBattleVisual
extends Control

signal visual_bounds_changed(bounds: Rect2)

@export var sprite_node_path: NodePath = ^"AnimatedSprite2D"
@export_range(0.1, 2.0, 0.01) var fill_ratio: float = 0.95
@export var bottom_padding: float = 8.0
@export var visual_offset: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null(sprite_node_path) as AnimatedSprite2D

var visual_bounds: Rect2 = Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_fit_sprite)
	if animated_sprite != null:
		animated_sprite.animation_changed.connect(_fit_sprite)
		animated_sprite.frame_changed.connect(_fit_sprite)
	call_deferred("_fit_sprite")

func get_visual_bounds() -> Rect2:
	return visual_bounds

func _fit_sprite() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		_set_visual_bounds(Rect2())
		return
	if size.x <= 0.0 or size.y <= 0.0:
		_set_visual_bounds(Rect2())
		return

	var frame_texture := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	if frame_texture == null:
		_set_visual_bounds(Rect2())
		return

	var frame_size := frame_texture.get_size()
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		_set_visual_bounds(Rect2())
		return

	var available_size: Vector2 = Vector2(size.x, maxf(size.y - bottom_padding, 1.0)) * fill_ratio
	var uniform_scale: float = minf(available_size.x / frame_size.x, available_size.y / frame_size.y)
	var scaled_size: Vector2 = frame_size * uniform_scale
	animated_sprite.scale = Vector2.ONE * uniform_scale
	animated_sprite.position = Vector2(
		size.x * 0.5,
		size.y - bottom_padding - (scaled_size.y * 0.5)
	) + visual_offset
	_set_visual_bounds(Rect2(animated_sprite.position - scaled_size * 0.5, scaled_size))

func _set_visual_bounds(new_visual_bounds: Rect2) -> void:
	if visual_bounds == new_visual_bounds:
		return

	visual_bounds = new_visual_bounds
	visual_bounds_changed.emit(visual_bounds)
