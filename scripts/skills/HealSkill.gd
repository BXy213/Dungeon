class_name HealSkill
extends SkillBase

# 💚 治疗术 - 范围治疗技能

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "heal"
	skill_name = "治疗术"
	cooldown = 5.0
	mana_cost = 25
	max_range = 200.0
	skill_radius = 80.0  # 80像素的治疗光环范围
	skill_color = Color.GREEN
	description = "治疗玩家"
	cast_type = SkillCastType.TARGET_GROUND

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行治疗术效果"""
	if not is_position_in_range(target_position):
		print("💚 治疗术目标超出范围!")
		return
	
	print("💚 释放治疗术到: ", target_position)
	
	# 创建治疗效果
	var heal_effect = create_skill_effect("heal", target_position)
	heal_effect.life_time = 1.0
	
	# 治疗玩家
	if player and player.has_method("heal"):
		player.heal(100)
		print("💚 治疗术释放! 恢复 100 点生命值")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "heal"
	return info
