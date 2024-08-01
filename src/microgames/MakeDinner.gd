extends Node2D

@onready var mg = $MicroGame
@onready var pot = $Pot

var good_ingredients = []
var bad_ingredients = []

var held_object = null

var added_poison = false

func _ready():
	for node in get_tree().get_nodes_in_group("good_ingredients"):
		good_ingredients.append(node)
	for node in get_tree().get_nodes_in_group("bad_ingredients"):
		bad_ingredients.append(node)

	pot.body_entered.connect(on_body_entered_pot)

	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

	for node in get_tree().get_nodes_in_group("draggable"):
		node.clicked.connect(_on_pickable_clicked)

func _exit_tree():
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_pickable_clicked(object):
	if !held_object:
		object.pickup()
		held_object = object
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)


func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if held_object and !event.pressed:
			held_object.drop()
			held_object = null
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func on_body_entered_pot(body):
	if body in good_ingredients:
		good_ingredients.erase(body)

		Sounds.play(Sounds.S.pray)
		body.set_visible(false)
		if not added_poison and good_ingredients.is_empty():
			mg.game_won.emit()
	elif body in bad_ingredients:
		mg.game_lost.emit()
		body.set_visible(false)
		added_poison = true
		Sounds.play(Sounds.S.new_order)
