extends MicroGame

@onready var player = $TDHairo

func player_transit(new_state_name):
	match new_state_name:
		"Pray": pass
		"Chant": game_won.emit()
		_: pass

func _ready():
	player.machine.transitioned.connect(player_transit)
