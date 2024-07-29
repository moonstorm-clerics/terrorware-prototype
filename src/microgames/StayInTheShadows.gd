extends Node2D

@onready var mg = $MicroGame
@onready var player = $TDHairo

var detectors
var player_lost = false

func _ready():
	detectors = U.get_children_in_group(self, "light_detectors")


func _process(_delta):
	if player_lost:
		return

	for d in detectors:
		if d.is_colliding():
			player_lost = true
			Log.pr("PLAYER IN THE LIGHT!")
			player.take_hit()

			mg.game_lost.emit()
