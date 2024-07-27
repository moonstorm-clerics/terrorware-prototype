extends Node2D

@onready var microgame = $MicroGame
@onready var player = $TDHairo

func _ready():
	player.died.connect(func(): microgame.game_won.emit())
