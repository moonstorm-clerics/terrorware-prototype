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
var game_idx = 0

var microgame_t = 4.0
var between_games_t = 4.0
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
	outcome_label.set_visible(false)

	setup_follows()

	start_next_game()

	micro_games.shuffle()

## start/end microgame ################################################

func start_next_game():
	# starting a micro game animation!
	level_label.text = "[center]# %s[/center]" % (won_count + lost_count + 1)
	await Anim.scale_up_down_up(level_label, 0.8)

	game_container.set_process_mode(PROCESS_MODE_DISABLED)

	var game_scene = get_next_game()
	if game_scene == null:
		Log.pr("no next microgame, you win!!")
		return
	var game_node = game_scene.instantiate()
	start_microgame(game_node)

func get_next_game():
	if game_idx < len(micro_games):
		var game = micro_games[game_idx]
		game_idx += 1
		return game

func start_microgame(game_node):
	Log.pr("Starting microgame")
	state = State.MICROGAME

	microgame = setup_microgame(game_node)
	Log.pr("Entering microgame", microgame)

	# pause and fade out stage/village
	Anim.fade_out(stage_ui, transition_t)
	Anim.fade_out(village, transition_t).connect(func():
		stage_ui.set_visible(false)
		village.set_visible(false)
		village.set_process_mode(PROCESS_MODE_DISABLED)
		player.camera.set_enabled(false))

	# show directive and game-splash for 2s
	microgame_ui.set_visible(true)
	await Anim.fade_in(directive_label, 1.0)
	await get_tree().create_timer(2.0).timeout
	await Anim.fade_out(directive_label, 0.4)
	microgame_ui.set_visible(false)

	# add and present game node
	game_container.add_child(game_node)
	game_container.set_process_mode(PROCESS_MODE_INHERIT)
	Anim.fade_in(game_node, transition_t)

	# end game after `microgame_t` seconds
	get_tree().create_timer(microgame_t).timeout.connect(exit_microgame)

func exit_microgame():
	if state == State.STAGE:
		Log.warn("Already exited, nothing to do")
		return
	Log.pr("Exiting microgame", microgame)

	# TODO time up! sound

	var outcome = microgame.outcome
	update_outcome_label(outcome)

	# start slowmo
	Engine.set_time_scale(0.5)

	# clean up game
	await Anim.fade_out(game_container.get_children()[0], transition_t)
	U.remove_children(game_container)

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
	await get_tree().create_timer(between_games_t).timeout

	outcome_label.set_visible(false)
	start_next_game()

## microgame setup ################################################

func setup_microgame(node):
	var mg = MicroGame.get_microgame(node)

	# these need to be invoked AFTER outcome is uped in microgame
	mg.game_won.connect(on_game_won, CONNECT_DEFERRED)
	mg.game_lost.connect(on_game_lost, CONNECT_DEFERRED)

	directive_label.text = "[center]%s[/center]" % mg.directive

	return mg

## game won/lost ################################################

func on_game_won():
	# you win! sound and visual
	if microgame.early_exit:
		exit_microgame()

func on_game_lost():
	# you lose! sound and visual
	if microgame.early_exit:
		exit_microgame()

func update_outcome_label(outcome):
	var color
	var text
	match outcome:
		MicroGame.Outcome.WON:
			color = "green"
			text = "SURVIVED"
		MicroGame.Outcome.LOST:
			color = "red"
			text = "FAIL"
	outcome_label.set_visible(true)
	outcome_label.text = "[center][color=%s]%s[/color][/center]" % [color, text]

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
