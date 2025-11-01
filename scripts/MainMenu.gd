# 主菜单脚本 - 只用于MainScene.tscn
extends Control

func _ready() -> void:
	# 确保主菜单不受游戏暂停状态影响
	get_tree().paused = false
	
	# 设置标题字体大小
	var title = $VBoxContainer/Title
	if title:
		title.add_theme_font_size_override("font_size", 32)
		title.add_theme_color_override("font_color", Color.WHITE)
	
	var subtitle = $VBoxContainer/Subtitle
	if subtitle:
		subtitle.add_theme_font_size_override("font_size", 16)
		subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 1.0))

func _on_start_button_pressed() -> void:
	print("开始游戏!")
	# 切换到游戏场景
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")

func _on_help_button_pressed() -> void:
	print("打开操作说明")
	# 切换到操作说明场景
	get_tree().change_scene_to_file("res://Scenes/HelpScene.tscn")

func _on_quit_button_pressed() -> void:
	print("退出游戏!")
	# 确保能够正常退出
	get_tree().quit()
	# Windows退出方法
	if OS.get_name() == "Windows":
		OS.kill(OS.get_process_id())
