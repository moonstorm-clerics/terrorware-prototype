# https://kidscancode.org/godot_recipes/4.x/physics/rigidbody_drag_drop/index.html
extends RigidBody2D

signal clicked

var held = false

func _ready():
	input_event.connect(_on_input_event)
	freeze = true

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			Log.pr("draggable clicked")
			clicked.emit(self)

func _physics_process(_delta):
	if held:
		global_transform.origin = get_global_mouse_position()

func pickup():
	if held:
		return
	# freeze = true
	held = true

func drop():
	if held:
		# freeze = false
		held = false
