class_name PlayerStateManager
extends Node

# 🎮 玩家状态管理器 - 处理技能选择和释放的状态机

## 玩家状态枚举
enum PlayerState {
	IDLE,                    # 技能未选中状态
	SKILL_SELECTED,          # 技能已选中（通用状态）
	SKILL_TARGETING,         # 技能特定选择状态
	SKILL_CASTING            # 技能释放中
}

## 当前状态
var current_state: PlayerState = PlayerState.IDLE
var selected_skill = null
var selected_skill_slot: int = -1

## 引用
var player: Node = null
var skill_manager: Node = null
var skill_indicator: Node = null

signal state_changed(old_state: PlayerState, new_state: PlayerState)
signal skill_selected(skill, slot: int)
signal skill_deselected(skill)
signal skill_cast_requested(skill, target_position: Vector2, target_node: Node)

func _init(p_player: Node = null):
	player = p_player
	if player:
		skill_manager = player.get_node_or_null("SkillManager")
		# 技能指示器在场景中查找
		call_deferred("find_skill_indicator")

func find_skill_indicator():
	skill_indicator = player.get_tree().current_scene.get_node_or_null("SkillIndicator")

## ========== 状态转换方法 ==========

func transition_to_state(new_state: PlayerState) -> void:
	"""状态转换"""
	var old_state = current_state
	current_state = new_state
	print("🎮 玩家状态: ", PlayerState.keys()[old_state], " → ", PlayerState.keys()[new_state])
	state_changed.emit(old_state, new_state)

func try_select_skill(slot_index: int) -> bool:
	"""尝试选择技能"""
	if not skill_manager:
		return false
		
	var skill = skill_manager.get_skill_instance(slot_index)
	if not skill:
		print("技能槽 ", slot_index + 1, " 为空！")
		return false
	
	if not skill.can_cast():
		return false
	
	# 如果已经选中了技能，先取消
	if current_state != PlayerState.IDLE:
		cancel_skill_selection()
	
	# 选择新技能
	selected_skill = skill
	selected_skill_slot = slot_index
	
	# 根据技能类型进入不同状态
	match skill.cast_type:
		0:  # SkillBase.SkillCastType.AUTO_CAST
			# 自动释放技能
			handle_auto_cast_skill()
		_:
			# 进入技能选择状态
			enter_skill_targeting_state()
	
	return true

func handle_auto_cast_skill() -> void:
	"""处理自动释放技能"""
	print("🚀 自动释放技能: ", selected_skill.skill_name)
	
	transition_to_state(PlayerState.SKILL_CASTING)
	
	# 调用技能的选中方法（会自动释放）
	selected_skill.on_skill_selected()
	
	# 释放完成，返回空闲状态
	call_deferred("finish_skill_cast")

func enter_skill_targeting_state() -> void:
	"""进入技能瞄准状态"""
	transition_to_state(PlayerState.SKILL_SELECTED)
	
	# 通知技能被选中
	selected_skill.on_skill_selected()
	skill_selected.emit(selected_skill, selected_skill_slot)
	
	# 显示技能指示器
	show_skill_indicator()
	
	# 根据技能类型进入特定状态
	transition_to_state(PlayerState.SKILL_TARGETING)

func show_skill_indicator() -> void:
	"""显示技能指示器"""
	if skill_indicator and selected_skill:
		var indicator_info = selected_skill.get_skill_indicator_info()
		skill_indicator.show_indicator(indicator_info)

func cancel_skill_selection() -> void:
	"""取消技能选择"""
	if selected_skill:
		selected_skill.on_skill_deselected()
		skill_deselected.emit(selected_skill)
	
	# 隐藏技能指示器
	if skill_indicator:
		skill_indicator.hide_indicator()
	
	# 重置状态
	selected_skill = null
	selected_skill_slot = -1
	transition_to_state(PlayerState.IDLE)

