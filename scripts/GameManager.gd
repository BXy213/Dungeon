extends Node

var death_panel = null
var player = null

var is_game_paused: bool = false

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
		# 确保死亡面板不受暂停影响
		death_panel.process_mode = Node.PROCESS_MODE_ALWAYS

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
