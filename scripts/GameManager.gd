extends Node

var death_panel = null
var victory_panel = null
var player = null

var is_game_paused: bool = false

# 游戏统计数据
var enemies_killed: int = 0
var total_damage_dealt: int = 0
var boss_defeated: bool = false

func _ready() -> void:
	# 延迟初始化，确保场景树完全准备好
	await get_tree().process_frame
	
	# 获取UI和玩家引用
	death_panel = get_tree().current_scene.get_node_or_null("UI/DeathPanel")
	player = get_tree().get_first_node_in_group("players")
	
	# 连接玩家死亡信号
	if player:
		player.player_died.connect(_on_player_died)
	
	# 确保死亡面板初始隐藏
	if death_panel:
		death_panel.visible = false
	
	# 创建胜利面板
	create_victory_panel()
	
	# 连接所有敌人的死亡信号来统计数据
	connect_enemy_signals()

func _on_player_died() -> void:
	pause_game()
	show_death_panel()

func on_pause_button_pressed() -> void:
	pause_game()
	show_death_panel()

func pause_game() -> void:
	is_game_paused = true
	# 暂停游戏树
	get_tree().paused = true
	print("游戏暂停")

func resume_game() -> void:
	is_game_paused = false
	# 恢复游戏树
	get_tree().paused = false
	print("游戏恢复")

func continue_game() -> void:
	print("继续游戏")
	
	# 隐藏暂停面板
	hide_death_panel()
	
	# 恢复游戏
	resume_game()

func show_death_panel() -> void:
	if death_panel:
		death_panel.visible = true

## ========== 胜利系统 ==========

func connect_enemy_signals() -> void:
	"""连接所有房间的敌人死亡信号"""
	await get_tree().process_frame
	
	var dungeon_generator = get_tree().current_scene.get_node_or_null("DungeonGenerator")
	if dungeon_generator:
		print("📊 GameManager: 开始连接房间信号，房间数: ", dungeon_generator.rooms.size())
		for room in dungeon_generator.rooms.values():
			if room:
				# 连接房间的敌人死亡信号
				if not room.enemy_died_in_room.is_connected(_on_enemy_killed):
					room.enemy_died_in_room.connect(_on_enemy_killed)
					print("  ✓ 已连接房间 ", room.room_id, " 的敌人死亡信号")
				else:
					print("  ⚠️ 房间 ", room.room_id, " 信号已连接")
	else:
		print("⚠️ GameManager: 未找到DungeonGenerator")

func _on_enemy_killed(_room_id: Vector2i, _remaining_enemies: int) -> void:
	"""敌人被击杀时的回调"""
	enemies_killed += 1
	print("📊 统计更新：已击杀 ", enemies_killed, " 个敌人，总伤害: ", total_damage_dealt)

func record_damage(damage: int) -> void:
	"""记录造成的伤害"""
	total_damage_dealt += damage
	print("📊 记录伤害: +", damage, " 总计: ", total_damage_dealt)

func _on_boss_defeated() -> void:
	"""BOSS被击败"""
	boss_defeated = true
	print("🎉 BOSS被击败！")
	print("📊 最终统计 - 击杀: ", enemies_killed, ", 伤害: ", total_damage_dealt)
	
	# 延迟显示胜利面板，让死亡动画播放完
	await get_tree().create_timer(1.0).timeout
	show_victory_panel()

