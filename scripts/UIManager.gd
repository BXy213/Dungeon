extends Control

const Constants = preload("res://scripts/core/GameConstants.gd")
const Styles = preload("res://scripts/ui/UIStyleFactory.gd")

var player = null
var skill_manager = null

# UI元素 - 底部布局：左边状态，右边技能
@onready var skill_buttons = [
	$BottomPanel/SkillBar/Skill1,
	$BottomPanel/SkillBar/Skill2, 
	$BottomPanel/SkillBar/Skill3,
	$BottomPanel/SkillBar/Skill4
]

@onready var skill_labels = [
	$BottomPanel/SkillBar/Skill1/Label,
	$BottomPanel/SkillBar/Skill2/Label,
	$BottomPanel/SkillBar/Skill3/Label,
	$BottomPanel/SkillBar/Skill4/Label
]

@onready var cooldown_labels = [
	$BottomPanel/SkillBar/Skill1/CooldownLabel,
	$BottomPanel/SkillBar/Skill2/CooldownLabel,
	$BottomPanel/SkillBar/Skill3/CooldownLabel,
	$BottomPanel/SkillBar/Skill4/CooldownLabel
]

@onready var mana_cost_labels = [
	$BottomPanel/SkillBar/Skill1/ManaCostLabel,
	$BottomPanel/SkillBar/Skill2/ManaCostLabel,
	$BottomPanel/SkillBar/Skill3/ManaCostLabel,
	$BottomPanel/SkillBar/Skill4/ManaCostLabel
]

# 玩家状态UI - 移至底部左边
@onready var health_bar = $BottomPanel/StatusPanel/HealthBar/HealthFill
@onready var health_label = $BottomPanel/StatusPanel/HealthBar/HealthLabel
@onready var mana_bar = $BottomPanel/StatusPanel/ManaBar/ManaFill
@onready var mana_label = $BottomPanel/StatusPanel/ManaBar/ManaLabel
@onready var exp_bar = $BottomPanel/StatusPanel/ExpBar/ExpFill
@onready var exp_label = $BottomPanel/StatusPanel/ExpBar/ExpLabel
@onready var level_label = $BottomPanel/StatusPanel/PlayerInfo/LevelLabel
@onready var attack_label = $BottomPanel/StatusPanel/PlayerStats/AttackLabel
@onready var defense_label = $BottomPanel/StatusPanel/PlayerStats/DefenseLabel
@onready var speed_label = $BottomPanel/StatusPanel/PlayerStats/SpeedLabel

# 银钥匙显示（动态创建）
var silver_key_label: Label

# 技能视觉效果UI - 状态叠加
@onready var state_overlays = [
	$BottomPanel/SkillBar/Skill1/StateOverlay,
	$BottomPanel/SkillBar/Skill2/StateOverlay,
	$BottomPanel/SkillBar/Skill3/StateOverlay,
	$BottomPanel/SkillBar/Skill4/StateOverlay
]

# 小地图UI（动态创建）
var minimap_panel: Panel
var minimap_container: Control
var minimap_room_size: Vector2 = Vector2(15, 15)  # 小地图中每个房间的大小
var minimap_rooms: Dictionary = {}  # 存储小地图房间节点
var minimap_corridors: Dictionary = {}  # 存储小地图通道节点
var discovered_rooms: Dictionary = {}  # 已发现的房间
var discovered_corridors: Dictionary = {}  # 已发现的通道
var boss_room_coord: Vector2i  # BOSS房间坐标
var player_indicator: ColorRect  # 玩家位置指示器

# 房间状态面板（动态创建）
var room_status_panel: Panel
var room_status_label: Label
var enemy_counter_label: Label

var dungeon_generator  # DungeonGenerator类型

# 🔄 技能切换UI
var skill_swap_panel: Panel
var skill_swap_button: Button
var is_skill_swap_open: bool = false
var skill_scroll_container: ScrollContainer  # 保存滚动容器引用
var last_scroll_position: float = 0.0  # 保存上次滚动位置

# 🎁 技能奖励UI
var skill_reward_panel: Panel
var is_skill_reward_open: bool = false
var selected_reward_skill: String = ""
var reward_confirm_button: Button
var reward_skill_buttons: Array[Button] = []

# ⏸️ 暂停系统UI
var pause_button: Button
var pause_panel: Panel
var is_user_paused: bool = false  # 用户手动暂停
var is_reward_paused: bool = false  # 奖励系统暂停

func _ready() -> void:
	# 延迟初始化，确保场景树完全准备好
	await get_tree().process_frame
	
	# 获取玩家引用
	player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if player:
		skill_manager = player.get_node_or_null(Constants.NODE_SKILL_MANAGER)
	
	setup_skill_buttons()
	create_skill_swap_ui()
	create_skill_reward_ui()
	create_pause_ui()
	create_room_status_panel()
	create_minimap()
	create_silver_key_display()
	setup_dungeon_reference()
	
	# 连接玩家的银钥匙变化信号
	if player and player.has_signal("silver_key_changed"):
		player.silver_key_changed.connect(_on_silver_key_changed)

func _input(event: InputEvent) -> void:
	"""处理UI快捷键输入"""
	if event is InputEventKey and event.pressed:
		# ESC键：打开暂停菜单（优先级：技能取消 > 打开暂停菜单）
		if event.keycode == KEY_ESCAPE:
			# 检查玩家是否正在选择技能
			var is_selecting_skill = false
			if player and player.has_node(Constants.NODE_STATE_MANAGER):
				var state_manager = player.get_node(Constants.NODE_STATE_MANAGER)
				if state_manager and state_manager.has_method("is_selecting_skill"):
					is_selecting_skill = state_manager.is_selecting_skill()
			
			# 如果没有选择技能且暂停菜单未打开，则打开暂停菜单
			if not is_selecting_skill and not is_user_paused:
				_on_pause_button_pressed()
				get_viewport().set_input_as_handled()  # 标记事件已处理
		
		# B键：打开/关闭技能调配菜单（暂停时不响应）
		elif event.keycode == KEY_B:
			if not is_user_paused:  # 只在非暂停状态时才响应
				_on_skill_swap_button_pressed()
				get_viewport().set_input_as_handled()  # 标记事件已处理

func setup_dungeon_reference() -> void:
	# 等待一帧确保场景树准备好
	await get_tree().process_frame
	dungeon_generator = get_tree().current_scene.get_node_or_null(Constants.NODE_DUNGEON_GENERATOR)
	if dungeon_generator:
		dungeon_generator.room_changed.connect(_on_room_changed)
		dungeon_generator.room_exploration_completed.connect(_on_room_exploration_completed)
		
		# 初始化小地图内容
		initialize_minimap()
		
		# 初始更新状态面板
		if dungeon_generator.current_room:
			update_room_status_display(dungeon_generator.current_room)
	
	# 连接玩家到房间的敌人死亡信号
	var game_player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if game_player:
		# 等待房间准备好后连接信号
		call_deferred("connect_room_signals")

