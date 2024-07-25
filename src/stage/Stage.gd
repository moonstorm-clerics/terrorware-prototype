extends Node
class_name Stage

## vars ################################################

@onready var stage_ui = $%StageUI
@onready var game_container = $%MicroGameContainer

@export var micro_games: Array[PackedScene] = []

var game_t = 4.0
var transition_t = 4.0

enum State {STAGE, MICROGAME}
enum Outcome {WON, LOST}

var state = State.STAGE
var outcome

var won_count = 0
var lost_count = 0

## ready ################################################

func _ready():
	Log.pr("stage ready.....")
	game_container.set_process_mode(PROCESS_MODE_DISABLED)

	start_next_game()

## start/end microgame ################################################

func start_next_game():
	# TODO drop, do some animation, etc
	await get_tree().create_timer(1.0).timeout

	var game_scene = U.rand_of(micro_games)
	var game_node = game_scene.instantiate()
	start_microgame(game_node)

func start_microgame(game_node):
	Log.pr("Entering microgame")
	state = State.MICROGAME
	if game_node.default_outcome != null:
		outcome = game_node.default_outcome
	else:
		outcome = Outcome.WON

	game_node.game_won.connect(on_game_won)
	game_node.game_lost.connect(on_game_lost)

	await Anim.fade_out(stage_ui, transition_t)

	# TODO pause/transition in game container?
	game_container.add_child(game_node)
	game_container.set_process_mode(PROCESS_MODE_INHERIT)
	Anim.fade_in(game_node, transition_t)

	get_tree().create_timer(game_t).timeout.connect(exit_microgame)

func exit_microgame():
	if state == State.STAGE:
		Log.warn("Already exited, nothing to do")
		return
	Log.pr("Exiting microgame")

	match outcome:
		Outcome.WON:
			won_count += 1
		Outcome.LOST:
			lost_count += 1
		_: Log.warn("Unhandled game outcome: ", outcome)

	outcome = null
	state = State.STAGE

	await Anim.fade_out(game_container.get_children()[0], transition_t)
	U.remove_children(game_container)

	await Anim.fade_in(stage_ui, transition_t)

	# TODO update stage based on won/lost count
	Log.pr("won", won_count, "lost", lost_count)

	start_next_game()

## game won/lost ################################################

func on_game_won():
	Log.pr("game won! exiting!")
	outcome = Outcome.WON
	exit_microgame()

func on_game_lost():
	Log.pr("game lost! exiting!")
	outcome = Outcome.LOST
	exit_microgame()