func create_victory_panel() -> void:
	"""创建胜利面板"""
	var ui_root = get_tree().current_scene.get_node_or_null("UI")
	if not ui_root:
		print("⚠️ 未找到UI根节点")
		return
	
	victory_panel = Panel.new()
	victory_panel.name = "VictoryPanel"
	victory_panel.visible = false
	victory_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时也能处理
	victory_panel.z_index = 200  # 最高层级
	
	# 设置面板样式和位置
	victory_panel.custom_minimum_size = Vector2(500, 400)
	victory_panel.position = Vector2(
		(1280.0 - 500.0) / 2.0,  # 居中
		(720.0 - 400.0) / 2.0
	)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color.GOLD
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	victory_panel.add_theme_stylebox_override("panel", style)
	
	# 创建内容容器
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.custom_minimum_size = Vector2(460, 360)
	vbox.add_theme_constant_override("separation", 20)
	victory_panel.add_child(vbox)
	
	# 标题
	var title = Label.new()
	title.text = "🎉 胜利！ 🎉"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	# 副标题
	var subtitle = Label.new()
	subtitle.text = "恭喜你击败了BOSS！"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	
	# 分隔线
	var separator1 = ColorRect.new()
	separator1.custom_minimum_size = Vector2(460, 2)
	separator1.color = Color.GOLD
	vbox.add_child(separator1)
	
	# 统计信息容器
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 15)
	vbox.add_child(stats_vbox)
	
	# 击杀统计
	var kills_label = Label.new()
	kills_label.name = "KillsLabel"
	kills_label.text = "⚔️ 击杀敌人：0"
	kills_label.add_theme_font_size_override("font_size", 20)
	kills_label.add_theme_color_override("font_color", Color.WHITE)
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_vbox.add_child(kills_label)
	
	# 伤害统计
	var damage_label = Label.new()
	damage_label.name = "DamageLabel"
	damage_label.text = "💥 造成伤害：0"
	damage_label.add_theme_font_size_override("font_size", 20)
	damage_label.add_theme_color_override("font_color", Color.WHITE)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_vbox.add_child(damage_label)
	
	# 分隔线
	var separator2 = ColorRect.new()
	separator2.custom_minimum_size = Vector2(460, 2)
	separator2.color = Color.GOLD
	vbox.add_child(separator2)
	
	# 按钮容器
	var button_hbox = HBoxContainer.new()
	button_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_hbox.add_theme_constant_override("separation", 30)
	vbox.add_child(button_hbox)
	
	# 重新开始按钮
	var restart_button = Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = "🔄 重新开始"
	restart_button.custom_minimum_size = Vector2(180, 60)
	restart_button.add_theme_font_size_override("font_size", 20)
	restart_button.pressed.connect(_on_victory_restart_pressed)
	button_hbox.add_child(restart_button)
	
	# 返回主菜单按钮
	var menu_button = Button.new()
	menu_button.name = "MenuButton"
	menu_button.text = "🏠 返回主菜单"
	menu_button.custom_minimum_size = Vector2(180, 60)
	menu_button.add_theme_font_size_override("font_size", 20)
	menu_button.pressed.connect(_on_victory_menu_pressed)
	button_hbox.add_child(menu_button)
	
	ui_root.add_child(victory_panel)
	print("✅ 胜利面板创建完成")

func show_victory_panel() -> void:
	"""显示胜利面板"""
	if not victory_panel:
		print("⚠️ 胜利面板未创建")
		return
	
	# 暂停游戏
	pause_game()
	
	print("🎉 准备显示胜利面板 - 击杀:", enemies_killed, " 伤害:", total_damage_dealt)
	
	# 直接查找标签并更新
	var kills_label = find_node_by_name_recursive(victory_panel, "KillsLabel")
	var damage_label = find_node_by_name_recursive(victory_panel, "DamageLabel")
	
	if kills_label:
		kills_label.text = "⚔️ 击杀敌人：" + str(enemies_killed)
		print("  ✓ 更新击杀标签: ", kills_label.text)
	else:
		print("  ⚠️ 未找到KillsLabel")
	
	if damage_label:
		damage_label.text = "💥 造成伤害：" + str(total_damage_dealt)
		print("  ✓ 更新伤害标签: ", damage_label.text)
	else:
		print("  ⚠️ 未找到DamageLabel")
	
	# 显示面板
	victory_panel.visible = true
	print("🎉 胜利面板已显示")

func hide_victory_panel() -> void:
	"""隐藏胜利面板"""
	if victory_panel:
		victory_panel.visible = false

func find_node_by_name_recursive(node: Node, target_name: String) -> Node:
	"""递归查找子节点"""
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = find_node_by_name_recursive(child, target_name)
		if result:
			return result
	
	return null

func _on_victory_restart_pressed() -> void:
	"""胜利面板 - 重新开始"""
	print("🔄 从胜利面板重新开始游戏")
	hide_victory_panel()
	
	# 重置统计数据
	enemies_killed = 0
	total_damage_dealt = 0
	boss_defeated = false
	
	resume_game()
	restart_game()

func _on_victory_menu_pressed() -> void:
	"""胜利面板 - 返回主菜单"""
	print("🏠 从胜利面板返回主菜单")
	hide_victory_panel()
	resume_game()
	return_to_main_menu()

## ========== 死亡面板系统 ==========

func hide_death_panel() -> void:
	if death_panel:
		death_panel.visible = false

func restart_game() -> void:
	print("重新开始游戏")
	
	# 隐藏死亡面板
	hide_death_panel()
	
	# 重生玩家
	if player:
		player.respawn()
	
	# 重置所有敌人血量
	reset_all_enemies()
	
	# 恢复游戏
	resume_game()

func reset_all_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy:
			# 重置敌人血量到满值
			enemy.health = enemy.max_health
			enemy.is_dead = false

func return_to_main_menu() -> void:
	print("返回主菜单")
	# 确保恢复游戏状态，避免主菜单被暂停影响
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

func quit_game() -> void:
	print("退出游戏")
	get_tree().quit()