func setup_skill_buttons() -> void:
	if not skill_manager:
		return
	
	for i in range(4):
		var skill_info = skill_manager.get_skill_info(i)
		if skill_info:
			# 有技能
			skill_labels[i].text = str(i + 1) + ". " + skill_info.name
			skill_buttons[i].modulate = skill_info.color
			mana_cost_labels[i].text = str(skill_info.mana_cost) + "MP"
			skill_buttons[i].disabled = false
		else:
			# 空技能槽
			skill_labels[i].text = str(i + 1) + ". 暂无技能"
			skill_buttons[i].modulate = Color.GRAY
			mana_cost_labels[i].text = "--MP"
			skill_buttons[i].disabled = true
		
		# 连接按钮信号（如果还未连接）
		if not skill_buttons[i].pressed.is_connected(_on_skill_button_pressed):
			skill_buttons[i].pressed.connect(_on_skill_button_pressed.bind(i))

func _on_skill_button_pressed(skill_id: int) -> void:
	if player and player.state_manager:
		player.state_manager.handle_skill_key_input(skill_id)

func _process(_delta: float) -> void:
	update_skill_ui()
	update_player_status_ui()

func update_skill_ui() -> void:
	if not player or not skill_manager:
		return
	
	for i in range(4):
		var skill_info = skill_manager.get_skill_info(i)
		
		# 检查技能槽是否为空
		if not skill_info:
			# 空技能槽
			state_overlays[i].set_skill_state("disabled")
			skill_buttons[i].disabled = true
			cooldown_labels[i].text = ""
			mana_cost_labels[i].modulate = Color.GRAY
			continue
		
		var remaining = skill_manager.get_cooldown_remaining(i)
		var mana_cost = skill_info.get("mana_cost", 0)
		var is_mana_sufficient = player.mana >= mana_cost
		
		# 技能状态视觉反馈和冷却时间显示
		if remaining > 0:
			# 冷却中 - 暗色叠加 + 显示剩余时间
			state_overlays[i].set_skill_state("cooldown")
			skill_buttons[i].disabled = true
			cooldown_labels[i].text = str(snapped(remaining, 0.1)) + "s"
		elif not is_mana_sufficient:
			# 魔法不足 - 更暗的叠加
			state_overlays[i].set_skill_state("disabled")
			skill_buttons[i].disabled = true
			cooldown_labels[i].text = ""
		elif player.state_manager and player.state_manager.is_selecting_skill() and player.state_manager.get_selected_skill_slot() == i:
			# 技能选中状态 - 亮色叠加
			state_overlays[i].set_skill_state("ready")
			skill_buttons[i].disabled = false
			cooldown_labels[i].text = ""
		else:
			# 正常可用状态
			state_overlays[i].set_skill_state("normal")
			skill_buttons[i].disabled = false
			cooldown_labels[i].text = ""
		
		# 魔法消耗颜色显示
		if is_mana_sufficient:
			mana_cost_labels[i].modulate = Color.WHITE
		else:
			mana_cost_labels[i].modulate = Color.RED

func update_player_status_ui() -> void:
	if not player:
		return
	
	# 更新血条
	var health_percent = get_safe_ratio(player.health, player.max_health)
	health_bar.scale.x = health_percent
	health_label.text = str(player.health) + "/" + str(player.max_health)
	
	# 血条颜色
	if health_percent > 0.6:
		health_bar.color = Color.GREEN
	elif health_percent > 0.3:
		health_bar.color = Color.YELLOW
	else:
		health_bar.color = Color.RED
	
	# 更新魔法条
	var mana_percent = get_safe_ratio(player.mana, player.max_mana)
	mana_bar.scale.x = mana_percent
	mana_label.text = str(player.mana) + "/" + str(player.max_mana)
	
	# ✅ 更新经验条（与血条和魔法条逻辑完全一致）
	var required_exp = player.get_required_experience_for_level(player.level + 1)
	var exp_percent = get_safe_ratio(player.experience, required_exp)
	exp_bar.scale.x = clamp(exp_percent, 0.0, 1.0)
	exp_label.text = str(player.experience) + " / " + str(required_exp)
	
	# 更新等级
	level_label.text = "等级 " + str(player.level)
	
	# ✅ 更新玩家属性
	attack_label.text = "攻击: " + str(player.current_attack_damage)
	defense_label.text = "防御: " + str(player.current_defense)
	speed_label.text = "速度: " + str(int(player.current_speed))

