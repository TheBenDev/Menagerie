@tool
class_name CombatantAnimationStateHelper
extends RefCounted

static func get_animated_sprite(host: Node, sprite_node_path: NodePath = ^"AnimatedSprite2D") -> AnimatedSprite2D:
	if host == null:
		return null

	return host.get_node_or_null(sprite_node_path) as AnimatedSprite2D

static func play_animation(
	host: Node,
	animation_name: StringName,
	sprite_node_path: NodePath = ^"AnimatedSprite2D"
) -> void:
	var sprite := get_animated_sprite(host, sprite_node_path)
	if not _can_use_animation(sprite, animation_name):
		return

	sprite.play(animation_name)

static func show_static_frame(
	host: Node,
	animation_name: StringName,
	frame_index: int = 0,
	sprite_node_path: NodePath = ^"AnimatedSprite2D"
) -> void:
	var sprite := get_animated_sprite(host, sprite_node_path)
	if not _can_use_animation(sprite, animation_name):
		return

	sprite.animation = animation_name
	sprite.frame = max(frame_index, 0)
	sprite.frame_progress = 0.0
	sprite.stop()

static func _can_use_animation(sprite: AnimatedSprite2D, animation_name: StringName) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name)
