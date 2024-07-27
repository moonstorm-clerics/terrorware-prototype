extends Node
class_name MicroGame

static func get_microgame(node):
	if node is MicroGame:
		return node
	else:
		for ch in node.get_children():
			if ch is MicroGame:
				return ch
	Log.warn("No MicroGame node found in game node!", node)

## vars ###########################################

enum Outcome {WON, LOST}

signal game_won
signal game_lost

@export var default_outcome: Outcome = Outcome.LOST
@export var directive: String = "Do the thing!"

var outcome

## ready ###########################################

func _ready():
	outcome = U._or(default_outcome, Outcome.LOST)
	game_won.connect(func(): outcome = Outcome.WON)
	game_lost.connect(func(): outcome = Outcome.LOST)

	Log.pr("Microgame ready", self)

## log.gd ###########################################

func to_pretty():
	return [directive, outcome]