func get_safe_ratio(current_value: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return clamp(current_value / max_value, 0.0, 1.0)

# 操作教程已移除，现在在暂停面板中显示

# 小地图相关函数
func _on_room_changed(new_room, _old_room) -> void:
	update_room_status_display(new_room)
	
	# 连接新房间的敌人信号
	if new_room:
		if new_room.enemy_died_in_room.is_connected(_on_enemy_died_in_room):
			new_room.enemy_died_in_room.disconnect(_on_enemy_died_in_room)
		new_room.enemy_died_in_room.connect(_on_enemy_died_in_room)
		
		# 连接敌人计数变化信号（检查是否已连接）
		if not new_room.enemy_count_changed.is_connected(_on_enemy_count_changed):
			new_room.enemy_count_changed.connect(_on_enemy_count_changed)
	
	# 更新小地图玩家位置和房间状态
	update_player_position_on_minimap()
	# 更新当前房间颜色（可能从探索中变为已探索）
	if new_room:
		var room_coord = new_room.room_id
		if room_coord in minimap_rooms:
			var room_rect = minimap_rooms[room_coord]
			update_minimap_room_color(room_rect, room_coord)
	
	# 立即更新状态面板
	call_deferred("update_room_status_display", new_room)

func _on_area_changed(area_type: String, area_id: String) -> void:
	# 处理玩家区域改变的状态显示
	if area_type == "corridor":
		show_corridor_status(area_id)
		update_player_position_on_minimap()  # 更新玩家在通道中的位置
		# 显示通道（移除迷雾）
		reveal_corridor(area_id)
		print("UI更新通道状态: ", area_id)
	elif area_type == "room":
		# 玩家进入或回到房间，更新房间状态显示
		if dungeon_generator and dungeon_generator.current_room:
			update_room_status_display(dungeon_generator.current_room)
			update_player_position_on_minimap()
			# 更新当前房间颜色（可能发生状态变化）
			var current_room = dungeon_generator.current_room
			if current_room:
				var room_coord = current_room.room_id
				# 显示房间（移除迷雾）
				reveal_room(room_coord)
				if room_coord in minimap_rooms:
					var room_rect = minimap_rooms[room_coord]
					update_minimap_room_color(room_rect, room_coord)
			print("UI更新房间状态: ", area_id)

func show_corridor_status(corridor_id: String) -> void:
	# 显示通道状态信息
	if room_status_label:
		# 解析通道ID，显示连接的房间信息
		var parts = corridor_id.split("_to_")
		if parts.size() == 2:
			room_status_label.text = "🚪 通道: " + parts[0] + " ↔ " + parts[1]
		else:
			room_status_label.text = "🚪 通道 - 安全区域"
		room_status_label.modulate = Color.CYAN
	
	if enemy_counter_label:
		enemy_counter_label.text = "💙 通道: 无敌人"
		enemy_counter_label.modulate = Color.CYAN
	
	print("UI显示通道状态: ", corridor_id)

func initialize_minimap() -> void:
	if not dungeon_generator:
		return
	
	# 清除现有的小地图房间和通道
	for child in minimap_container.get_children():
		child.queue_free()
	minimap_rooms.clear()
	minimap_corridors.clear()
	discovered_rooms.clear()
	discovered_corridors.clear()
	
	# 获取地牢尺寸
	var dungeon_width = dungeon_generator.dungeon_width
	var dungeon_height = dungeon_generator.dungeon_height
	
	# 记录BOSS房间坐标
	boss_room_coord = Vector2i(dungeon_width - 1, dungeon_height - 1)
	
	# 计算小地图房间大小，为通道预留空间
	var container_size = minimap_container.size
	var corridor_gap = 6  # 房间间通道的间隔大小
	var room_size = Vector2(
		(container_size.x - (dungeon_width - 1) * corridor_gap - 10) / dungeon_width,
		(container_size.y - (dungeon_height - 1) * corridor_gap - 10) / dungeon_height
	)
	minimap_room_size = room_size
	
	# 创建所有小地图房间（初始不可见）
	for x in range(dungeon_width):
		for y in range(dungeon_height):
			var room_coord = Vector2i(x, y)
			var room_rect = ColorRect.new()
			room_rect.size = minimap_room_size
			room_rect.position = Vector2(
				x * (minimap_room_size.x + corridor_gap) + 5,
				y * (minimap_room_size.y + corridor_gap) + 5
			)
			
			# 初始设置为不可见（迷雾）
			room_rect.visible = false
			
			# 设置颜色（未探索）
			update_minimap_room_color(room_rect, room_coord)
			
			minimap_container.add_child(room_rect)
			minimap_rooms[room_coord] = room_rect
	
	# 创建小地图通道（初始不可见）
	create_minimap_corridors()
	
	# 显示初始房间和BOSS房间
	reveal_room(Vector2i(0, 0))  # 初始房间
	reveal_room(boss_room_coord)  # BOSS房间
	
	# 为BOSS房间添加金钥匙图标
	add_golden_key_icon_to_boss_room()
	
	# 创建玩家位置指示器
	player_indicator = ColorRect.new()
	player_indicator.size = minimap_room_size * 0.6  # 稍小一些
	player_indicator.color = Color.YELLOW
	player_indicator.z_index = 10  # 确保在最上层
	minimap_container.add_child(player_indicator)
	
	# 更新玩家位置
	update_player_position_on_minimap()
	
	print("🗺️ 小地图初始化完成（迷雾探索模式）")

func create_minimap_corridors() -> void:
	if not dungeon_generator:
		return
	
	# 获取通道数据
	var corridors = dungeon_generator.corridors
	
	for corridor_id in corridors:
		var corridor_data = corridors[corridor_id]
		
		# 创建通道的视觉表示
		var corridor_rect = ColorRect.new()
		corridor_rect.color = Color(0.6, 0.6, 0.6, 0.8)  # 灰色通道
		corridor_rect.z_index = 1  # 在房间之上，玩家指示器之下
		corridor_rect.visible = false  # 初始不可见（迷雾）
		
		# 计算小地图中通道的位置和大小
		var room1_coord = corridor_data.room1_coord
		var room2_coord = corridor_data.room2_coord
		var direction = corridor_data.direction
		
		if room1_coord in minimap_rooms and room2_coord in minimap_rooms:
			var room1_rect = minimap_rooms[room1_coord]
			var room2_rect = minimap_rooms[room2_coord]
			
			# 通道为小矩形，位于房间间隙中
			var corridor_gap = 6  # 与房间布局一致的间隔
			
			# 根据方向计算通道位置和大小
			if direction == Vector2i.RIGHT:
				# 水平向右的通道 - 位于房间右侧边缘和下一房间左侧边缘之间
				corridor_rect.size = Vector2(corridor_gap, minimap_room_size.y * 0.4)
				corridor_rect.position = Vector2(
					room1_rect.position.x + minimap_room_size.x,
					room1_rect.position.y + minimap_room_size.y * 0.3
				)
			elif direction == Vector2i.LEFT:
				# 水平向左的通道 - 位于房间左侧边缘和上一房间右侧边缘之间
				corridor_rect.size = Vector2(corridor_gap, minimap_room_size.y * 0.4)
				corridor_rect.position = Vector2(
					room2_rect.position.x + minimap_room_size.x,
					room2_rect.position.y + minimap_room_size.y * 0.3
				)
			elif direction == Vector2i.DOWN:
				# 垂直向下的通道 - 位于房间下侧边缘和下一房间上侧边缘之间
				corridor_rect.size = Vector2(minimap_room_size.x * 0.4, corridor_gap)
				corridor_rect.position = Vector2(
					room1_rect.position.x + minimap_room_size.x * 0.3,
					room1_rect.position.y + minimap_room_size.y
				)
			elif direction == Vector2i.UP:
				# 垂直向上的通道 - 位于房间上侧边缘和上一房间下侧边缘之间
				corridor_rect.size = Vector2(minimap_room_size.x * 0.4, corridor_gap)
				corridor_rect.position = Vector2(
					room2_rect.position.x + minimap_room_size.x * 0.3,
					room2_rect.position.y + minimap_room_size.y
				)
			
			minimap_container.add_child(corridor_rect)
			minimap_corridors[corridor_id] = corridor_rect
			print("创建小地图通道: ", corridor_id, " 位置: ", corridor_rect.position, " 大小: ", corridor_rect.size)

func update_minimap_room_color(room_rect: ColorRect, room_coord: Vector2i) -> void:
	if not dungeon_generator:
		return
	
	var room = dungeon_generator.rooms.get(room_coord)
	if room:
		var room_state = room.get_room_state()
		match room_state:
			room.RoomState.UNEXPLORED:
				room_rect.color = Color(0.3, 0.3, 0.3, 0.8)  # 灰色 - 未探索
			room.RoomState.EXPLORING:
				room_rect.color = Color(0.8, 0.3, 0.3, 0.8)  # 红色 - 探索中
			room.RoomState.EXPLORED:
				room_rect.color = Color(0.3, 0.8, 0.3, 0.8)  # 绿色 - 已探索
	else:
		room_rect.color = Color(0.1, 0.1, 0.1, 0.5)  # 深灰色 - 不存在的房间

func reveal_room(room_coord: Vector2i) -> void:
	"""显示房间（移除迷雾）"""
	if room_coord in discovered_rooms:
		return  # 已经显示过了
	
	if room_coord in minimap_rooms:
		var room_rect = minimap_rooms[room_coord]
		room_rect.visible = true
		discovered_rooms[room_coord] = true
		
		# 更新房间颜色
		update_minimap_room_color(room_rect, room_coord)
		
		# 显示连接到这个房间的通道
		reveal_corridors_connected_to_room(room_coord)
		
		print("🗺️ 显示房间: ", room_coord)

func reveal_corridors_connected_to_room(room_coord: Vector2i) -> void:
	"""显示连接到指定房间的所有通道"""
	if not dungeon_generator:
		return
	
	for corridor_id in dungeon_generator.corridors:
		var corridor_data = dungeon_generator.corridors[corridor_id]
		var room1_coord = corridor_data.room1_coord
		var room2_coord = corridor_data.room2_coord
		
		# 如果通道连接到这个房间，且两端房间都已发现，则显示通道
		if (room1_coord == room_coord or room2_coord == room_coord):
			if room1_coord in discovered_rooms and room2_coord in discovered_rooms:
				reveal_corridor(corridor_id)

func reveal_corridor(corridor_id: String) -> void:
	"""显示通道（移除迷雾）"""
	if corridor_id in discovered_corridors:
		return  # 已经显示过了
	
	if corridor_id in minimap_corridors:
		var corridor_rect = minimap_corridors[corridor_id]
		corridor_rect.visible = true
		discovered_corridors[corridor_id] = true
		print("🗺️ 显示通道: ", corridor_id)

func add_golden_key_icon_to_boss_room() -> void:
	"""为BOSS房间添加金钥匙图标"""
	if not boss_room_coord in minimap_rooms:
		return
	
	var boss_room_rect = minimap_rooms[boss_room_coord]
	
	# 创建金钥匙图标
	var key_icon = TextureRect.new()
	var key_texture = load("res://art/goldenkey.png")
	if key_texture:
		key_icon.texture = key_texture
		key_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		key_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# 设置金钥匙图标大小（约为房间大小的70%）
		var icon_size = minimap_room_size * 0.7
		key_icon.size = icon_size
		
		# 居中放置
		key_icon.position = (minimap_room_size - icon_size) / 2
		
		key_icon.z_index = 5  # 在房间和玩家指示器之间
		
		boss_room_rect.add_child(key_icon)
		print("🏆 BOSS房间添加金钥匙图标")
	else:
		print("⚠️ 无法加载金钥匙贴图")

func update_player_position_on_minimap() -> void:
	if not dungeon_generator or not player_indicator:
		return
	
	# 检查玩家当前区域类型
	if dungeon_generator.current_area_type == "room":
		var current_room = dungeon_generator.current_room
		if current_room:
			var room_coord = current_room.room_id
			if room_coord in minimap_rooms:
				var room_rect = minimap_rooms[room_coord]
				# 将玩家指示器居中放置在房间中央
				var offset = (minimap_room_size - player_indicator.size) / 2
				player_indicator.position = room_rect.position + offset
				player_indicator.color = Color.YELLOW  # 房间中为黄色
	
	elif dungeon_generator.current_area_type == "corridor":
		var corridor_id = dungeon_generator.current_corridor_id
		if corridor_id in minimap_corridors:
			var corridor_rect = minimap_corridors[corridor_id]
			# 将玩家指示器居中放置在通道中央
			var offset = (corridor_rect.size - player_indicator.size) / 2
			player_indicator.position = corridor_rect.position + offset
			player_indicator.color = Color.CYAN  # 通道中为青色

func _on_room_exploration_completed(room_id: Vector2i) -> void:
	print("UI: 房间 ", room_id, " 探索完成!")
	
	# 更新当前房间状态显示
	if dungeon_generator and dungeon_generator.current_room:
		update_room_status_display(dungeon_generator.current_room)
	
	# ❌ 不再自动显示技能奖励选择界面
	# 玩家需要用银钥匙打开宝箱来获取奖励
	# show_skill_reward_selection()
	
	# 更新小地图中对应房间的颜色
	if room_id in minimap_rooms:
		var room_rect = minimap_rooms[room_id]
		update_minimap_room_color(room_rect, room_id)

func _on_enemy_died_in_room(_room_id: Vector2i, remaining_count: int) -> void:
	# 更新敌人计数显示
	if enemy_counter_label:
		if remaining_count > 0:
			enemy_counter_label.text = "敌人: " + str(remaining_count)
			enemy_counter_label.modulate = Color.RED
		else:
			enemy_counter_label.text = "敌人: 已清除"
			enemy_counter_label.modulate = Color.GREEN

func _on_enemy_count_changed(_room_id: Vector2i, enemy_count: int) -> void:
	"""敌人数量变化时更新UI（包括增加和减少）"""
	if enemy_counter_label:
		if enemy_count > 0:
			enemy_counter_label.text = "🔥 敌人: " + str(enemy_count)
			enemy_counter_label.modulate = Color.RED
		else:
			enemy_counter_label.text = "💀 敌人: 已清除"
			enemy_counter_label.modulate = Color.GREEN
	print("UI敌人计数更新: ", enemy_count)

func update_room_status_display(room) -> void:
	if not room or not room_status_label or not enemy_counter_label:
		return
	
	var room_state = room.get_room_state()
	var status_text = ""
	var status_color = Color.WHITE
	
	match room_state:
		0:  # Room.RoomState.UNEXPLORED
			status_text = "🔒 未探索"
			status_color = Color.GRAY
		1:  # Room.RoomState.EXPLORING
			status_text = "⚔️ 探索中"
			status_color = Color.YELLOW
		2:  # Room.RoomState.EXPLORED
			status_text = "✅ 已探索"
			status_color = Color.GREEN
	
	room_status_label.text = "房间 " + str(room.room_id) + " - " + status_text
	room_status_label.modulate = status_color
	
	# 更新敌人计数
	var enemy_count = room.alive_enemy_count
	if enemy_count > 0:
		enemy_counter_label.text = "🔥 敌人: " + str(enemy_count)
		enemy_counter_label.modulate = Color.RED
	else:
		enemy_counter_label.text = "💀 敌人: 已清除"
		enemy_counter_label.modulate = Color.GREEN
		
	# 调试信息
	print("UI更新 - 房间: ", room.room_id, ", 状态: ", status_text, ", 敌人: ", room.alive_enemy_count)

func create_room_status_panel() -> void:
	# 创建房间状态显示面板（右上角，暂停按钮下方）
	room_status_panel = Panel.new()
	room_status_panel.size = Vector2(280, 80)
	
	# 计算位置：右上角，暂停按钮下方
	var screen_size = get_viewport().get_visible_rect().size
	room_status_panel.position = Vector2(screen_size.x - 300, 70)  # 暂停按钮下方
	
	room_status_panel.add_theme_stylebox_override(
		"panel",
		Styles.create_panel_style(Color(0.2, 0.2, 0.3, 0.8), Color(0.5, 0.5, 0.6, 1.0), 2, 5)
	)
	
	# 创建垂直容器
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(230, 60)
	
	# 房间状态标签
	room_status_label = Label.new()
	room_status_label.text = "房间状态: 未知"
	room_status_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(room_status_label)
	
	# 敌人计数标签
	enemy_counter_label = Label.new()
	enemy_counter_label.text = "敌人: 0"
	enemy_counter_label.add_theme_font_size_override("font_size", 14)
	enemy_counter_label.modulate = Color.GRAY
	vbox.add_child(enemy_counter_label)
	
	room_status_panel.add_child(vbox)
	add_child(room_status_panel)
	
	print("房间状态面板已创建")

func connect_room_signals() -> void:
	# 为所有房间连接敌人死亡信号
	if dungeon_generator:
		for room in dungeon_generator.rooms.values():
			if room:
				if not room.enemy_died_in_room.is_connected(_on_enemy_died_in_room):
					room.enemy_died_in_room.connect(_on_enemy_died_in_room)
				if not room.enemy_count_changed.is_connected(_on_enemy_count_changed):
					room.enemy_count_changed.connect(_on_enemy_count_changed)

func create_minimap() -> void:
	# 创建小地图面板（左上角）
	minimap_panel = Panel.new()
	minimap_panel.name = "MinimapPanel"
	
	# 放置在左上角
	var panel_size = Vector2(200, 220)
	minimap_panel.position = Vector2(20, 20)  # 左上角位置
	minimap_panel.size = panel_size
	
	minimap_panel.add_theme_stylebox_override(
		"panel",
		Styles.create_panel_style(Color(0.05, 0.05, 0.1, 0.9), Color(0.4, 0.4, 0.6, 1.0), 2, 8)
	)
	
	# 创建标题
	var title_label = Label.new()
	title_label.text = "🗺️ 地牢地图"
	title_label.position = Vector2(10, 5)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	minimap_panel.add_child(title_label)
	
	# 创建地图容器
	minimap_container = Control.new()
	minimap_container.position = Vector2(10, 30)
	minimap_container.size = Vector2(180, 180)
	minimap_panel.add_child(minimap_container)
	
	# 添加到UI
	add_child(minimap_panel)

# 🔄 创建技能切换UI
func create_skill_swap_ui() -> void:
	# 创建技能切换按钮（右下角）
	skill_swap_button = Button.new()
	skill_swap_button.text = "技能\n调配"
	skill_swap_button.size = Vector2(60, 60)
	
	# 设置文本居中和字体大小
	skill_swap_button.add_theme_font_size_override("font_size", 14)
	
	# 计算位置：右下角，技能条右侧
	var screen_size = get_viewport().get_visible_rect().size
	skill_swap_button.position = Vector2(screen_size.x - 80, screen_size.y - 80)
	
	skill_swap_button.pressed.connect(_on_skill_swap_button_pressed)
	add_child(skill_swap_button)
	
	# 创建技能切换面板（初始隐藏）
	skill_swap_panel = Panel.new()
	skill_swap_panel.size = Vector2(600, 400)
	skill_swap_panel.position = Vector2(
		(screen_size.x - skill_swap_panel.size.x) / 2,
		(screen_size.y - skill_swap_panel.size.y) / 2
	)
	skill_swap_panel.visible = false
	
	skill_swap_panel.add_theme_stylebox_override(
		"panel",
		Styles.create_panel_style(Color(0.1, 0.1, 0.2, 0.95), Color(0.6, 0.6, 0.8, 1.0), 3, 10)
	)
	
	create_skill_swap_content()
	add_child(skill_swap_panel)

func create_skill_swap_content() -> void:
	# 创建标题
	var title_label = Label.new()
	title_label.text = "⚔️ 技能切换"
	title_label.position = Vector2(20, 10)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	skill_swap_panel.add_child(title_label)
	
	# 创建关闭按钮
	var close_button = Button.new()
	close_button.text = "✖"
	close_button.size = Vector2(40, 40)
	close_button.position = Vector2(skill_swap_panel.size.x - 50, 10)
	close_button.pressed.connect(_on_skill_swap_close_pressed)
	skill_swap_panel.add_child(close_button)
	
	if not skill_manager:
		var empty_label = Label.new()
		empty_label.text = "技能管理器未就绪"
		empty_label.position = Vector2(20, 70)
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color.GRAY)
		skill_swap_panel.add_child(empty_label)
		return
	
	# 创建主容器
	var main_container = HBoxContainer.new()
	main_container.position = Vector2(20, 60)
	main_container.size = Vector2(skill_swap_panel.size.x - 40, skill_swap_panel.size.y - 80)
	main_container.add_theme_constant_override("separation", 20)
	skill_swap_panel.add_child(main_container)
	
	# 左侧：当前激活技能
	var active_container = VBoxContainer.new()
	active_container.custom_minimum_size = Vector2(250, 0)
	var active_title = Label.new()
	active_title.text = "🎯 当前激活技能"
	active_title.add_theme_font_size_override("font_size", 18)
	active_container.add_child(active_title)
	
	# 创建4个激活技能槽
	for i in range(4):
		var skill_slot = create_skill_slot_button(i, true)
		active_container.add_child(skill_slot)
	
	main_container.add_child(active_container)
	
	# 右侧：备选技能库
	var available_container = VBoxContainer.new()
	available_container.custom_minimum_size = Vector2(290, 0)  # 增加宽度以容纳两列
	var available_title = Label.new()
	available_title.text = "📚 备选技能库"
	available_title.add_theme_font_size_override("font_size", 18)
	available_container.add_child(available_title)
	
	# 创建滚动容器
	skill_scroll_container = ScrollContainer.new()
	skill_scroll_container.custom_minimum_size = Vector2(280, 280)  # 增加宽度以容纳两列
	skill_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 设置滚动条样式
	skill_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # 禁用横向滚动
	skill_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO  # 自动垂直滚动
	
	# 创建技能列表容器（使用GridContainer实现两列布局）
	var skills_list = GridContainer.new()
	skills_list.columns = 2  # 设置为2列
	skills_list.add_theme_constant_override("h_separation", 5)  # 水平间距
	skills_list.add_theme_constant_override("v_separation", 5)  # 垂直间距
	skills_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 创建备选技能按钮
	var all_skills = skill_manager.get_all_available_skills()
	for skill_id in all_skills.keys():
		var skill_button = create_available_skill_button(skill_id)
		skills_list.add_child(skill_button)
	
	# 组装滚动结构
	skill_scroll_container.add_child(skills_list)
	available_container.add_child(skill_scroll_container)
	
	# 恢复之前的滚动位置
	if last_scroll_position > 0:
		# 延迟设置滚动位置，确保内容已加载
		await get_tree().process_frame
		skill_scroll_container.scroll_vertical = int(last_scroll_position)
	
	main_container.add_child(available_container)

