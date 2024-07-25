extends MicroGame

@onready var player = $TDHairo

func _ready():
	player.died.connect(func(): game_won.emit())
