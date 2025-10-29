class_name FireballSkill
extends SkillBase

# 🔥 火球术 - 投射物技能

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "fireball"
	skill_name = "火球术"
	cooldown = 2.0
	mana_cost = 15
	max_range = 0.0  # 无射程限制
	skill_color = Color.RED
	description = "发射火球，造成增幅伤害并获得3秒伤害加成"
	cast_type = SkillCastType.TARGET_GROUND

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行火球术效果"""
	print("🔥 释放火球术到: ", target_position)
	
	# 基础伤害
	var base_damage = 50
	var damage_boost_strength = 0.5  # 50%伤害增幅
	
	# 先给玩家施加3秒伤害增幅buff
	if player and player.has_node("BuffSystem"):
		var buff_system = player.get_node("BuffSystem")
		buff_system.apply_buff(BuffSystem.BuffType.DAMAGE_BOOST, 3.0, damage_boost_strength, player)
		print("  🔥 玩家获得伤害增幅buff (50%, 3秒)")
	
	# 计算增幅后的伤害（本次攻击也吃到加成）
	var boosted_damage = int(base_damage * (1.0 + damage_boost_strength))
	
	# 创建火球投射物
	var fireball = create_skill_effect("projectile", player.global_position)
	fireball.direction = (target_position - player.global_position).normalized()
	fireball.speed = 400.0
	fireball.damage = boosted_damage  # 使用增幅后的伤害
	fireball.max_distance = 600.0
	fireball.life_time = 3.0
	
	print("  🔥 火球伤害: ", base_damage, " → ", boosted_damage, " (增幅 ", int(damage_boost_strength * 100), "%)")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "projectile"
	return info
