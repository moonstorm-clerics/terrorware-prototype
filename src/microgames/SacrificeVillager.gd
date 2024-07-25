extends MicroGame

func _ready():
	var npcs = U.get_children_in_group(self, "npcs", true)
	for npc in npcs:
		npc.died.connect(func(): game_won.emit())
