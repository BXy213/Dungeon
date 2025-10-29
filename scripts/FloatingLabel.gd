class_name FloatingLabel
extends Label

# 🏷️ 浮动标签 - 用于显示伤害数字和buff提示

enum LabelType {
	DAMAGE,      # 伤害
	HEAL,        # 治疗
	BUFF,        # 增益buff
	DEBUFF       # 减益buff
}

var label_type: LabelType = LabelType.DAMAGE
var float_distance: float = 50.0  # 向上飘动的距离（屏幕像素）
var duration: float = 1.5  # 持续时间
var world_position: Vector2 = Vector2.ZERO  # 世界坐标位置

func _ready() -> void:
	print("🏷️ FloatingLabel _ready - 文本: ", text, " 类型: ", label_type, " 世界位置: ", world_position)
	
	# 设置标签样式
	add_theme_font_size_override("font_size", 14)  # 较小的字体
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	z_index = 100  # 确保在最上层
	
	# 设置自动尺寸
	size = Vector2.ZERO
	autowrap_mode = TextServer.AUTOWRAP_OFF
	
	# 添加描边效果
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 2)
	
	# 根据类型设置颜色
	match label_type:
		LabelType.DAMAGE:
			modulate = Color.RED
		LabelType.HEAL:
			modulate = Color.GREEN
		LabelType.BUFF:
			modulate = Color.CYAN
		LabelType.DEBUFF:
			modulate = Color.ORANGE
	
	# 等一帧确保添加到场景树后再更新位置
	await get_tree().process_frame
	update_screen_position()
	print("  📍 初始屏幕位置: ", position)
	
	# 开始动画
	start_animation()

func _process(_delta: float) -> void:
	"""每帧更新屏幕位置（如果相机移动）"""
	update_screen_position()

func update_screen_position() -> void:
	"""将世界坐标转换为屏幕坐标"""
	var viewport = get_viewport()
	if not viewport:
		return
	
	var camera = viewport.get_camera_2d()
	if not camera:
		return
	
	# 计算世界坐标在屏幕上的位置
	var camera_center = camera.get_screen_center_position()
	var viewport_size = viewport.get_visible_rect().size
	var screen_pos = world_position - camera_center + viewport_size / 2
	position = screen_pos - size / 2  # 居中对齐

func start_animation() -> void:
	"""启动浮动和淡出动画"""
	var tween = create_tween()
	tween.set_parallel(true)
	
	# 向上飘动（添加随机偏移避免重叠）
	var random_offset_x = randf_range(-20, 20)
	var start_world_pos = world_position
	var target_world_pos = start_world_pos + Vector2(random_offset_x, -float_distance)
	
	# 使用回调更新世界位置
	tween.tween_method(func(value: float):
		world_position = start_world_pos.lerp(target_world_pos, value)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 淡出效果（前半段保持，后半段淡出）
	tween.tween_property(self, "modulate:a", 1.0, duration * 0.5)
	tween.chain().tween_property(self, "modulate:a", 0.0, duration * 0.5)
	
	# 动画结束后删除
	await tween.finished
	queue_free()

## ========== 静态创建方法 ==========

static func create_damage_label(damage: int, ui_parent: Node, spawn_world_pos: Vector2) -> FloatingLabel:
	"""创建伤害标签
	@param damage: 伤害数值
	@param ui_parent: UI父节点（CanvasLayer或Control类型）
	@param spawn_world_pos: 世界坐标位置
	"""
	var label = FloatingLabel.new()
	label.text = str(damage)
	label.label_type = LabelType.DAMAGE
	label.world_position = spawn_world_pos
	ui_parent.add_child(label)
	return label

static func create_heal_label(heal_amount: int, ui_parent: Node, spawn_world_pos: Vector2) -> FloatingLabel:
	"""创建治疗标签
	@param heal_amount: 治疗数值
	@param ui_parent: UI父节点（CanvasLayer或Control类型）
	@param spawn_world_pos: 世界坐标位置
	"""
	var label = FloatingLabel.new()
	label.text = "+" + str(heal_amount)
	label.label_type = LabelType.HEAL
	label.world_position = spawn_world_pos
	ui_parent.add_child(label)
	return label

static func create_buff_label(buff_name: String, is_debuff: bool, ui_parent: Node, spawn_world_pos: Vector2) -> FloatingLabel:
	"""创建buff标签
	@param buff_name: Buff名称
	@param is_debuff: 是否为减益buff
	@param ui_parent: UI父节点（CanvasLayer或Control类型）
	@param spawn_world_pos: 世界坐标位置
	"""
	var label = FloatingLabel.new()
	label.text = buff_name
	label.label_type = LabelType.DEBUFF if is_debuff else LabelType.BUFF
	label.float_distance = 40.0  # buff标签飘得稍微低一些
	label.duration = 1.2  # buff标签显示时间稍短
	label.world_position = spawn_world_pos
	ui_parent.add_child(label)
	return label

