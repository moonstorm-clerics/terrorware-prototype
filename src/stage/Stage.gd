extends Node
class_name Stage

## vars ################################################

@onready var directive_label = $%DirectiveLabel
@onready var outcome_label = $%OutcomeLabel
@onready var level_label = $%LevelLabel
@onready var lives_label = $%LivesLabel

@onready var microgame_ui = $%MicroGameUI
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

var villagers = []
@onready var player = $%Player

## ready ################################################

func _ready():
	Log.pr("stage ready.....")
	directive_label.set_visible(false)
	outcome_label.set_visible(false)

	setup_follows()

	start_next_game()

## start/end microgame ################################################

func start_next_game():
	# starting a micro game animation!
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

	# pause and fade out stage/village
	Anim.fade_out(stage_ui, transition_t)
	await Anim.fade_out(village, transition_t)
	stage_ui.set_visible(false)
	village.set_visible(false)
	village.set_process_mode(PROCESS_MODE_DISABLED)
	player.camera.set_enabled(false)

	# add and present game node
	directive_label.set_visible(true)
	game_container.add_child(game_node)
	game_container.set_process_mode(PROCESS_MODE_INHERIT)
	Anim.fade_in(game_node, transition_t)

	# clear directive line after 2s
	get_tree().create_timer(2.0).timeout.connect(func():
		directive_label.set_visible(false))

	# end game after `game_t` seconds
	get_tree().create_timer(game_t).timeout.connect(exit_microgame)

func exit_microgame():
	if state == State.STAGE:
		Log.warn("Already exited, nothing to do")
		return
	Log.pr("Exiting microgame", microgame)

	# TODO time up! sound

	var outcome = microgame.outcome
	if outcome == microgame.default_outcome:
		match outcome:
			MicroGame.Outcome.WON:
				on_game_won()
			MicroGame.Outcome.LOST:
				on_game_lost()


	# start slowmo
	Engine.set_time_scale(0.5)

	# clean up game
	await Anim.fade_out(game_container.get_children()[0], transition_t)
	U.remove_children(game_container)
	directive_label.set_visible(false)

	# end slowmo
	Engine.set_time_scale(1.0)

	# switch back to STAGE mode
	state = State.STAGE
	player.camera.set_enabled(true)
	village.set_process_mode(PROCESS_MODE_INHERIT)
	stage_ui.set_visible(true)
	village.set_visible(true)
	Anim.fade_in(village, transition_t)
	await Anim.fade_in(stage_ui, transition_t)

	# handle game outcome
	match outcome:
		MicroGame.Outcome.WON:
			won_count += 1
			player.machine.transit("Jump") # celebrate
		MicroGame.Outcome.LOST:
			lost_count += 1
			drop_villager()
		_: Log.warn("Unhandled game outcome: ", outcome)

	microgame = null

	Log.pr("won", won_count, "lost", lost_count)
	lives_label.text = "[center]Lives: %s[/center]" % (lives - lost_count)

	# wait a bit before starting again
	await get_tree().create_timer(game_t).timeout

	outcome_label.set_visible(false)
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
	# you win! sound and visual
	outcome_label.set_visible(true)
	outcome_label.text = "[center][color=green]%s[/color][/center]" % "SURVIVED"

func on_game_lost():
	# you lose! sound and visual
	outcome_label.set_visible(true)
	outcome_label.text = "[center][color=red]%s[/color][/center]" % "FAIL"

## villager follows ###########################################

func drop_villager():
	if not villagers.is_empty():
		var rand = U.rand_of(villagers)
		rand.machine.transit("Fall") # could also do Dying/death
		await Anim.fade_out(rand)
		rand.queue_free()

		# wait a tick
		await get_tree().create_timer(0.3).timeout
		setup_follows.call_deferred()
	else:
		# TODO animate player death
		# handle game over
		Log.pr("Game over!")

func find_villagers():
	villagers = U.get_children_in_group(self, "npcs")

func setup_follows():
	find_villagers()
	var last = null
	for vil in villagers:
		if last == null:
			vil.follow_entity(player)
		else:
			vil.follow_entity(last)
		last = vil
