# 操作说明界面脚本
extends Control

func _ready() -> void:
	# 确保操作说明界面不受游戏暂停状态影响
	get_tree().paused = false
	
	# 设置标题字体大小
	var title = $ScrollContainer/VBoxContainer/Title
	if title:
		title.add_theme_font_size_override("font_size", 32)
		title.add_theme_color_override("font_color", Color.WHITE)

func _on_back_button_pressed() -> void:
	print("返回主菜单")
	# 切换回主菜单场景
	get_tree().change_scene_to_file("res://Scenes/MainScene.tscn")

