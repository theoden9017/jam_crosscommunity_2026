@tool
extends EditorPlugin

const MENU_SCRIPT := preload("res://addons/flexible_menu/flexible_main_menu.gd")

func _enter_tree() -> void:
	add_custom_type("FlexibleMainMenu", "Control", MENU_SCRIPT, null)

func _exit_tree() -> void:
	remove_custom_type("FlexibleMainMenu")