func create_skill_slot_button(slot_index: int, _is_active: bool) -> Control:
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 60)
	
	# 技能信息
	var info_container = VBoxContainer.new()
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var skill_info = skill_manager.get_skill_info(slot_index)
	var name_label = Label.new()
	var desc_label = Label.new()
	
	if skill_info:
		name_label.text = str(slot_index + 1) + ". " + skill_info.name
		desc_label.text = "伤害:" + str(skill_info.get("damage", skill_info.get("heal_amount", 0))) + " 魔法:" + str(skill_info.mana_cost) + " 冷却:" + str(skill_info.cooldown) + "s"
		name_label.modulate = skill_info.color
	else:
		name_label.text = str(slot_index + 1) + ". 空技能槽"
		desc_label.text = "点击移除按钮清空，或从右侧选择技能"
		name_label.modulate = Color.GRAY
	
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.modulate = Color.LIGHT_GRAY
	
	info_container.add_child(name_label)
	info_container.add_child(desc_label)
	container.add_child(info_container)
	
	# 移除按钮
	var remove_button = Button.new()
	remove_button.text = "✖"
	remove_button.custom_minimum_size = Vector2(40, 40)
	remove_button.pressed.connect(_on_skill_remove_pressed.bind(slot_index))
	container.add_child(remove_button)
	
	return container

