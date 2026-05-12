## Easy State Machine state that plays the Warrior idle animation.
@tool
class_name WarriorIdleState
extends EasyState

@export var animation_name: StringName = &"idle"
@export var sprite_node_path: NodePath = ^"AnimatedSprite2D"

func _on_enter(_previous_state: EasyState) -> void:
	CombatantAnimationStateHelper.play_animation(host, animation_name, sprite_node_path)
