class_name FireballSkill
extends SkillBase

# 🔥 火球术 - 投射物技能

# 可配置参数
@export var damage_multiplier: float = 1.5  # 伤害倍率（基于玩家攻击力）
@export var damage_boost_strength: float = 0.5  # 伤害增幅强度（50%）
@export var damage_boost_duration: float = 3.0  # 伤害增幅持续时间
@export var projectile_width: float = 0.0  # 弹道宽度（0表示使用默认圆形碰撞盒）

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
	
	# ✅ 先给玩家施加伤害增幅buff（这样本次攻击也能吃到加成）
	if player and player.has_node("BuffSystem"):
		var buff_system = player.get_node("BuffSystem")
		buff_system.apply_buff(BuffSystem.BuffType.DAMAGE_BOOST, damage_boost_duration, damage_boost_strength, player)
		print("  🔥 玩家获得伤害增幅buff (", int(damage_boost_strength * 100), "%, ", damage_boost_duration, "秒)")
	
	# ✅ 再获取玩家当前攻击力（已包含buff加成）
	var player_attack = player.current_attack_damage if player else 10
	var skill_damage = int(player_attack * damage_multiplier)
	
	# 创建火球投射物
	var fireball = create_skill_effect("projectile", player.global_position)
	fireball.direction = (target_position - player.global_position).normalized()
	fireball.speed = 400.0
	fireball.damage = skill_damage  # 基于玩家攻击力的倍率伤害
	fireball.max_distance = 600.0
	fireball.skill_width = projectile_width  # 设置弹道宽度
	fireball.life_time = 3.0
	
	# ✅ 在设置完所有属性后初始化
	fireball.initialize()
	
	print("  🔥 火球伤害: ", player_attack, " × ", damage_multiplier, " = ", skill_damage)

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "projectile"
	return info
