extends Node2D

@onready var player = $TDHairo
@onready var microgame = $MicroGame

func player_transit(new_state_name):
	match new_state_name:
		"Pray": microgame.game_won.emit()
		"Chant": pass
		_: pass

func _ready():
	player.machine.transitioned.connect(player_transit)
