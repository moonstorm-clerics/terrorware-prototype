extends Node2D

@onready var player = $TDHairo
@onready var microgame = $MicroGame

func player_transit(new_state_name):
	match new_state_name:
		"Pray": pass
		"Chant": microgame.game_won.emit()
		_: pass

func _ready():
	player.machine.transitioned.connect(player_transit)
