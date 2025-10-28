class_name MeteorSkill
extends SkillBase

# 💥 范围轰炸 - AOE技能

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "meteor"
	skill_name = "范围轰炸"
	cooldown = 6.0
	mana_cost = 40
	max_range = 400.0  # 400像素射程限制
	skill_radius = 150.0  # 150像素AOE范围
	skill_color = Color.ORANGE
	description = "在目标区域造成范围伤害"
	cast_type = SkillCastType.TARGET_AREA

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行范围轰炸效果"""
	print("💥 释放范围轰炸到: ", target_position)
	
	# 创建爆炸效果
	var explosion = create_skill_effect("aoe", target_position)
	explosion.skill_radius = skill_radius
	explosion.damage = 120
	explosion.life_time = 2.0
	
	# 对范围内敌人造成伤害
	var enemies = find_enemies_in_area(target_position, skill_radius)
	var hit_count = 0
	
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(120)
			hit_count += 1
	
	print("💥 范围轰炸命中 ", hit_count, " 个敌人，造成 120 点伤害")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "aoe"
	return info
