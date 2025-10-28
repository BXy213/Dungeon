class_name SnipeSkill
extends SkillBase

# 🎯 精准射击 - 目标敌人技能

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "snipe"
	skill_name = "精准射击"
	cooldown = 3.5
	mana_cost = 25
	max_range = 500.0
	skill_color = Color.PURPLE
	description = "精准射击敌人"
	cast_type = SkillCastType.TARGET_ENEMY

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行精准射击效果"""
	if not is_position_in_range(target_position):
		print("🎯 精准射击目标超出射程!")
		return
	
	print("🎯 释放精准射击到: ", target_position)
	
	# 寻找目标敌人
	var target_enemy = find_closest_enemy(target_position, 50.0)
	
	if target_enemy and target_enemy.has_method("take_damage"):
		target_enemy.take_damage(100)
		
		# 创建射击效果
		var snipe_effect = create_skill_effect("targeted", target_enemy.global_position)
		snipe_effect.damage = 100
		snipe_effect.life_time = 0.8
		
		print("🎯 精准射击命中 ", target_enemy.name, "! 造成 100 点伤害")
	else:
		print("🎯 没有找到可攻击的目标!")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "targeted"
	return info
