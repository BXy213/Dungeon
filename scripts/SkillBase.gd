class_name SkillBase
extends RefCounted

# 🎯 技能基类 - 所有技能的通用属性和接口

## 技能基础属性
@export var skill_id: String = ""
@export var skill_name: String = ""
@export var cooldown: float = 0.0
@export var mana_cost: int = 0
@export var max_range: float = 0.0  # 最大选择射程，0表示无限制
@export var skill_radius: float = 0.0  # 技能作用范围半径，0或负数表示无范围显示
@export var skill_color: Color = Color.WHITE
@export var icon_path: String = ""
@export var description: String = ""

## 技能行为类型
enum SkillCastType {
	AUTO_CAST,      # 自动释放（按键即释放）
	TARGET_GROUND,  # 目标地面点击
	TARGET_ENEMY,   # 目标敌人点击
	TARGET_AREA     # 目标区域选择
}

@export var cast_type: SkillCastType = SkillCastType.TARGET_GROUND

## 技能状态
var is_on_cooldown: bool = false
var cooldown_timer: Timer

# 引用
var player: Node = null
var skill_manager: Node = null

func _init(p_player: Node = null, p_skill_manager: Node = null):
	player = p_player
	skill_manager = p_skill_manager
	setup_cooldown_timer()

func setup_cooldown_timer():
	"""设置冷却计时器"""
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.timeout.connect(_on_cooldown_finished)

func _on_cooldown_finished():
	"""冷却完成回调"""
	is_on_cooldown = false
	print(skill_name, " 冷却完成!")

## ========== 核心接口 ==========
## 子类必须重写这些方法

func can_cast() -> bool:
	"""检查是否可以释放技能"""
	if is_on_cooldown:
		print(skill_name, " 冷却中!")
		return false
	
	if player and player.mana < mana_cost:
		print("魔法值不足! ", skill_name, " 需要 ", mana_cost, " 点魔法")
		return false
	
	return true

func on_skill_selected() -> void:
	"""技能被选中时调用（进入技能特定状态）"""
	print("选择技能: ", skill_name)
	# 子类重写实现特定逻辑

func on_skill_deselected() -> void:
	"""技能被取消选择时调用"""
	print("取消技能: ", skill_name)
	# 子类重写清理逻辑

func cast_skill(target_position: Vector2 = Vector2.ZERO, target_node: Node = null) -> bool:
	"""释放技能 - 子类重写实现具体效果"""
	if not can_cast():
		return false
	
	# 消耗魔法
	if player:
		player.use_mana(mana_cost)
	
	# 开始冷却
	start_cooldown()
	
	# 子类实现具体效果
	execute_skill_effect(target_position, target_node)
	
	return true

func execute_skill_effect(_target_position: Vector2, _target_node: Node) -> void:
	"""执行技能效果 - 子类必须重写"""
	print("技能 ", skill_name, " 释放! (基类默认实现)")

func get_skill_indicator_info() -> Dictionary:
	"""获取技能指示器信息 - 子类可重写自定义指示器"""
	return {
		"type": get_cast_type_string(),
		"color": skill_color,
		"range": max_range,
		"radius": skill_radius  # 通用的技能作用范围
	}

func get_cast_type_string() -> String:
	"""获取释放类型字符串"""
	match cast_type:
		SkillCastType.AUTO_CAST:
			return "auto"
		SkillCastType.TARGET_GROUND:
			return "ground"
		SkillCastType.TARGET_ENEMY:
			return "targeted"
		SkillCastType.TARGET_AREA:
			return "aoe"
		_:
			return "ground"

func start_cooldown() -> void:
	"""开始冷却"""
	if cooldown > 0:
		is_on_cooldown = true
		cooldown_timer.wait_time = cooldown
		
		# 将计时器添加到场景树（如果还没有父节点的话）
		if player and not cooldown_timer.get_parent():
			player.add_child(cooldown_timer)
		cooldown_timer.start()

func get_cooldown_remaining() -> float:
	"""获取剩余冷却时间"""
	if is_on_cooldown and cooldown_timer:
		return cooldown_timer.time_left
	return 0.0

## ========== 工具方法 ==========

func is_position_in_range(target_position: Vector2) -> bool:
	"""检查目标位置是否在射程内"""
	if max_range <= 0:
		return true  # 无射程限制
	
	if player:
		var distance = player.global_position.distance_to(target_position)
		return distance <= max_range
	
	return true

func create_skill_effect(effect_type: String, position: Vector2) -> Node:
	"""创建技能效果节点"""
	var effect = preload("res://Scenes/SkillEffect.tscn").instantiate()
	effect.global_position = position
	effect.modulate = skill_color
	effect.skill_type = effect_type
	effect.source = player  # 设置技能来源为玩家
	
	# 添加到技能效果容器
	var skill_effects = player.get_tree().current_scene.get_node_or_null("SkillEffects")
	if skill_effects:
		skill_effects.add_child(effect)
	else:
		player.get_tree().current_scene.add_child(effect)
	
	return effect

func find_enemies_in_area(center: Vector2, radius: float) -> Array:
	"""查找区域内的敌人"""
	var enemies = player.get_tree().get_nodes_in_group("enemies")
	var targets = []
	
	for enemy in enemies:
		if enemy.visible and enemy.get_parent().get_parent().visible:
			var distance = center.distance_to(enemy.global_position)
			if distance <= radius:
				targets.append(enemy)
	
	return targets

func find_closest_enemy(position: Vector2, max_distance: float = 50.0) -> Node:
	"""查找最近的敌人"""
	var enemies = player.get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var closest_distance = max_distance
	
	for enemy in enemies:
		if enemy.visible and enemy.get_parent().get_parent().visible:
			var distance = position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	
	return closest_enemy