func create_available_skill_button(skill_id: String) -> Button:
	var skill_info = skill_manager.get_skill_info_by_id(skill_id)
	var button = Button.new()
	button.custom_minimum_size = Vector2(130, 55)  # 减小尺寸适应两列布局
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# 设置较小的字体
	button.add_theme_font_size_override("font_size", 10)
	
	# 构建技能描述文本
	var skill_text = skill_info.name
	
	# 根据技能类型显示不同信息
	var skill_type = skill_info.get("type", "")
	match skill_type:
		"auto":
			skill_text += "\n🔮 自动"
		"heal":
			skill_text += "\n💚 " + str(skill_info.get("heal_amount", 0))
		"aoe":
			skill_text += "\n💥 " + str(skill_info.get("damage", 0))
		"targeted":
			skill_text += "\n🎯 " + str(skill_info.get("damage", 0))
		_:
			skill_text += "\n⚔️ " + str(skill_info.get("damage", 0))
	
	skill_text += " " + str(skill_info.mana_cost) + "MP"
	skill_text += " " + str(skill_info.cooldown) + "s"
	
	button.text = skill_text
	button.modulate = skill_info.color
	button.pressed.connect(_on_available_skill_pressed.bind(skill_id))
	
	# 检查是否已激活 - 用视觉效果表示，不添加文字
	var active_skill_ids = skill_manager.get_active_skill_ids()
	if skill_id in active_skill_ids:
		button.disabled = true
		button.modulate = Color(0.4, 0.4, 0.4, 0.8)  # 更明显的暗化效果
		button.add_theme_stylebox_override(
			"normal",
			Styles.create_panel_style(Color(0.2, 0.2, 0.2, 0.5), Color.ORANGE, 3)
		)
	
	return button

