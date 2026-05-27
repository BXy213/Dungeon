extends Node2D

const Constants = preload("res://scripts/core/GameConstants.gd")

var skill_range: float = 0.0
var skill_type: String = ""
var is_active: bool = false
var skill_color: Color = Color.WHITE
var in_range: bool = true
var skill_radius: float = 0.0  # 技能作用范围半径（通用）
var highlighted_enemy: Node = null  # 当前高亮的敌人
var highlight_mask: Node = null  # 当前高亮mask节点

# 🎯 射程限制相关
var clamped_position: Vector2 = Vector2.ZERO  # 被限制后的准心位置
var has_range_limit: bool = false  # 是否有射程限制

func _ready() -> void:
	visible = false

func show_indicator(skill_info: Dictionary) -> void:
	skill_range = skill_info.get("range", 0.0)
	skill_type = skill_info.get("type", "")
	skill_color = skill_info.get("color", Color.WHITE)
	skill_radius = skill_info.get("radius", 0.0)  # 技能作用范围半径（通用）
	has_range_limit = skill_range > 0.0  # 射程大于0表示有限制
	is_active = true
	visible = true

func hide_indicator() -> void:
	is_active = false
	visible = false
	
	# 清除敌人高亮
	if highlighted_enemy and is_instance_valid(highlighted_enemy):
		remove_enemy_highlight(highlighted_enemy)
	highlighted_enemy = null
	highlight_mask = null

func _process(_delta: float) -> void:
	if not is_active:
		return
	
	var player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if not player:
		return
	
	var mouse_position = get_global_mouse_position()
	
	# 🎯 计算受射程限制的准心位置
	if has_range_limit:
		clamped_position = clamp_position_to_range(mouse_position, player.global_position, skill_range)
		global_position = clamped_position
		
		# 检查是否在射程内
		var distance = clamped_position.distance_to(player.global_position)
		in_range = distance <= skill_range
	else:
		# 无射程限制，直接跟随鼠标
		global_position = mouse_position
		clamped_position = mouse_position
		in_range = true
	
	# 🎯 精准射击特殊处理：检测鼠标下的敌人
	if skill_type == "targeted":
		var new_highlighted_enemy = find_enemy_at_cursor()
		if new_highlighted_enemy != highlighted_enemy:
			# 移除旧高亮
			if highlighted_enemy and is_instance_valid(highlighted_enemy):
				remove_enemy_highlight(highlighted_enemy)
			# 添加新高亮
			highlighted_enemy = new_highlighted_enemy
			if highlighted_enemy:
				add_enemy_highlight(highlighted_enemy)
	else:
		# 非精准射击技能，清除所有高亮
		if highlighted_enemy and is_instance_valid(highlighted_enemy):
			remove_enemy_highlight(highlighted_enemy)
		highlighted_enemy = null
	
	# 重绘指示器
	queue_redraw()

func clamp_position_to_range(mouse_pos: Vector2, player_pos: Vector2, max_range: float) -> Vector2:
	"""将位置限制在射程范围内"""
	var direction = mouse_pos - player_pos
	var distance = direction.length()
	
	if distance <= max_range:
		# 在射程内，直接返回鼠标位置
		return mouse_pos
	else:
		# 超出射程，返回射程边界上的点（稍微缩小避免精度误差）
		var safe_range = max_range * 0.999  # 缩小0.1%避免浮点数精度问题
		return player_pos + direction.normalized() * safe_range

func get_clamped_position() -> Vector2:
	"""获取受射程限制的准心位置"""
	return clamped_position

func find_enemy_at_cursor(tolerance: float = 50.0) -> Node:
	"""查找鼠标位置附近的敌人"""
	var mouse_pos = get_global_mouse_position()
	var enemies = get_tree().get_nodes_in_group(Constants.GROUP_ENEMIES)
	var closest_enemy = null
	var closest_distance = tolerance
	
	for enemy in enemies:
		if enemy.visible and enemy.get_parent().get_parent().visible:
			var distance = mouse_pos.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	
	return closest_enemy

