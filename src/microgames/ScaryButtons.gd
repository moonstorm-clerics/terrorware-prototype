extends Node

@onready var win_button = $ScaryButton
@onready var microgame = $MicroGame

func _ready():
	for ch in get_children():
		if ch is Button:
			ch.pressed.connect(func():
				if ch == win_button:
					microgame.game_won.emit()
				else:
					microgame.game_lost.emit())