var selected_slot_for_swap: int = -1

func _on_skill_swap_button_pressed() -> void:
	is_skill_swap_open = !is_skill_swap_open
	skill_swap_panel.visible = is_skill_swap_open
	if is_skill_swap_open:
		refresh_skill_swap_panel()

func _on_skill_swap_close_pressed() -> void:
	is_skill_swap_open = false
	skill_swap_panel.visible = false
	selected_slot_for_swap = -1

func _on_skill_remove_pressed(slot_index: int) -> void:
	skill_manager.swap_skill(slot_index, "")  # 移除技能
	refresh_skill_swap_panel()
	setup_skill_buttons()  # 刷新主UI

func _on_available_skill_pressed(skill_id: String) -> void:
	# 如果没有选中槽位，尝试找到第一个空槽位
	if selected_slot_for_swap == -1:
		for i in range(4):
			var current_skill = skill_manager.get_skill_info(i)
			if not current_skill:
				selected_slot_for_swap = i
				break
		
		# 如果没有空槽位，选择第一个槽位替换
		if selected_slot_for_swap == -1:
			selected_slot_for_swap = 0
	
	skill_manager.swap_skill(selected_slot_for_swap, skill_id)
	selected_slot_for_swap = -1
	refresh_skill_swap_panel()
	setup_skill_buttons()  # 刷新主UI

func refresh_skill_swap_panel() -> void:
	# 保存当前滚动位置
	if skill_scroll_container and is_instance_valid(skill_scroll_container):
		last_scroll_position = skill_scroll_container.scroll_vertical
	
	# 清除旧内容并重新创建
	for child in skill_swap_panel.get_children():
		child.queue_free()
	
	# 等待节点被清理后再创建新内容
	await get_tree().process_frame
	create_skill_swap_content()

# 🎁 创建技能奖励选择UI
func create_skill_reward_ui() -> void:
	# 创建技能奖励面板（初始隐藏）
	skill_reward_panel = Panel.new()
	skill_reward_panel.size = Vector2(500, 400)
	var screen_size = get_viewport().get_visible_rect().size
	skill_reward_panel.position = Vector2(
		(screen_size.x - skill_reward_panel.size.x) / 2,
		(screen_size.y - skill_reward_panel.size.y) / 2
	)
	skill_reward_panel.visible = false
	
	skill_reward_panel.add_theme_stylebox_override(
		"panel",
		Styles.create_panel_style(Color(0.1, 0.1, 0.15, 0.95), Color.GOLD, 2, 10)
	)
	
	# 设置奖励面板为高优先级，但低于暂停面板
	skill_reward_panel.z_index = 500
	skill_reward_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	
	add_child(skill_reward_panel)

# ⏸️ 创建暂停系统UI
func create_silver_key_display() -> void:
	"""创建银钥匙计数显示"""
	silver_key_label = Label.new()
	silver_key_label.text = "🔑 银钥匙: 0"
	
	# 设置字体大小和颜色
	silver_key_label.add_theme_font_size_override("font_size", 16)
	silver_key_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6, 1.0))  # 淡黄色
	
	# 获取状态面板并添加到PlayerInfo下方
	var status_panel = get_node_or_null("BottomPanel/StatusPanel")
	if status_panel:
		var player_info = status_panel.get_node_or_null("PlayerInfo")
		if player_info:
			# 添加到PlayerInfo容器中
			player_info.add_child(silver_key_label)
			print("  ✓ 银钥匙显示已创建并添加到PlayerInfo")
		else:
			# 如果找不到PlayerInfo，直接添加到StatusPanel
			silver_key_label.position = Vector2(10, 65)
			status_panel.add_child(silver_key_label)
			print("  ✓ 银钥匙显示已创建并添加到StatusPanel")
	else:
		print("  ⚠️ 找不到StatusPanel，无法添加银钥匙显示")
	
	# 初始更新显示
	if player:
		_on_silver_key_changed(player.silver_key_count)

