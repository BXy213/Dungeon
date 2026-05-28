extends Area2D

const Constants = preload("res://scripts/core/GameConstants.gd")
const OPENED_TEXTURE = preload("res://art/chestopened.png")

# 📦 宝箱 - 使用银钥匙开启获得技能奖励
#
# ⚠️ 重要技术说明：
# 由于 Area2D 的 mouse_entered/mouse_exited 信号在某些情况下不可靠，
# 本实现使用手动鼠标位置检测（Rect2.has_point）来确保交互功能正常工作。

## ========== 枚举 ==========

enum ChestState {
	CLOSED,   # 未开启
	OPENED    # 已开启
}

## ========== 导出属性 ==========

@export var interaction_distance: float = 100.0  # 交互距离

## ========== 内部属性 ==========

var chest_state: ChestState = ChestState.CLOSED
var player: Node = null
var ui_manager: Node = null
var is_hovering: bool = false  # 鼠标是否悬停在宝箱上（备用）

## ========== 信号 ==========

signal chest_opened(chest: Node)

## ========== 初始化 ==========

func _ready() -> void:
	# 设置碰撞层和掩码
	collision_layer = Constants.LAYER_INTERACTABLE
	collision_mask = Constants.LAYER_NONE
	
	# 启用输入检测
	input_pickable = true
	set_process_input(true)
	
	# 连接鼠标进入/离开信号（作为备用方案）
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	
	# 添加到可交互组
	add_to_group(Constants.GROUP_CHESTS)
	visible = true
	
	# 等待一帧，确保节点树准备好
	await get_tree().process_frame
	
	# 获取玩家和UI管理器引用
	player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	ui_manager = get_tree().current_scene.get_node_or_null(Constants.NODE_UI_MANAGER)
	
	DebugLog.debug(["📦 宝箱初始化完成，位置: ", global_position], DebugLog.CATEGORY_INTERACTION)

## ========== 输入处理 ==========

func _input(event: InputEvent) -> void:
	"""处理输入事件（鼠标点击）"""
	# 只有在未开启状态下才能交互
	if chest_state != ChestState.CLOSED:
		return
	
	# 检测鼠标左键点击
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# ✅ 手动检测鼠标位置是否在宝箱范围内
			# 原因：Area2D 的 mouse_entered/mouse_exited 信号不够可靠
			var mouse_pos = get_global_mouse_position()
			var collision_shape = get_node_or_null("CollisionShape2D")
			
			if collision_shape and collision_shape.shape:
				var shape = collision_shape.shape as RectangleShape2D
				if shape:
					# 计算宝箱的碰撞矩形（全局坐标）
					var chest_rect = Rect2(
						global_position - shape.size / 2,
						shape.size
					)
					
					# 使用手动检测代替 is_hovering
					if chest_rect.has_point(mouse_pos):
						DebugLog.debug(["📦 点击宝箱，尝试交互"], DebugLog.CATEGORY_INTERACTION)
						attempt_interaction()
			else:
				# 降级方案：使用 is_hovering（如果信号系统工作正常）
				if is_hovering:
					DebugLog.debug(["📦 点击宝箱（使用is_hovering），尝试交互"], DebugLog.CATEGORY_INTERACTION)
					attempt_interaction()

func _on_mouse_entered() -> void:
	"""鼠标进入宝箱区域（备用方案）"""
	is_hovering = true
	# 添加悬停视觉效果
	if chest_state == ChestState.CLOSED:
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			sprite.modulate = Color(1.2, 1.2, 1.2, 1.0)  # 稍微变亮

func _on_mouse_exited() -> void:
	"""鼠标离开宝箱区域（备用方案）"""
	is_hovering = false
	# 移除悬停视觉效果
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.modulate = Color.WHITE

## ========== 交互逻辑 ==========

func attempt_interaction() -> void:
	"""尝试与宝箱交互"""
	if chest_state != ChestState.CLOSED:
		return
	
	# 检查玩家引用
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
		if not player:
			DebugLog.warning(["找不到玩家"], DebugLog.CATEGORY_INTERACTION)
			return
	
	# 检查距离
	var distance_squared = global_position.distance_squared_to(player.global_position)
	if distance_squared > interaction_distance * interaction_distance:
		DebugLog.info(["距离宝箱太远了！（", int(sqrt(distance_squared)), " / ", interaction_distance, "）"], DebugLog.CATEGORY_INTERACTION)
		return
	
	# 检查玩家状态（需要在IDLE状态）
	if player.has_node(Constants.NODE_STATE_MANAGER):
		var state_manager = player.get_node(Constants.NODE_STATE_MANAGER)
		if state_manager.current_state != state_manager.PlayerState.IDLE:
			DebugLog.info(["玩家当前无法交互（需要IDLE状态）"], DebugLog.CATEGORY_INTERACTION)
			return
	
	# 尝试开启宝箱
	try_open(player)

func try_open(interacting_player: Node) -> void:
	"""尝试开启宝箱（需要银钥匙）"""
	if chest_state != ChestState.CLOSED:
		return
	
	# 检查玩家是否有银钥匙
	if not interacting_player.has_method("remove_silver_key"):
		DebugLog.warning(["玩家没有remove_silver_key方法"], DebugLog.CATEGORY_INTERACTION)
		return
	
	if interacting_player.silver_key_count <= 0:
		DebugLog.info(["银钥匙不足，需要至少1把银钥匙才能开启宝箱"], DebugLog.CATEGORY_INTERACTION)
		return
	
	# 扣除银钥匙
	if not interacting_player.remove_silver_key(1):
		DebugLog.warning(["扣除银钥匙失败"], DebugLog.CATEGORY_INTERACTION)
		return
	
	DebugLog.info(["📦 使用银钥匙开启宝箱"], DebugLog.CATEGORY_INTERACTION)
	
	# 显示奖励选择界面
	if not ui_manager:
		ui_manager = get_tree().current_scene.get_node_or_null(Constants.NODE_UI_MANAGER)
	
	if ui_manager and ui_manager.has_method("show_chest_reward_selection"):
		ui_manager.show_chest_reward_selection(self)
	else:
		DebugLog.warning(["无法找到UI管理器"], DebugLog.CATEGORY_UI)
		# 直接开启宝箱
		open_chest()

func open_chest() -> void:
	"""开启宝箱（在奖励确认后调用）"""
	if chest_state == ChestState.OPENED:
		return
	
	chest_state = ChestState.OPENED
	DebugLog.info(["📦 宝箱已开启"], DebugLog.CATEGORY_INTERACTION)
	
	# 切换贴图为打开状态
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = OPENED_TEXTURE
		sprite.modulate = Color.WHITE  # 移除悬停效果
	
	# 播放开启动画
	play_open_animation()
	
	# 发出信号
	chest_opened.emit(self)

func play_open_animation() -> void:
	"""播放开启动画（简单的跳跃效果）"""
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		# 跳跃效果
		tween.tween_property(sprite, "position:y", sprite.position.y - 10, 0.2)
		tween.chain().tween_property(sprite, "position:y", sprite.position.y, 0.2)
		# 轻微缩放
		tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.2)
		tween.chain().tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)
