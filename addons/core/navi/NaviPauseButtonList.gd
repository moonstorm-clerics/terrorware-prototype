@tool
extends NaviButtonList

var button_defs = [
	{
		label="Resume",
		fn=Navi.resume,
	},
	{
		label="Restart",
		fn=Navi.nav_to.bind("res://src/stage/Stage.tscn"),
	},
	{
		label="Quit Game",
		fn=func(): get_tree().quit(),
	},
]


func _ready():
	for def in button_defs:
		add_menu_item(def)

	if Engine.is_editor_hint():
		request_ready()