func _on_silver_key_changed(new_count: int) -> void:
	"""银钥匙数量变化时更新显示"""
	if silver_key_label:
		silver_key_label.text = "🔑 银钥匙: " + str(new_count)
		
		# 根据数量改变颜色
		if new_count > 0:
			silver_key_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0, 1.0))  # 亮黄色
		else:
			silver_key_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))  # 灰色

func create_pause_ui() -> void:
	# 创建暂停按钮（右上角，最高优先级）
	pause_button = Button.new()
	pause_button.text = "⏸️"
	pause_button.size = Vector2(50, 50)
	
	# 计算位置：右上角
	var screen_size = get_viewport().get_visible_rect().size
	pause_button.position = Vector2(screen_size.x - 60, 10)
	
	# 设置最高优先级，确保总是可点击
	pause_button.z_index = 1000
	pause_button.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_button.pressed.connect(_on_pause_button_pressed)
	add_child(pause_button)
	
	# 创建暂停面板（初始隐藏）
	pause_panel = Panel.new()
	pause_panel.size = Vector2(400, 350)
	pause_panel.position = Vector2(
		(screen_size.x - pause_panel.size.x) / 2,
		(screen_size.y - pause_panel.size.y) / 2
	)
	pause_panel.visible = false
	pause_panel.z_index = 1001  # 确保在所有面板之上
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	
	pause_panel.add_theme_stylebox_override(
		"panel",
		Styles.create_panel_style(Color(0.05, 0.05, 0.1, 0.98), Color.CYAN, 3, 15)
	)
	
	create_pause_content()
	add_child(pause_panel)

func create_pause_content() -> void:
	# 创建主容器
	var main_container = VBoxContainer.new()
	main_container.position = Vector2(20, 20)
	main_container.size = Vector2(360, 260)
	main_container.add_theme_constant_override("separation", 10)
	
	# 创建标题
	var title_label = Label.new()
	title_label.text = "⏸️ 游戏暂停"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color.CYAN)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	# 创建副标题
	var subtitle_label = Label.new()
	subtitle_label.text = "选择下一步操作"
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color.WHITE)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_container.add_child(subtitle_label)
	
	# 添加分隔线
	var separator1 = HSeparator.new()
	main_container.add_child(separator1)
	
	# 创建按钮容器
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 10)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# 继续游戏按钮
	var continue_button = Button.new()
	continue_button.text = "▶️ 继续游戏"
	continue_button.custom_minimum_size = Vector2(110, 40)
	continue_button.add_theme_font_size_override("font_size", 14)
	continue_button.pressed.connect(_on_continue_game_pressed)
	button_container.add_child(continue_button)
	
	# 重新开始按钮
	var restart_button = Button.new()
	restart_button.text = "🔄 重新开始"
	restart_button.custom_minimum_size = Vector2(110, 40)
	restart_button.add_theme_font_size_override("font_size", 14)
	restart_button.pressed.connect(_on_restart_game_pressed)
	button_container.add_child(restart_button)
	
	# 返回主菜单按钮
	var menu_button = Button.new()
	menu_button.text = "🏠 返回主菜单"
	menu_button.custom_minimum_size = Vector2(110, 40)
	menu_button.add_theme_font_size_override("font_size", 14)
	menu_button.pressed.connect(_on_return_to_menu_pressed)
	button_container.add_child(menu_button)
	
	main_container.add_child(button_container)
	
	# 添加第二个分隔线
	var separator2 = HSeparator.new()
	main_container.add_child(separator2)
	
	# 创建操作说明标题
	var instruction_title = Label.new()
	instruction_title.text = "操作说明:"
	instruction_title.add_theme_font_size_override("font_size", 16)
	instruction_title.add_theme_color_override("font_color", Color.WHITE)
	instruction_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(instruction_title)
	
	# 创建操作说明文本
	var instruction_text = Label.new()
	instruction_text.text = "WASD移动  右键普攻  1234选择技能\n左键释放技能  ESC暂停/取消  B键技能调配"
	instruction_text.add_theme_font_size_override("font_size", 13)
	instruction_text.add_theme_color_override("font_color", Color.WHITE)
	instruction_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_container.add_child(instruction_text)
	
	pause_panel.add_child(main_container)

func _on_pause_button_pressed() -> void:
	"""处理暂停按钮点击"""
	is_user_paused = true
	get_tree().paused = true
	pause_panel.visible = true
	print("⏸️ 用户手动暂停游戏")

func _on_continue_game_pressed() -> void:
	"""处理继续游戏按钮"""
	is_user_paused = false
	pause_panel.visible = false
	
	# 如果奖励面板打开，回到奖励界面但保持暂停
	# 如果奖励面板关闭，恢复游戏
	if is_reward_paused and is_skill_reward_open:
		# 回到奖励选择界面，游戏仍暂停
		print("⏸️ 回到技能奖励选择界面")
	else:
		# 完全恢复游戏
		get_tree().paused = false
		print("▶️ 恢复游戏")

func _on_restart_game_pressed() -> void:
	"""处理重新开始按钮 - 完全重新开始游戏"""
	print("🔄 完全重新开始游戏")
	
	# 重置暂停状态
	is_user_paused = false
	is_reward_paused = false
	
	# 确保恢复游戏状态，避免重新加载时仍处于暂停
	get_tree().paused = false
	
	# 重新加载游戏场景，这会重置所有状态：
	# - 重新生成地牢
	# - 重置所有房间状态
	# - 重置玩家等级、经验、技能
	# - 重置所有敌人
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")

func _on_return_to_menu_pressed() -> void:
	"""处理返回主菜单按钮"""
	print("🏠 返回主菜单")
	
	# 重置暂停状态
	is_user_paused = false
	is_reward_paused = false
	
	# 确保恢复游戏状态，避免主菜单被暂停影响
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

var current_chest: Node = null  # 当前触发奖励的宝箱

func show_chest_reward_selection(chest: Node) -> void:
	"""显示宝箱奖励选择（由宝箱调用）"""
	print("📦 显示宝箱奖励选择界面")
	current_chest = chest
	show_skill_reward_selection()

