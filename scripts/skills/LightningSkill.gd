class_name LightningSkill
extends SkillBase

# ⚡ 闪电链 - 瞬发技能

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "lightning"
	skill_name = "闪电链"
	cooldown = 4.0
	mana_cost = 30
	max_range = 300.0
	skill_radius = 120.0  # 120像素的搜索范围
	skill_color = Color.YELLOW
	description = "瞬发闪电，攻击范围内敌人"
	cast_type = SkillCastType.TARGET_GROUND

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行闪电链效果"""
	if not is_position_in_range(target_position):
		print("⚡ 闪电链目标超出范围!")
		return
	
	print("⚡ 释放闪电链到: ", target_position)
	
	# 寻找目标位置最近的敌人
	var target_enemy = find_closest_enemy(target_position, 100.0)
	
	if target_enemy and target_enemy.has_method("take_damage"):
		target_enemy.take_damage(80)
		
		# 创建闪电效果
		var lightning = create_skill_effect("instant", target_enemy.global_position)
		lightning.damage = 80
		lightning.life_time = 0.5
		
		print("⚡ 闪电链命中 ", target_enemy.name, "! 造成 80 点伤害")
	else:
		print("⚡ 范围内没有敌人!")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "instant"
	return info
