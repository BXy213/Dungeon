extends StaticBody2D

const DEFAULT_OBSTACLE_TEXTURE = preload("res://art/environment/dungeon_obstacle_rubble.png")

# 🪨 障碍物（支持多种类型，统一使用正方形网格）

@export var obstacle_type: String = "rock"
@export var grid_size: int = 64  # 网格大小（正方形）

@onready var collision_shape = $CollisionShape2D
@onready var sprite = $Sprite2D

var obstacle_tints = {
	"wall": Color(0.75, 0.78, 0.82),
	"rock": Color.WHITE,
	"tree": Color(0.65, 0.9, 0.65),
	"crystal": Color(0.85, 0.65, 1.0)
}

func _ready() -> void:
	# 延迟执行以确保@onready变量已准备好
	call_deferred("setup_obstacle")

func initialize(type: String, pos: Vector2) -> void:
	"""初始化障碍物类型和位置"""
	obstacle_type = type
	position = pos
	# 如果已经在场景树中，立即设置
	if is_inside_tree():
		call_deferred("setup_obstacle")

func setup_obstacle() -> void:
	"""设置障碍物（正方形，颜色根据类型变化）"""
	# 安全检查：确保节点存在
	if not collision_shape or not sprite:
		print("⚠️ 障碍物节点未准备好")
		return
	
	# 确保障碍物在正确的碰撞层
	set_collision_layer_value(1, true)  # 障碍物在第1层
	set_collision_mask_value(1, false)  # 障碍物不需要检测其他物体
	
	# 设置正方形碰撞形状（所有类型统一大小）
	var shape = RectangleShape2D.new()
	shape.size = Vector2(grid_size, grid_size)
	collision_shape.shape = shape
	
	# 设置视觉效果（根据类型设置颜色）
	sprite.texture = DEFAULT_OBSTACLE_TEXTURE
	sprite.modulate = obstacle_tints.get(obstacle_type, Color.WHITE)
	
	# 调整sprite缩放以适应grid_size
	if sprite.texture:
		var texture_size = sprite.texture.get_size()
		if texture_size.x > 0 and texture_size.y > 0:
			sprite.scale = Vector2(float(grid_size) / texture_size.x, float(grid_size) / texture_size.y)

func set_obstacle_type(type: String) -> void:
	"""设置障碍物类型"""
	obstacle_type = type
	# 如果节点还没准备好，延迟执行
	if collision_shape and sprite:
		setup_obstacle()
	else:
		call_deferred("setup_obstacle")

func get_obstacle_type() -> String:
	"""获取障碍物类型"""
	return obstacle_type
