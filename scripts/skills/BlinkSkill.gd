class_name BlinkSkill
extends SkillBase

# ⚡ 闪现 - 短距离瞬移（参考LOL闪现/DOTA闪烁匕首）

# 可配置参数
@export var blink_distance: float = 300.0  # 闪现距离

func _init(p_player: Node = null, p_skill_manager: Node = null):
	super._init(p_player, p_skill_manager)
	
	# 设置技能属性
	skill_id = "blink"
	skill_name = "闪现"
	cooldown = 15.0  # 较长CD
	mana_cost = 40
	max_range = blink_distance
	skill_color = Color(0.8, 0.3, 1.0)  # 紫色
	description = "瞬移到目标位置，最大距离300像素"
	cast_type = SkillCastType.TARGET_GROUND

func execute_skill_effect(target_position: Vector2, _target_node: Node) -> void:
	"""执行闪现效果"""
	print("⚡ 释放闪现到: ", target_position)
	
	if not player:
		return
	
	# 计算实际闪现位置（不超过最大距离）
	var direction = (target_position - player.global_position).normalized()
	var distance = min(player.global_position.distance_to(target_position), blink_distance)
	var blink_target = player.global_position + direction * distance
	
	# 创建起始位置特效
	var start_effect = create_skill_effect("instant", player.global_position)
	start_effect.life_time = 0.3
	start_effect.modulate = Color(0.8, 0.3, 1.0, 0.8)
	start_effect.initialize()
	
	# 瞬移玩家
	player.global_position = blink_target
	
	# 创建到达位置特效
	var end_effect = create_skill_effect("instant", blink_target)
	end_effect.life_time = 0.3
	end_effect.modulate = Color(0.8, 0.3, 1.0, 0.8)
	end_effect.initialize()
	
	print("  ⚡ 闪现成功! 距离: ", distance, " 像素")

func get_skill_indicator_info() -> Dictionary:
	var info = super.get_skill_indicator_info()
	info["type"] = "blink"
	return info

