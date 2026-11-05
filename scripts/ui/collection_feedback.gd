class_name CityCollectionFeedback
extends Node2D
## A short visual bridge from the collected property to the actual cash counter.
## It never modifies balances or blocks town input.
signal delivered

func play(source: Vector2, target: Vector2) -> void:
	var texture: Texture2D = load("res://assets/ui/coin.svg")
	for i in range(3):
		var coin := Sprite2D.new()
		coin.texture = texture
		coin.scale = Vector2.ONE * .55
		coin.position = source
		add_child(coin)
		var bend := source.lerp(target, .35) + Vector2((i - 1) * 24, -85 - i * 16)
		var tween := create_tween()
		tween.tween_interval(i * .055)
		tween.tween_method(func(t: float) -> void:
			coin.position = source.lerp(bend, t).lerp(bend.lerp(target, t), t)
			coin.scale = Vector2.ONE * lerpf(.55, .32, t)
		, 0.0, 1.0, .42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		if i == 0: tween.tween_callback(func() -> void: delivered.emit())
		tween.tween_property(coin, "modulate:a", 0.0, .06)
	var cleanup := create_tween()
	cleanup.tween_interval(.7)
	cleanup.tween_callback(queue_free)
