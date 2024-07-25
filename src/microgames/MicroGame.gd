extends Node2D
class_name MicroGame

signal game_won
signal game_lost

@export var default_outcome: Stage.Outcome = Stage.Outcome.LOST
@export var directive: String = "Do the thing!"
