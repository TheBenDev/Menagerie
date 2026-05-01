@tool
class_name CombatantStaticState
extends EasyState

@export var animation_name: StringName = &"static"
@export var sprite_node_path: NodePath = ^"AnimatedSprite2D"
@export var frame_index: int = 0

func _on_enter(_previous_state: EasyState) -> void:
	CombatantAnimationStateHelper.show_static_frame(host, animation_name, frame_index, sprite_node_path)
