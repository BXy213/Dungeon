extends Node

# 📋 Buff系统使用示例

func _ready():
	example_buff_usage()

func example_buff_usage():
	"""演示Buff系统的使用方法"""
	
	print("=== Buff系统使用示例 ===")
	
	# 创建一个角色（这里用假设的角色）
	var CharacterBaseClass = preload("res://scripts/CharacterBase.gd")
	var character = CharacterBaseClass.new()
	character.character_name = "测试角色"
	add_child(character)
	
	# 等待角色初始化完成
	await get_tree().process_frame
	
	# 1. 应用单个Buff
	print("\n1. 应用减速Buff")
	character.buff_system.apply_buff(0, 5.0, 0.5)  # SLOW - 减速50%，持续5秒
	
	# 2. 应用多个Buff
	print("\n2. 应用多个Buff")
	character.buff_system.apply_buff(2, 8.0, 2.0)   # POISON - 中毒，每秒10点伤害，持续8秒
	character.buff_system.apply_buff(4, 10.0, 1.5)  # STRENGTHEN - 攻击力提升50%，持续10秒
	
	# 3. 检查Buff状态
	print("\n3. 检查Buff状态")
	print("是否有减速Buff: ", character.buff_system.has_buff(0))  # SLOW
	print("减速强度: ", character.buff_system.get_buff_strength(0))  # SLOW
	print("当前Buff数量: ", character.buff_system.get_all_buffs().size())
	
	# 4. 按分类获取Buff
	print("\n4. 按分类获取Buff")
	var debuffs = character.buff_system.get_buffs_by_category(0)  # DEBUFF
	var buffs = character.buff_system.get_buffs_by_category(1)   # BUFF
	print("负面Buff数量: ", debuffs.size())
	print("正面Buff数量: ", buffs.size())
	
	# 5. Buff叠加演示
	print("\n5. Buff叠加演示")
	character.buff_system.apply_buff(2, 5.0, 1.0)  # POISON - 再次应用中毒，会叠加
	print("叠加后中毒强度: ", character.buff_system.get_buff_strength(2))  # POISON
	
	# 6. 清除特定类型的Buff
	print("\n6. 清除负面Buff")
	await get_tree().create_timer(2.0).timeout
	character.buff_system.clear_buffs_by_category(0)  # DEBUFF
	print("清除后Buff数量: ", character.buff_system.get_all_buffs().size())
	
	# 7. 清除所有Buff
	print("\n7. 清除所有Buff")
	await get_tree().create_timer(1.0).timeout
	character.buff_system.clear_all_buffs()
	print("最终Buff数量: ", character.buff_system.get_all_buffs().size())

## ========== 实际游戏场景中的Buff应用示例 ==========

func example_skill_with_buff():
	"""技能释放时应用Buff的示例"""
	
	# 假设这是一个技能效果函数
	var caster = get_player()
	var target = get_enemy()
	
	if caster and target:
		# 火球术：造成伤害并点燃目标
		target.take_damage(50)
		target.buff_system.apply_buff(2, 3.0, 1.0)  # POISON - 燃烧3秒
		
		print("🔥 火球术命中！目标被点燃3秒")

func example_item_with_buff():
	"""物品使用时应用Buff的示例"""
	
	var player = get_player()
	
	if player:
		# 力量药水：提升攻击力
		player.buff_system.apply_buff(4, 30.0, 2.0)  # STRENGTHEN - 攻击力翻倍，持续30秒
		
		# 治疗药水：持续回血
		player.buff_system.apply_buff(6, 15.0, 3.0)  # REGENERATION - 每秒回复60点生命，持续15秒
		
		print("💉 使用了力量药水和治疗药水")

func example_area_effect():
	"""区域效果Buff的示例"""
	
	var enemies_in_area = get_enemies_in_area(Vector2.ZERO, 200.0)
	
	for enemy in enemies_in_area:
		# 冰霜新星：减速所有敌人
		enemy.buff_system.apply_buff(0, 4.0, 0.7)  # SLOW - 减速30%，持续4秒
		
		# 沉默法阵：禁止技能释放
		enemy.buff_system.apply_buff(3, 6.0, 1.0)  # SILENCE - 沉默6秒
	
	print("❄️ 冰霜新星释放！敌人被减速和沉默")

## ========== 辅助方法 ==========

func get_player() -> CharacterBase:
	"""获取玩家（示例）"""
	return get_tree().get_first_node_in_group("players")

func get_enemy() -> CharacterBase:
	"""获取敌人（示例）"""
	return get_tree().get_first_node_in_group("enemies")

func get_enemies_in_area(center: Vector2, radius: float) -> Array:
	"""获取区域内的敌人（示例）"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	var enemies_in_area = []
	
	for enemy in enemies:
		if enemy.global_position.distance_to(center) <= radius:
			enemies_in_area.append(enemy)
	
	return enemies_in_area
