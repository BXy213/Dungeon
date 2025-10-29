class_name IceSpikeSkill
extends SkillBase

# ❄️ 冰锥术 - 投射物技能

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "ice_spike"
	skill_name = "冰锥术"
	cooldown = 3.0
	mana_cost = 20
	max_range = 0.0  # 无射程限制
	skill_color = Color.CYAN
	description = "发射冰锥，造成伤害并减速敌人3秒"
	cast_type = SkillCastType.TARGET_GROUND

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行冰锥术效果"""
	print("❄️ 释放冰锥术到: ", target_position)
	
	# 创建冰锥投射物
	var ice_spike = create_skill_effect("projectile", player.global_position)
	ice_spike.direction = (target_position - player.global_position).normalized()
	ice_spike.speed = 500.0
	ice_spike.damage = 40
	ice_spike.max_distance = 600.0
	ice_spike.life_time = 3.0
	
	# 设置命中时的减速buff（50%减速，持续3秒）
	ice_spike.on_hit_buff_type = BuffSystem.BuffType.SLOW
	ice_spike.on_hit_buff_duration = 3.0
	ice_spike.on_hit_buff_strength = 0.5  # 50%减速

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "projectile"
	return info
