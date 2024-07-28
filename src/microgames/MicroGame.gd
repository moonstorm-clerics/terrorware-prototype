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

signal game_finished
signal game_won
signal game_lost

@export var default_outcome: Outcome = Outcome.LOST
@export var directive: String = "Do the thing!"
@export var early_exit: bool = false

var outcome

## ready ###########################################

func _ready():
	outcome = U._or(default_outcome, Outcome.LOST)
	game_won.connect(on_game_won)
	game_lost.connect(on_game_lost)

	Log.pr("Microgame ready", self)

## log.gd ###########################################

func to_pretty():
	return [directive, outcome]

## won ###########################################

func on_game_won():
	Log.pr("On game won")
	outcome = Outcome.WON

## lost ###########################################

func on_game_lost():
	Log.pr("On game lost")
	outcome = Outcome.LOST
