@tool
extends NaviButtonList

var button_defs = [
	{
		label="Start game",
		fn=Navi.nav_to.bind("res://src/stage/Stage.tscn"),
	},
	{
		label="Quit",
		fn=func(): get_tree().quit(),
	},
]


func _ready():
	for def in button_defs:
		add_menu_item(def)

	if Engine.is_editor_hint():
		request_ready()
