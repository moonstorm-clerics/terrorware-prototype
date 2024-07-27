extends Node
class_name Stage

## vars ################################################

@onready var directive_label = $%DirectiveLabel
@onready var level_label = $%LevelLabel
@onready var lives_label = $%LivesLabel

@onready var stage_ui = $%StageUI
@onready var village = $%Village
@onready var game_container = $%MicroGameContainer

@export var micro_games: Array[PackedScene] = []

var game_t = 4.0
var transition_t = 0.8

enum State {STAGE, MICROGAME}

var state = State.STAGE
var microgame: MicroGame

var won_count = 0
var lost_count = 0
var lives = 4

## ready ################################################

func _ready():
	Log.pr("stage ready.....")
	directive_label.set_visible(false)

	start_next_game()

## start/end microgame ################################################

func start_next_game():
	# TODO animations/presentation, etc
	level_label.text = "[center]# %s[/center]" % (won_count + lost_count + 1)

	await Anim.scale_up_down_up(level_label, 0.8)

	game_container.set_process_mode(PROCESS_MODE_DISABLED)
	var game_scene = U.rand_of(micro_games)
	var game_node = game_scene.instantiate()
	start_microgame(game_node)


func start_microgame(game_node):
	Log.pr("Starting microgame")
	state = State.MICROGAME

	microgame = setup_microgame(game_node)
	Log.pr("Entering microgame", microgame)

	Anim.fade_out(stage_ui, transition_t)
	await Anim.fade_out(village, transition_t)

	game_container.add_child(game_node)
	game_container.set_process_mode(PROCESS_MODE_INHERIT)
	directive_label.set_visible(true)
	Anim.fade_in(game_node, transition_t)

	get_tree().create_timer(2.0).timeout.connect(func():
		directive_label.set_visible(false))
	get_tree().create_timer(game_t).timeout.connect(exit_microgame)

func exit_microgame():
	if state == State.STAGE:
		Log.warn("Already exited, nothing to do")
		return
	Log.pr("Exiting microgame", microgame)

	# TODO time up! sound

	Engine.set_time_scale(0.5)

	match microgame.outcome:
		MicroGame.Outcome.WON:
			won_count += 1
		MicroGame.Outcome.LOST:
			lost_count += 1
		_: Log.warn("Unhandled game outcome: ", microgame.outcome)

	microgame = null
	state = State.STAGE

	await Anim.fade_out(game_container.get_children()[0], transition_t)
	Engine.set_time_scale(1.0)
	U.remove_children(game_container)

	Anim.fade_in(village, transition_t)
	await Anim.fade_in(stage_ui, transition_t)

	# TODO update stage based on won/lost count
	Log.pr("won", won_count, "lost", lost_count)
	lives_label.text = "[center]Lives: %s[/center]" % (lives - lost_count)

	start_next_game()

## microgame setup ################################################

func setup_microgame(node):
	var mg = MicroGame.get_microgame(node)

	mg.game_won.connect(on_game_won)
	mg.game_lost.connect(on_game_lost)

	directive_label.text = "[center]%s[/center]" % mg.directive

	return mg

## game won/lost ################################################

func on_game_won():
	Log.pr("marking game won!")
	# TODO you win! sound and visual

func on_game_lost():
	Log.pr("marking game lost!")
	# TODO you lose! sound and visual
