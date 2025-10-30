class_name DrainLifeSkill
extends SkillBase

# 🧛 生命汲取 - 伤害敌人并回复自身（参考DOTA死灵法师/LOL吸血鬼）

# 可配置参数
@export var damage_multiplier: float = 1.8  # 伤害倍率
@export var lifesteal_percent: float = 0.5  # 生命偷取比例（50%）
@export var search_radius: float = 150.0  # 搜索范围

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "drain_life"
	skill_name = "生命汲取"
	cooldown = 5.0
	mana_cost = 30
	max_range = 400.0
	skill_radius = search_radius
	skill_color = Color(0.6, 0.0, 0.6)  # 深紫色
	description = "汲取敌人生命，造成伤害并恢复自身"
	cast_type = SkillCastType.TARGET_GROUND

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行生命汲取效果"""
	print("🧛 释放生命汲取到: ", target_position)
	
	if not is_position_in_range(target_position):
		print("🧛 目标超出射程!")
		return
	
	# 计算技能伤害
	var player_attack = player.current_attack_damage if player else 10
	var skill_damage = int(player_attack * damage_multiplier)
	
	# 查找目标位置附近的敌人
	var enemies = find_enemies_in_area(target_position, search_radius)
	
	if enemies.is_empty():
		print("🧛 范围内没有敌人!")
		return
	
	# 选择最近的敌人
	var target_enemy = enemies[0]
	var min_distance = target_position.distance_to(target_enemy.global_position)
	for enemy in enemies:
		var dist = target_position.distance_to(enemy.global_position)
		if dist < min_distance:
			min_distance = dist
			target_enemy = enemy
	
	# 造成伤害
	if target_enemy.has_method("take_damage"):
		target_enemy.take_damage(skill_damage, player)
		print("  🧛 生命汲取命中 ", target_enemy.name, "! 造成 ", skill_damage, " 点伤害")
		
		# 回复生命值
		var heal_amount = int(skill_damage * lifesteal_percent)
		if player.has_method("heal"):
			player.heal(heal_amount)
			print("  💚 汲取生命，回复 ", heal_amount, " 点生命值")
		
		# 创建汲取特效（从敌人到玩家的连线）
		create_drain_effect(target_enemy.global_position, player.global_position)

func create_drain_effect(from_pos: Vector2, to_pos: Vector2) -> void:
	"""创建生命汲取特效"""
	# 创建起点特效
	var drain_effect = create_skill_effect("targeted", from_pos)
	drain_effect.damage = 0
	drain_effect.life_time = 0.8
	drain_effect.modulate = Color(0.6, 0.0, 0.6, 0.8)
	drain_effect.initialize()
	
	# TODO: 可以添加Line2D实现连线特效

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "aoe"
	return info

