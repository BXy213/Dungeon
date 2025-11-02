class_name MeteorSkill
extends SkillBase

# 💥 陨石术 - AOE技能

# 可配置参数
@export var damage_multiplier: float = 2.5  # 伤害倍率（基于玩家攻击力）

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "meteor"
	skill_name = "陨石术"
	cooldown = 8.0
	mana_cost = 40
	max_range = 400.0  # 400像素射程限制
	skill_radius = 150.0  # 150像素AOE范围
	skill_color = Color.ORANGE
	description = "在目标区域造成范围伤害"
	cast_type = SkillCastType.TARGET_AREA

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行陨石术效果"""
	print("💥 释放陨石术到: ", target_position)
	
	# 计算技能伤害（基于玩家攻击力）
	var player_attack = player.current_attack_damage if player else 10
	var skill_damage = int(player_attack * damage_multiplier)
	
	# 创建爆炸效果
	var explosion = create_skill_effect("aoe", target_position)
	explosion.skill_radius = skill_radius
	explosion.damage = skill_damage
	explosion.life_time = 2.0
	explosion.initialize()  # ✅ 初始化
	
	# 对范围内敌人造成伤害
	var enemies = find_enemies_in_area(target_position, skill_radius)
	var hit_count = 0
	
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(skill_damage, player)
			hit_count += 1
	
	print("  💥 陨石术伤害: ", player_attack, " × ", damage_multiplier, " = ", skill_damage, ", 命中 ", hit_count, " 个敌人")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "aoe"
	return info
