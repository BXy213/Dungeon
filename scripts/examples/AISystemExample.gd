extends Node

# 🤖 AI系统使用示例

func _ready():
	example_ai_usage()

func example_ai_usage():
	"""演示AI系统的使用方法"""
	
	print("=== AI系统使用示例 ===")
	
	await get_tree().create_timer(1.0).timeout
	
	# 1. 创建不同类型的敌人
	create_different_ai_enemies()
	
	await get_tree().create_timer(2.0).timeout
	
	# 2. 动态改变AI行为
	demonstrate_ai_switching()
	
	await get_tree().create_timer(2.0).timeout
	
	# 3. AI配置和调试
	demonstrate_ai_configuration()

func create_different_ai_enemies():
	"""创建不同AI类型的敌人"""
	
	print("\n1. 创建不同AI类型的敌人")
	
	# 攻击型敌人
	var EnemyCharacterClass = preload("res://scripts/EnemyCharacter.gd")
	var aggressive_enemy = EnemyCharacterClass.create_enemy(Vector2i(0, 0), EnemyCharacterClass.EnemyType.MELEE_SOLDIER)
	aggressive_enemy.position = Vector2(100, 100)
	add_child(aggressive_enemy)
	print("创建攻击型近战士兵")
	
	# 防御型敌人
	var defensive_enemy = EnemyCharacterClass.create_enemy(Vector2i(0, 0), EnemyCharacterClass.EnemyType.RANGED_SOLDIER)
	defensive_enemy.position = Vector2(200, 100)
	add_child(defensive_enemy)
	print("创建远程士兵")
	
	# 精英敌人
	var passive_enemy = EnemyCharacterClass.create_enemy(Vector2i(0, 0), EnemyCharacterClass.EnemyType.ELITE_MELEE)
	passive_enemy.position = Vector2(300, 100)
	add_child(passive_enemy)
	print("创建精英哥布林")

func demonstrate_ai_switching():
	"""演示AI行为切换"""
	
	print("\n2. 动态改变AI行为")
	
	var enemy = get_tree().get_first_node_in_group("enemies")
	if enemy and enemy.has_method("set_ai_type"):
		print("原AI类型: ", enemy.get_ai_type_name())
		
		# 切换为狂暴型
		enemy.set_ai_type(3)  # BERSERKER
		print("切换为狂暴型AI")
		
		await get_tree().create_timer(3.0).timeout
		
		# 切换为支援型
		enemy.set_ai_type(4)  # SUPPORT
		print("切换为支援型AI")

func demonstrate_ai_configuration():
	"""演示AI配置"""
	
	print("\n3. AI配置和调试")
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy and enemy.ai_controller:
			var ai = enemy.ai_controller
			
			# 配置AI参数
			ai.detection_range = 400.0      # 增加检测范围
			ai.aggression_level = 1.5       # 提高攻击性
			# ai.intelligence_level = 2.0   # 智能程度（如果有此属性）
			# ai.reaction_time = 0.3        # 反应速度（如果有此属性）
			
			print("配置敌人AI: ", enemy.character_name)

## ========== 自定义AI行为示例 ==========

class CustomAI extends "res://scripts/AI/AIBase.gd":
	"""自定义AI示例"""
	
	func _init(character: Node = null):
		super._init(character)
		ai_type = 1 as AIType  # AGGRESSIVE
		ai_name = "自定义AI"
		
		# 自定义配置
		detection_range = 500.0
		aggression_level = 1.8
	
	func execute_attack_behavior() -> void:
		"""自定义攻击行为"""
		super.execute_attack_behavior()
		
		# 攻击时有概率使用特殊技能
		if randf() < 0.1 and owner_character:
			# 10%概率使用加速技能
			owner_character.cast_speed_boost()
		
		if randf() < 0.2 and current_target:
			# 20%概率使用毒攻击
			owner_character.cast_poison_attack(current_target)

func create_custom_ai_enemy():
	"""创建使用自定义AI的敌人"""
	
	var EnemyCharacterClass = preload("res://scripts/EnemyCharacter.gd")
	var enemy = EnemyCharacterClass.new()
	enemy.character_name = "精英哥布林"
	enemy.position = Vector2(400, 200)
	
	# 移除默认AI
	if enemy.ai_controller:
		enemy.ai_controller.queue_free()
	
	# 添加自定义AI
	var custom_ai = CustomAI.new(enemy)
	enemy.add_child(custom_ai)
	enemy.ai_controller = custom_ai
	
	add_child(enemy)
	print("创建使用自定义AI的精英哥布林")

## ========== AI状态监控示例 ==========

func monitor_ai_states():
	"""监控AI状态"""
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	print("\n=== AI状态监控 ===")
	for enemy in enemies:
		if enemy and enemy.ai_controller:
			var info = enemy.get_debug_info()
			print(enemy.character_name, ":")
			print("  状态: ", info.state)
			print("  AI状态: ", info.ai_state)
			print("  AI类型: ", info.ai_type)
			print("  位置: ", info.position)
			print("  血量: ", info.health)

func _input(event: InputEvent):
	"""输入处理 - 用于测试"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				create_custom_ai_enemy()
			KEY_2:
				monitor_ai_states()
			KEY_3:
				demonstrate_ai_buff_interaction()

func demonstrate_ai_buff_interaction():
	"""演示AI与Buff系统的交互"""
	
	print("\n=== AI与Buff系统交互 ===")
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy and enemy.buff_system:
			# 给敌人添加一些Buff
			enemy.buff_system.apply_buff(8, 5.0, 1.5)  # SPEED_BOOST
			enemy.buff_system.apply_buff(4, 8.0, 1.3)  # STRENGTHEN
			
			print("为 ", enemy.character_name, " 添加加速和强化Buff")
			
			# AI会根据Buff状态调整行为
			if enemy.ai_controller:
				# 有加速Buff时AI可能更加激进
				enemy.ai_controller.aggression_level *= 1.2
