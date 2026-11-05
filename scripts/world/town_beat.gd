class_name CityTownBeat
extends Node3D
## A short world-space accent for a completed action. The town remains interactive.

const RING := preload("res://assets/ui/arrival-ring.svg")

func play(at: Vector3, tone: Color, radius: float) -> void:
	position = at
	var stamp := Sprite3D.new()
	stamp.texture = RING
	stamp.axis = Vector3.AXIS_Y
	stamp.pixel_size = radius * 2.0 / RING.get_width()
	stamp.shaded = false
	stamp.modulate = Color(tone, .85)
	stamp.scale = Vector3.ONE * .50
	add_child(stamp)
	var motion := create_tween().set_parallel(true)
	motion.tween_property(stamp, "scale", Vector3.ONE, .56).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(stamp, "modulate:a", 0.0, .46).set_delay(.10)
	motion.chain().tween_callback(queue_free)
