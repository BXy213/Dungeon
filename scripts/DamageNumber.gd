extends Label

var damage_amount: int = 0
var is_critical: bool = false

func setup(dmg: int, pos: Vector2, critical: bool = false) -> void:
	damage_amount = dmg
	is_critical = critical
	global_position = pos
	
	# 设置文本和颜色
	text = str(damage_amount)
	if is_critical:
		modulate = Color.YELLOW
		add_theme_font_size_override("font_size", 20)
		text = "!" + text + "!"
	else:
		modulate = Color.RED
		add_theme_font_size_override("font_size", 16)
	
	# 播放动画
	animate_damage()

func animate_damage() -> void:
	var tween = create_tween()
	
	# 向上飘动并淡出
	var end_pos = global_position + Vector2(randf_range(-20, 20), -60)
	tween.parallel().tween_property(self, "global_position", end_pos, 1.0)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 1.0)
	
	# 如果是暴击，添加缩放效果
	if is_critical:
		tween.parallel().tween_property(self, "scale", Vector2(1.2, 1.2), 0.2)
		tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.8)
	
	# 动画结束后删除
	await tween.finished
	queue_free()
