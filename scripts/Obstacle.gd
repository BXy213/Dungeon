extends StaticBody2D

@export var obstacle_type: String = "wall"
@export var obstacle_size: Vector2 = Vector2(50, 50)

@onready var collision_shape = $CollisionShape2D
@onready var sprite = $Sprite2D

var obstacle_colors = {
	"wall": Color(0.4, 0.4, 0.4),
	"rock": Color(0.6, 0.4, 0.2),
	"tree": Color(0.2, 0.6, 0.2),
	"crystal": Color(0.6, 0.2, 0.8)
}

func _ready() -> void:
	# 延迟执行以确保@onready变量已准备好
	call_deferred("setup_obstacle")

func initialize(type: String, pos: Vector2) -> void:
	obstacle_type = type
	position = pos
	# 如果已经在场景树中，立即设置
	if is_inside_tree():
		call_deferred("setup_obstacle")
	# 否则等待_ready()调用

func setup_obstacle() -> void:
	# 安全检查：确保节点存在
	if not collision_shape or not sprite:
		print("警告：障碍物节点未准备好")
		return
	
	# 确保障碍物在正确的碰撞层
	set_collision_layer_value(1, true)  # 障碍物在第1层
	set_collision_mask_value(1, false)  # 障碍物不需要检测其他物体
	
	# 根据类型调整大小
	match obstacle_type:
		"wall":
			obstacle_size = Vector2(60, 60)
		"rock":
			obstacle_size = Vector2(40, 40)
		"tree":
			obstacle_size = Vector2(35, 45)
		"crystal":
			obstacle_size = Vector2(25, 35)
	
	# 设置碰撞形状
	var shape = RectangleShape2D.new()
	shape.size = obstacle_size
	collision_shape.shape = shape
	
	# 设置视觉效果
	sprite.modulate = obstacle_colors.get(obstacle_type, Color.GRAY)
	
	print("🧱 障碍物设置完成: ", obstacle_type, " 碰撞层: ", collision_layer, " 大小: ", obstacle_size)

func set_obstacle_type(type: String) -> void:
	obstacle_type = type
	# 如果节点还没准备好，延迟执行
	if collision_shape and sprite:
		setup_obstacle()
	else:
		call_deferred("setup_obstacle")

func get_obstacle_type() -> String:
	"""获取障碍物类型"""
	return obstacle_type
