class_name ChainLightningSkill
extends SkillBase

# ⚡ 闪电链 - 弹跳攻击多个敌人（参考DOTA宙斯/LOL凯南）

# 可配置参数
@export var damage_multiplier: float = 1.5  # 首个目标伤害倍率
@export var bounce_count: int = 3  # 弹跳次数
@export var bounce_range: float = 250.0  # 弹跳范围
@export var damage_reduction: float = 0.8  # 每次弹跳伤害衰减（80%）

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "chain_lightning"
	skill_name = "闪电链"
	cooldown = 8.0
	mana_cost = 50
	max_range = 500.0
	skill_color = Color(0.3, 0.6, 1.0)  # 蓝白色
	description = "释放弹跳闪电，最多弹跳3次"
	cast_type = SkillCastType.TARGET_GROUND

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行闪电链效果"""
	print("⚡ 释放闪电链到: ", target_position)
	
	if not is_position_in_range(target_position):
		print("⚡ 目标超出射程!")
		return
	
	# 查找首个目标
	var first_target = find_closest_enemy(target_position, 100.0)
	if not first_target:
		print("⚡ 没有找到目标!")
		return
	
	# 开始链式反应
	var current_damage = int(player.current_attack_damage * damage_multiplier)
	var current_target = first_target
	var hit_targets = [first_target]  # 记录已命中的目标，避免重复命中
	
	for i in range(bounce_count + 1):  # +1 因为包含首个目标
		if not current_target or not current_target.has_method("take_damage"):
			break
		
		# 造成伤害
		current_target.take_damage(current_damage, player)
		print("  ⚡ 闪电链命中 ", current_target.name, "! 造成 ", current_damage, " 点伤害 (第", i+1, "次)")
		
		# 创建闪电特效
		var lightning_effect = create_skill_effect("instant", current_target.global_position)
		lightning_effect.life_time = 0.3
		lightning_effect.modulate = Color(0.3, 0.6, 1.0, 0.9)
		lightning_effect.initialize()
		
		# 如果还有弹跳次数，查找下一个目标
		if i < bounce_count:
			var next_target = find_next_bounce_target(current_target.global_position, hit_targets)
			if next_target:
				current_target = next_target
				hit_targets.append(next_target)
				current_damage = int(current_damage * damage_reduction)  # 伤害衰减
			else:
				print("  ⚡ 没有更多弹跳目标")
				break
		else:
			break
	
	print("  ⚡ 闪电链完成! 共命中 ", hit_targets.size(), " 个目标")

func find_next_bounce_target(from_position: Vector2, exclude_targets: Array) -> Node:
	"""查找下一个弹跳目标（排除已命中的）"""
	var enemies = player.get_tree().get_nodes_in_group("enemies")
	var closest_enemy = null
	var closest_distance = bounce_range
	
	for enemy in enemies:
		if enemy in exclude_targets:
			continue  # 跳过已命中的
		
		if enemy.visible and enemy.get_parent() and enemy.get_parent().get_parent().visible:
			var distance = from_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	
	return closest_enemy

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "targeted"
	return info