func try_cast_skill(target_position: Vector2, target_node: Node = null) -> bool:
	"""尝试释放技能"""
	if current_state != PlayerState.SKILL_TARGETING or not selected_skill:
		return false
	
	# 🎯 使用技能指示器的受限制位置，而不是鼠标位置
	var actual_target_position = target_position
	if skill_indicator and skill_indicator.has_method("get_clamped_position"):
		actual_target_position = skill_indicator.get_clamped_position()
		print("🎯 使用受限制的目标位置: ", actual_target_position, " (原鼠标位置: ", target_position, ")")
	
	# 检查技能特定的释放条件
	if not can_cast_at_target(actual_target_position, target_node):
		# 对于精准射击，无目标时取消技能
		if selected_skill.cast_type == 2:  # SkillBase.SkillCastType.TARGET_ENEMY
			print("🎯 无有效目标，取消技能")
			cancel_skill_selection()
			return false
		else:
			print("❌ 无法在此位置释放技能")
			return false
	
	# 释放技能
	transition_to_state(PlayerState.SKILL_CASTING)
	skill_cast_requested.emit(selected_skill, actual_target_position, target_node)
	
	# 执行技能效果（使用受限制的位置）
	var success = selected_skill.cast_skill(actual_target_position, target_node)
	
	if success:
		print("✅ 技能释放成功: ", selected_skill.skill_name)
	
	# 释放完成，返回空闲状态
	call_deferred("finish_skill_cast")
	
	return success

func can_cast_at_target(target_position: Vector2, _target_node: Node) -> bool:
	"""检查是否可以在目标位置释放技能"""
	if not selected_skill:
		return false
	
	# 检查射程
	if not selected_skill.is_position_in_range(target_position):
		print("📏 目标超出技能射程")
		return false
	
	# 根据技能类型检查特定条件
	match selected_skill.cast_type:
		2:  # SkillBase.SkillCastType.TARGET_ENEMY
			# 精准射击需要有敌人目标
			var enemy = selected_skill.find_closest_enemy(target_position, 50.0)
			return enemy != null
		_:
			return true

func finish_skill_cast() -> void:
	"""完成技能释放"""
	# 清理状态
	if selected_skill:
		selected_skill.on_skill_deselected()
	
	if skill_indicator:
		skill_indicator.hide_indicator()
	
	selected_skill = null
	selected_skill_slot = -1
	transition_to_state(PlayerState.IDLE)

## ========== 输入处理方法 ==========

func handle_skill_key_input(slot_index: int) -> bool:
	"""处理技能按键输入 (1-4键)"""
	match current_state:
		PlayerState.IDLE:
			return try_select_skill(slot_index)
		PlayerState.SKILL_SELECTED, PlayerState.SKILL_TARGETING:
			# 切换到新技能
			return try_select_skill(slot_index)
		PlayerState.SKILL_CASTING:
			# 技能释放中，忽略输入
			return false
	
	return false

func handle_left_click(target_position: Vector2) -> bool:
	"""处理鼠标左键点击"""
	match current_state:
		PlayerState.IDLE:
			# 空闲状态，无反应
			return false
		PlayerState.SKILL_TARGETING:
			# 尝试释放技能
			return try_cast_skill(target_position)
		PlayerState.SKILL_CASTING:
			# 技能释放中，忽略输入
			return false
	
	return false

func handle_right_click(_target_position: Vector2) -> bool:
	"""处理鼠标右键点击"""
	match current_state:
		PlayerState.IDLE:
			# 空闲状态，执行普攻
			return false  # 返回false表示没有处理，让玩家执行普攻
		PlayerState.SKILL_SELECTED, PlayerState.SKILL_TARGETING:
			# 技能选中状态，取消技能
			cancel_skill_selection()
			return true
		PlayerState.SKILL_CASTING:
			# 技能释放中，忽略输入
			return true
	
	return false

func handle_escape_key() -> bool:
	"""处理ESC键"""
	if current_state != PlayerState.IDLE:
		cancel_skill_selection()
		return true
	return false

## ========== 查询方法 ==========

func is_idle() -> bool:
	"""是否处于空闲状态"""
	return current_state == PlayerState.IDLE

func is_selecting_skill() -> bool:
	"""是否正在选择技能"""
	return current_state in [PlayerState.SKILL_SELECTED, PlayerState.SKILL_TARGETING]

func is_casting_skill() -> bool:
	"""是否正在释放技能"""
	return current_state == PlayerState.SKILL_CASTING

func get_selected_skill():
	"""获取当前选中的技能"""
	return selected_skill

func get_selected_skill_slot() -> int:
	"""获取当前选中的技能槽位"""
	return selected_skill_slot
