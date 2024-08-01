@tool
extends Node2D

@onready var light = $PointLight2D
@onready var anim = $AnimatedSprite2D

var actions = [
	Action.mk({
		label="Light", fn=light_up,
		source_can_execute=func(): return not is_lit(),
		# kind of a gross leak of grab/throw into other actions!!
		actor_can_execute=func(player): return not player.is_holding(),
		show_on_source=true, show_on_actor=false,}),
	Action.mk({
		label="Pray", fn=pray,
		# kind of a gross leak of grab/throw into other actions!!
		actor_can_execute=func(player): return not player.is_holding(),
		source_can_execute=func(): return is_lit() and not praying,
		show_on_source=true, show_on_actor=false,}),
	]

#################################################################
# ready

func _ready():
	og_scale = light.texture_scale
	og_energy = light.energy

	update_light()

#################################################################
# actions

@export var lit: bool = false :
	set(l):
		lit = l

func update_light():
	if lit:
		light_up()
	else:
		put_out()

func is_lit():
	return lit

func light_up(_actor=null):
	lit = true
	anim.play("flicker")
	Sounds.play(Sounds.S.light_candle)
	light.set_enabled(true)
	light_tween()

func put_out(_actor=null):
	lit = false
	anim.play("off")
	# Sounds.play(Sounds.S.candleout)
	light.set_enabled(false)

var praying
func pray(player):
	praying = true

	var exit_cb = func():
		put_out()
		praying = false

	player.machine.transit("Pray", {exit_cb=exit_cb})


## light tween ################################################################

var t
var new_scale
var new_energy
var og_scale
var og_energy

func light_tween():
	var duration = 3.0
	var reset_duration = 2.0
	var new = 0.8

	if t:
		t.kill()

	t = create_tween().set_loops()
	t.tween_property(light, "texture_scale", new, duration)
	t.parallel().tween_property(light, "energy", new, duration)
	t.tween_property(light, "texture_scale", og_scale, reset_duration)
	t.parallel().tween_property(light, "energy", og_energy, reset_duration)
