extends MicroGame

@onready var player = $TDHairo

func player_transit(new_state_name):
	match new_state_name:
		"Pray": game_won.emit()
		"Chant": pass
		_: pass

func _ready():
	player.machine.transitioned.connect(player_transit)
