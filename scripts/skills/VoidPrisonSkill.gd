class_name VoidPrisonSkill
extends SkillBase

# 🌌 虚空牢笼 - 定点眩晕区域（参考LOL维克兹/虚空之眼）

# 可配置参数
@export var damage_multiplier: float = 1.5  # 伤害倍率（基于玩家攻击力）
@export var prison_radius: float = 150.0  # 牢笼范围
@export var stun_duration: float = 2.5  # 眩晕持续时间
@export var delay: float = 0.8  # 延迟触发时间（给敌人反应时间）

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "void_prison"
	skill_name = "虚空牢笼"
	cooldown = 18.0
	mana_cost = 70
	max_range = 600.0
	skill_radius = prison_radius
	skill_color = Color(0.5, 0.0, 0.8)  # 深紫色
	description = "延迟0.8秒后眩晕区域内所有敌人2.5秒"
	cast_type = SkillCastType.TARGET_AREA

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行虚空牢笼效果"""
	print("🌌 释放虚空牢笼到: ", target_position)
	
	if not is_position_in_range(target_position):
		print("🌌 目标超出射程!")
		return
	
	# 创建预警圈（延迟触发前的视觉提示）
	var warning_circle = create_skill_effect("aoe", target_position)
	warning_circle.skill_radius = prison_radius
	warning_circle.life_time = delay
	warning_circle.modulate = Color(0.5, 0.0, 0.8, 0.3)  # 半透明紫色预警
	warning_circle.initialize()
	
	print("  🌌 虚空牢笼预警中... ", delay, " 秒后触发")
	
	# 延迟触发
	await player.get_tree().create_timer(delay).timeout
	
	# 计算技能伤害
	var player_attack = player.current_attack_damage if player else 10
	var skill_damage = int(player_attack * damage_multiplier)
	
	# 创建触发效果
	var prison_effect = create_skill_effect("aoe", target_position)
	prison_effect.skill_radius = prison_radius
	prison_effect.damage = 0  # 不直接造成伤害，通过take_damage实现
	prison_effect.life_time = stun_duration
	prison_effect.modulate = Color(0.5, 0.0, 0.8, 0.6)
	prison_effect.initialize()
	
	# 查找范围内的敌人
	var enemies = find_enemies_in_area(target_position, prison_radius)
	var hit_count = 0
	
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(skill_damage, player)
			hit_count += 1
			
			# 施加眩晕buff
			if enemy.has_node("BuffSystem"):
				var buff_system = enemy.get_node("BuffSystem")
				buff_system.apply_buff(BuffSystem.BuffType.STUN, stun_duration, 1.0, player)
	
	print("  🌌 虚空牢笼触发! 伤害: ", skill_damage, ", 眩晕: ", stun_duration, " 秒, 命中 ", hit_count, " 个敌人")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "aoe"
	return info

