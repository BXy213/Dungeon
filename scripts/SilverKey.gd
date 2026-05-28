extends Area2D

const Constants = preload("res://scripts/core/GameConstants.gd")

# 🔑 银钥匙 - 敌人死亡掉落，玩家靠近自动拾取

## ========== 导出属性 ==========

@export var pickup_distance: float = 50.0  # 自动拾取距离

## ========== 内部属性 ==========

var is_picked_up: bool = false
var player: Node = null

## ========== 信号 ==========

signal key_picked_up(player: Node)

## ========== 初始化 ==========

func _ready() -> void:
	# 连接body_entered信号
	body_entered.connect(_on_body_entered)
	
	# 设置碰撞层和掩码
	collision_layer = Constants.LAYER_NONE
	collision_mask = Constants.LAYER_PLAYER_BODY
	
	# 添加到拾取物组
	add_to_group(Constants.GROUP_PICKUPS)
	
	DebugLog.debug(["🔑 银钥匙已生成，位置: ", global_position], DebugLog.CATEGORY_PICKUP)

## ========== 物理处理 ==========

func _physics_process(_delta: float) -> void:
	if is_picked_up:
		return
	
	# 检测附近的玩家
	player = _get_player()
	
	if player:
		if global_position.distance_squared_to(player.global_position) <= pickup_distance * pickup_distance:
			pickup_by_player(player)

func _get_player() -> Node:
	if player and is_instance_valid(player):
		return player
	player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYERS)
	return player

## ========== 拾取逻辑 ==========

func _on_body_entered(body: Node2D) -> void:
	"""当玩家进入碰撞区域时"""
	if is_picked_up:
		return
	
	if body.is_in_group(Constants.GROUP_PLAYERS):
		pickup_by_player(body)

func pickup_by_player(picked_player: Node) -> void:
	"""被玩家拾取"""
	if is_picked_up:
		return
	
	is_picked_up = true
	set_physics_process(false)
	
	# 调用玩家的添加银钥匙方法
	if picked_player.has_method("add_silver_key"):
		picked_player.add_silver_key(1)
		DebugLog.info(["🔑 玩家拾取银钥匙！位置: ", global_position], DebugLog.CATEGORY_PICKUP)
	else:
		DebugLog.warning(["玩家没有add_silver_key方法"], DebugLog.CATEGORY_PICKUP)
	
	# 播放拾取动画（简单的缩放消失效果）
	play_pickup_animation()
	
	# 发出信号
	key_picked_up.emit(picked_player)
	
	# 延迟删除，等待动画播放完成
	await get_tree().create_timer(0.3).timeout
	queue_free()

func play_pickup_animation() -> void:
	"""播放拾取动画"""
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		# 创建缩放+上升+淡出动画
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.3)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		tween.tween_property(self, "position", position + Vector2(0, -20), 0.3)

