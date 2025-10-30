class_name PoisonShotSkill
extends SkillBase

# 🧪 剧毒射击 - 发射带毒弹道

# 可配置参数
@export var damage_multiplier: float = 0.8  # 伤害倍率（基于玩家攻击力）
@export var poison_duration: float = 5.0  # 中毒持续时间
@export var poison_strength: float = 2.0  # 中毒强度（每0.5秒造成 strength * 5 伤害）
@export var projectile_width: float = 0.0  # 弹道宽度（0表示使用默认圆形碰撞盒）

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "poison_shot"
	skill_name = "剧毒射击"
	cooldown = 6.0
	mana_cost = 35
	max_range = 0.0  # 无射程限制
	skill_color = Color(0.4, 0.8, 0.2)  # 绿色
	description = "发射毒弹，使敌人中毒5秒"
	cast_type = SkillCastType.TARGET_GROUND

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行剧毒射击效果"""
	print("🧪 释放剧毒射击到: ", target_position)
	
	# 计算技能伤害（基于玩家攻击力）
	var player_attack = player.current_attack_damage if player else 10
	var skill_damage = int(player_attack * damage_multiplier)
	
	# 创建毒弹投射物
	var poison_shot = create_skill_effect("projectile", player.global_position)
	poison_shot.direction = (target_position - player.global_position).normalized()
	poison_shot.speed = 450.0
	poison_shot.damage = skill_damage
	poison_shot.max_distance = 700.0
	poison_shot.skill_width = projectile_width  # 设置弹道宽度
	poison_shot.life_time = 3.0
	poison_shot.modulate = skill_color
	
	# 设置命中时的中毒buff
	poison_shot.on_hit_buff_type = BuffSystem.BuffType.POISON
	poison_shot.on_hit_buff_duration = poison_duration
	poison_shot.on_hit_buff_strength = poison_strength
	
	# ✅ 在设置完所有属性后初始化
	poison_shot.initialize()
	
	var total_poison_damage = int(poison_strength * 5 * (poison_duration / 0.5))
	print("  🧪 剧毒射击伤害: ", player_attack, " × ", damage_multiplier, " = ", skill_damage, ", 中毒持续: ", poison_duration, "秒 (预计额外: ", total_poison_damage, " 点伤害)")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "projectile"
	return info

