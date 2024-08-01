extends Node2D


@onready var mg = $MicroGame
@onready var non_believer_area = $%NonBelieverArea2D
@onready var point_light = $%PointLight

var game_won = false

func _ready():
	non_believer_area.mouse_entered.connect(func():
		if not game_won:
			game_won = true
			mg.game_won.emit())

func _process(_delta):
	point_light.global_position = get_global_mouse_position()