func show_skill_reward_selection() -> void:
	"""显示技能奖励选择界面"""
	if not skill_manager:
		return
	
	# 获取未拥有的技能
	var unowned_skills = skill_manager.get_unowned_skills()
	if unowned_skills.is_empty():
		print("🎁 玩家已拥有所有技能，无奖励可提供")
		return
	
	# 标记为奖励暂停
	is_reward_paused = true
	get_tree().paused = true
	
	# 随机选择最多3个技能
	var reward_options = []
	unowned_skills.shuffle()
	var max_options = min(3, unowned_skills.size())
	for i in range(max_options):
		reward_options.append(unowned_skills[i])
	
	# 清除旧内容
	for child in skill_reward_panel.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# 创建标题
	var title_label = Label.new()
	title_label.text = "🎁 选择技能奖励"
	title_label.position = Vector2(20, 15)
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color.GOLD)
	skill_reward_panel.add_child(title_label)
	
	# 创建描述
	var desc_label = Label.new()
	desc_label.text = "恭喜清理完房间！请选择一个技能奖励："
	desc_label.position = Vector2(20, 50)
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color.WHITE)
	skill_reward_panel.add_child(desc_label)
	
	# 清空按钮数组
	reward_skill_buttons.clear()
	
	# 创建技能选择按钮
	for i in range(reward_options.size()):
		var skill_id = reward_options[i]
		var skill_info = skill_manager.get_skill_info_by_id(skill_id)
		var button = Button.new()
		button.size = Vector2(460, 60)
		button.position = Vector2(20, 90 + i * 70)
		
		var skill_text = skill_info.name + "\n"
		skill_text += "魔法:" + str(skill_info.mana_cost) + "MP 冷却:" + str(skill_info.cooldown) + "s"
		button.text = skill_text
		button.modulate = skill_info.color
		
		# 添加meta数据用于识别
		button.set_meta("skill_id", skill_id)
		
		# 连接到选择函数而不是直接确认
		button.pressed.connect(_on_reward_skill_button_clicked.bind(skill_id))
		button.process_mode = Node.PROCESS_MODE_ALWAYS  # 确保奖励按钮在暂停时可点击
		skill_reward_panel.add_child(button)
		reward_skill_buttons.append(button)
	
	# 创建确认按钮（初始隐藏/禁用）
	reward_confirm_button = Button.new()
	reward_confirm_button.text = "✅ 请先选择一个技能"
	reward_confirm_button.size = Vector2(200, 50)
	reward_confirm_button.position = Vector2(20, 90 + reward_options.size() * 70 + 10)
	reward_confirm_button.disabled = true
	reward_confirm_button.modulate = Color.GRAY
	reward_confirm_button.pressed.connect(_on_reward_confirmed)
	reward_confirm_button.process_mode = Node.PROCESS_MODE_ALWAYS
	skill_reward_panel.add_child(reward_confirm_button)
	
	# 创建"放弃奖励"按钮
	var skip_button = Button.new()
	skip_button.text = "❌ 放弃奖励"
	skip_button.size = Vector2(200, 50)
	skip_button.position = Vector2(280, 90 + reward_options.size() * 70 + 10)
	skip_button.modulate = Color.GRAY
	skip_button.pressed.connect(_on_skip_reward_button_clicked)
	skip_button.process_mode = Node.PROCESS_MODE_ALWAYS  # 确保放弃按钮在暂停时可点击
	skill_reward_panel.add_child(skip_button)
	
	# 显示面板
	is_skill_reward_open = true
	skill_reward_panel.visible = true
	
	print("🎁 显示技能奖励选择，可选技能: ", reward_options)

func _on_reward_skill_button_clicked(skill_id: String) -> void:
	"""处理技能按钮点击（选择但未确认）"""
	selected_reward_skill = skill_id
	
	# 更新所有技能按钮的视觉状态
	for button in reward_skill_buttons:
		if button.get_meta("skill_id", "") == skill_id:
			# 选中的按钮
			button.modulate = Color.YELLOW  # 高亮显示
			button.add_theme_stylebox_override(
				"normal",
				Styles.create_panel_style(Color(1, 0.8, 0, 0.3), Color.GOLD, 3)
			)
		else:
			# 未选中的按钮
			var skill_info = skill_manager.get_skill_info_by_id(button.get_meta("skill_id", ""))
			button.modulate = skill_info.color
			button.remove_theme_stylebox_override("normal")
	
	# 启用确认按钮
	reward_confirm_button.disabled = false
	reward_confirm_button.modulate = Color.WHITE
	reward_confirm_button.text = "✅ 确认选择: " + skill_manager.get_skill_info_by_id(skill_id).name
	
	print("🎯 选择技能: ", skill_id, "（未确认）")

func _on_reward_confirmed() -> void:
	"""处理确认奖励选择"""
	if selected_reward_skill == "":
		return
	
	if selected_reward_skill == "skip":
		# 确认放弃奖励
		print("🎁 确认放弃奖励")
	else:
		# 添加到技能库
		if skill_manager.add_skill_to_library(selected_reward_skill):
			# 如果激活技能数少于4个，自动激活
			if skill_manager.get_active_skill_count() < 4:
				var slot = skill_manager.auto_activate_skill(selected_reward_skill)
				if slot >= 0:
					print("🔥 新技能自动激活到槽位 ", slot + 1)
					# 刷新技能UI
					setup_skill_buttons()
			
			# 刷新技能切换面板（如果已打开）
			if is_skill_swap_open:
				refresh_skill_swap_panel()
			
			print("🎁 确认获得技能奖励: ", selected_reward_skill)
		else:
			print("❌ 技能奖励添加失败: ", selected_reward_skill)
	
	# 关闭奖励面板
	hide_skill_reward_panel()

func _on_skip_reward_button_clicked() -> void:
	"""处理放弃奖励按钮点击（选择但未确认）"""
	selected_reward_skill = "skip"
	
	# 更新所有技能按钮的视觉状态（取消高亮）
	for button in reward_skill_buttons:
		var skill_info = skill_manager.get_skill_info_by_id(button.get_meta("skill_id", ""))
		button.modulate = skill_info.color
		button.remove_theme_stylebox_override("normal")
	
	# 启用确认按钮
	reward_confirm_button.disabled = false
	reward_confirm_button.modulate = Color.WHITE
	reward_confirm_button.text = "✅ 确认放弃奖励"
	
	print("🎯 选择放弃奖励（未确认）")


func hide_skill_reward_panel() -> void:
	"""隐藏技能奖励面板"""
	is_skill_reward_open = false
	skill_reward_panel.visible = false
	selected_reward_skill = ""
	
	# ✅ 如果是从宝箱打开的，通知宝箱已完成奖励选择
	if current_chest and is_instance_valid(current_chest):
		if current_chest.has_method("open_chest"):
			current_chest.open_chest()
			print("📦 通知宝箱完成奖励选择，宝箱已开启")
	current_chest = null
	
	# 清除奖励暂停状态
	is_reward_paused = false
	
	# 只有在用户没有手动暂停的情况下才恢复游戏
	if not is_user_paused:
		get_tree().paused = false