func add_enemy_highlight(enemy: Node) -> void:
	"""为敌人添加高亮效果（使用mask层）"""
	if not enemy:
		return
	
	var sprite = enemy.get_node_or_null("Sprite2D")
	if not sprite:
		return
	
	# 创建高亮mask层
	highlight_mask = ColorRect.new()
	highlight_mask.name = "HighlightMask"
	
	# 设置mask的大小和位置（匹配精灵）
	var sprite_size = sprite.texture.get_size() * sprite.scale
	highlight_mask.size = sprite_size
	highlight_mask.position = -sprite_size / 2  # 居中
	
	# 设置高亮颜色（半透明白色叠加）
	highlight_mask.color = Color(1.0, 1.0, 1.0, 0.4)
	
	# 设置blend模式和z_index
	highlight_mask.z_index = 1  # 在精灵之上
	
	# 添加到敌人节点（不是Sprite2D）
	enemy.add_child(highlight_mask)
	
	var enemy_name = str(enemy.character_name) if "character_name" in enemy else str(enemy.name)
	print("🎯 为敌人添加高亮mask: ", enemy_name)

func remove_enemy_highlight(enemy: Node) -> void:
	"""移除敌人的高亮效果（删除mask层）"""
	if not enemy or not is_instance_valid(enemy):
		return
	
	# 查找并删除高亮mask
	var mask = enemy.get_node_or_null("HighlightMask")
	if mask:
		mask.queue_free()
		var enemy_name = str(enemy.character_name) if "character_name" in enemy else str(enemy.name)
		print("🎯 移除敌人高亮mask: ", enemy_name)
	
	highlight_mask = null

func _draw() -> void:
	if not is_active:
		return
	
	var player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	if not player:
		return
	
	# 🎯 绘制射程限制圆圈（以玩家为中心）
	if has_range_limit:
		var player_screen_pos = player.global_position - global_position  # 玩家相对于准心的位置
		var range_color = Color(skill_color.r, skill_color.g, skill_color.b, 0.15)
		var range_border_color = Color(skill_color.r, skill_color.g, skill_color.b, 0.4)
		
		# 绘制射程圆圈
		draw_circle(player_screen_pos, skill_range, range_color)
		draw_arc(player_screen_pos, skill_range, 0, TAU, 64, range_border_color, 2.0)
	
	# 🎯 精准射击特殊处理 - 不绘制AOE范围圆圈，只有瞄准镜和敌人高亮
	if skill_type == "targeted":
		# 只绘制瞄准镜
		var scope_color = Color(skill_color.r, skill_color.g, skill_color.b, 1.0 if in_range else 0.5)
		if highlighted_enemy:
			# 有目标时瞄准镜更亮
			scope_color = Color(skill_color.r + 0.3, skill_color.g + 0.3, skill_color.b + 0.3, 1.0)
		
		# 绘制瞄准镜
		var scope_radius = 12.0
		draw_arc(Vector2.ZERO, scope_radius, 0, TAU, 32, scope_color, 2.0)
		draw_line(Vector2(-scope_radius * 1.5, 0), Vector2(-scope_radius, 0), scope_color, 2.0)
		draw_line(Vector2(scope_radius, 0), Vector2(scope_radius * 1.5, 0), scope_color, 2.0)
		draw_line(Vector2(0, -scope_radius * 1.5), Vector2(0, -scope_radius), scope_color, 2.0)
		draw_line(Vector2(0, scope_radius), Vector2(0, scope_radius * 1.5), scope_color, 2.0)
		draw_circle(Vector2.ZERO, 2.0, scope_color)
		return
	
	# 🎆 其他技能的常规显示
	# 绘制技能作用范围圆圈（以准心为中心）
	if skill_radius > 0:
		# 显示技能作用范围
		var circle_color = Color(skill_color.r, skill_color.g, skill_color.b, 0.3)
		draw_circle(Vector2.ZERO, skill_radius, circle_color)
		
		# 绘制范围边框
		var border_color = Color(skill_color.r, skill_color.g, skill_color.b, 0.8)
		draw_arc(Vector2.ZERO, skill_radius, 0, TAU, 64, border_color, 3.0)
		
		# 在中心绘制爆炸图标
		var explosion_color = Color(skill_color.r, skill_color.g, skill_color.b, 0.9)
		draw_circle(Vector2.ZERO, 8.0, explosion_color)
		# 绘制爆炸辐射线
		for i in range(8):
			var angle = i * TAU / 8
			var start_pos = Vector2.from_angle(angle) * 10
			var end_pos = Vector2.from_angle(angle) * 20
			draw_line(start_pos, end_pos, explosion_color, 2.0)
	
	# 绘制目标指示器（准心）
	var target_color = Color(skill_color.r, skill_color.g, skill_color.b, 1.0 if in_range else 0.5)
	var cross_size = 15.0
	draw_line(Vector2(-cross_size, 0), Vector2(cross_size, 0), target_color, 3.0)
	draw_line(Vector2(0, -cross_size), Vector2(0, cross_size), target_color, 3.0)
	draw_circle(Vector2.ZERO, 4.0, target_color)
