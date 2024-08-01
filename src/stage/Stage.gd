extends Node
class_name Stage

## vars ################################################

@onready var directive_label = $%DirectiveLabel
@onready var outcome_label = $%OutcomeLabel
@onready var challenges_label = $%ChallengesLabel
@onready var lives_label = $%LivesLabel

@onready var microgame_progress_bar = $%MicroGameProgressBar
@onready var stage_ui = $%StageUI
@onready var village = $%Village
@onready var game_container = $%MicroGameContainer

@onready var controls = $%Controls
@onready var mouse_controls = $%MouseControls
@onready var keyboard_controls = $%KeyboardControls

@export var micro_games: Array[PackedScene] = []
var game_idx = 0

var microgame_t = 4.0
var between_games_t = 3.0
var transition_t = 0.8

enum State {STAGE, MICROGAME}

var state = State.STAGE
var microgame: MicroGame
var microgame_packed_scene: PackedScene

var won_count = 0
var lost_count = 0

var villagers = []
# @onready var player = $%Player
@onready var camera = $%Camera2D

## ready ################################################

func _ready():
	# randomize() # randomize seed
	# micro_games.shuffle()

	Log.pr("stage ready.....")
	outcome_label.set_visible(false)
	controls.set_visible(false)

	find_villagers()

	lives_label.text = "[center]Cult size: %s[/center]" % len(villagers)
	challenges_label.text = "[center]Remaining tasks: %s[/center]" % (len(micro_games) - game_idx)
	directive_label.text = "[center]Welcome to the cult![/center]"

	await get_tree().create_timer(2.0).timeout
	start_next_game()

## start/end microgame ################################################

func start_next_game():
	# starting a micro game animation!
	# level_label.text = "[center]Task # %s[/center]" % (won_count + lost_count + 1)
	# await Anim.scale_up_down_up(level_label, 0.8)

	game_container.set_process_mode(PROCESS_MODE_DISABLED)

	microgame_packed_scene = get_next_game()
	if microgame_packed_scene == null:
		Navi.show_win_menu()
		return
	var game_node = microgame_packed_scene.instantiate()
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
	controls.set_visible(true)
	Anim.fade_in(controls, 1.0)
	await Anim.fade_in(directive_label, 1.0)
	Log.pr("Entering microgame", microgame)

	await get_tree().create_timer(0.6).timeout

	# pause and fade out stage/village
	Anim.fade_out(stage_ui, transition_t)
	await Anim.fade_out(village, transition_t)

	stage_ui.set_visible(false)
	village.set_visible(false)
	village.set_process_mode(PROCESS_MODE_DISABLED)
	camera.set_enabled(false)

	await get_tree().create_timer(0.6).timeout

	# add and present game node
	game_container.add_child(game_node)
	game_container.set_process_mode(PROCESS_MODE_INHERIT)
	await Anim.fade_in(game_node, transition_t)

	get_tree().create_timer(2.0).timeout.connect(func():
		Anim.fade_out(directive_label, 0.4))

	match microgame.default_outcome:
		MicroGame.Outcome.LOST:
			microgame_progress_bar.modulate = Color.CRIMSON
		MicroGame.Outcome.WON:
			microgame_progress_bar.modulate = Color.GREEN

	# end game after `microgame_t` seconds
	get_tree().create_timer(microgame_t).timeout.connect(exit_microgame)
	reset_progress_timer()
	start_timer_update()

var timer_reset = false
func reset_progress_timer():
	microgame_progress_bar.value = 0
	timer_reset = true

func start_timer_update():
	timer_reset = false
	do_timer_update()

func do_timer_update():
	if timer_reset:
		return
	var step = microgame_t / 10.0
	microgame_progress_bar.set_max(microgame_t)
	microgame_progress_bar.value += step
	await get_tree().create_timer(step).timeout

	if microgame_progress_bar.value < microgame_progress_bar.max_value:
		do_timer_update()
	else:
		reset_progress_timer()

func exit_microgame():
	if state == State.STAGE:
		Log.warn("Already exited, nothing to do")
		return
	Log.pr("Exiting microgame", microgame)

	# TODO time up! sound
	reset_progress_timer()

	var outcome = microgame.outcome
	update_outcome_label(outcome)

	# start slowmo
	Engine.set_time_scale(0.5)

	# clean up game
	Anim.fade_out(controls, transition_t)
	await Anim.fade_out(game_container.get_children()[0], transition_t)
	U.remove_children(game_container)
	controls.set_visible(false)

	# end slowmo
	Engine.set_time_scale(1.0)

	# switch back to STAGE mode
	state = State.STAGE
	camera.set_enabled(true)
	village.set_process_mode(PROCESS_MODE_INHERIT)
	stage_ui.set_visible(true)
	village.set_visible(true)
	Anim.fade_in(village, transition_t)
	await Anim.fade_in(stage_ui, transition_t)

	# handle game outcome
	match outcome:
		MicroGame.Outcome.WON:
			won_count += 1
			villagers_celebrate()
		MicroGame.Outcome.LOST:
			# if you lose, you have to play it again!
			micro_games.append(microgame_packed_scene)
			lost_count += 1
			await drop_villager()
		_: Log.warn("Unhandled game outcome: ", outcome)

	microgame = null
	microgame_packed_scene = null

	Log.pr("won", won_count, "lost", lost_count)
	lives_label.text = "[center]Cult size: %s[/center]" % len(villagers)
	challenges_label.text = "[center]Remaining tasks: %s[/center]" % (len(micro_games) - game_idx)

	if villagers.is_empty():
		Navi.show_death_menu()
		return

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

	directive_label.text = "[center]Task %s: %s[/center]" % [won_count + lost_count + 1, mg.directive]

	match mg.control_type:
		MicroGame.ControlType.KEYBOARD:
			keyboard_controls.set_visible(true)
			mouse_controls.set_visible(false)
		MicroGame.ControlType.MOUSE:
			mouse_controls.set_visible(true)
			keyboard_controls.set_visible(false)
		_:
			Log.warn("Unhandled microgame control type", mg.control_type)

	return mg

## game won/lost ################################################

func on_game_won():
	# you win! sound and visual
	if microgame.early_exit:
		exit_microgame.call_deferred()
	microgame_progress_bar.modulate = Color.GREEN

func on_game_lost():
	# you lose! sound and visual
	if microgame.early_exit:
		exit_microgame.call_deferred()
	microgame_progress_bar.modulate = Color.CRIMSON

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

func villagers_celebrate():
	for v in villagers:
		v.machine.transit("Jump")

func villagers_sad():
	for v in villagers:
		v.machine.transit("Thrown", {
			direction=U.rand_of([Vector2.LEFT, Vector2.RIGHT]),
			})

func drop_villager():
	if not villagers.is_empty():
		var rand = U.rand_of(villagers)
		rand.machine.transit("Fall") # could also do Dying/death
		await Anim.fade_out(rand)
		rand.queue_free()

		# wait a bit
		await get_tree().create_timer(0.3).timeout
		find_villagers()
		villagers_sad()

func find_villagers():
	villagers = U.get_children_in_group(self, "npcs")
