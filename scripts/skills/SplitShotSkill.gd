class_name SplitShotSkill
extends SkillBase

# 🏹 分裂箭 - 向多个敌人发射弹道（参考DOTA美杜莎）

# 可配置参数
@export var damage_multiplier: float = 1.0  # 伤害倍率（基于玩家攻击力）
@export var max_targets: int = 5  # 最大目标数
@export var search_radius: float = 400.0  # 搜索范围

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "split_shot"
	skill_name = "分裂箭"
	cooldown = 8.0
	mana_cost = 50
	max_range = 0.0  # 无射程限制（自动选择目标）
	skill_color = Color(0.9, 0.7, 0.2)  # 金色
	description = "向范围内最多5个敌人发射弹道"
	cast_type = SkillCastType.AUTO_CAST

func execute_skill_effect(_target_position: Vector2, _target_node: Node) -> void:
	"""执行分裂箭效果"""
	print("🏹 释放分裂箭")
	
	if not player:
		return
	
	# 查找范围内的敌人
	var enemies = find_enemies_in_area(player.global_position, search_radius)
	
	if enemies.is_empty():
		print("🏹 范围内没有敌人!")
		return
	
	# 限制目标数量
	var targets = enemies.slice(0, min(max_targets, enemies.size()))
	
	# 计算技能伤害
	var player_attack = player.current_attack_damage if player else 10
	var skill_damage = int(player_attack * damage_multiplier)
	
	# 对每个目标发射弹道
	for i in range(targets.size()):
		var target = targets[i]
		
		# 创建弹道
		var projectile = create_skill_effect("projectile", player.global_position)
		projectile.direction = (target.global_position - player.global_position).normalized()
		projectile.speed = 600.0
		projectile.damage = skill_damage
		projectile.max_distance = 800.0
		projectile.life_time = 2.0
		projectile.modulate = Color(0.9, 0.7, 0.2, 0.8)
		
		# ✅ 立即初始化所有箭矢（移除await以避免阻塞技能系统）
		projectile.initialize()
	
	print("  🏹 分裂箭发射! 目标数: ", targets.size(), ", 每箭伤害: ", skill_damage)

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "auto"
	return info

