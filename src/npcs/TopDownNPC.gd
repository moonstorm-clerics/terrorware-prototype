extends CharacterBody2D
class_name TopDownNPC

## config warnings ###########################################################

func _get_configuration_warnings():
	return U._config_warning(self, {expected_nodes=[
		"TDNPCMachine", "StateLabel", "AnimatedSprite2D",
		], expected_animations={"AnimatedSprite2D": [
			"idle_down", "idle_up", "idle_right",
			"run_down", "run_up", "run_right",
			"idle", "grabbed", "thrown",
			]}})

## vars ###########################################################

# input vars

@export var display_name: String
@export var initial_health: int = 6

@export var run_speed: float = 10000
@export var wander_speed: float = 6000
@export var jump_speed: float = 10000

@export var should_wander: bool = false
@export var should_notice: bool = false
@export var should_hop: bool = false
@export var can_be_called: bool = false
@export var can_be_grabbed_thrown: bool = false

# vars

var move_vector: Vector2
var facing_vector: Vector2
var health
var is_dead
var following
var grabbed_by

# nodes

@onready var coll = $CollisionShape2D
@onready var anim = $AnimatedSprite2D
@onready var machine = $TDNPCMachine
@onready var state_label = $StateLabel

var action_detector
var action_hint
var action_label
var action_arrow

var produce_icon
var seed_icon
var seed_type_icon
var tool_icon

var item_seed
var item_tool
var item_produce

var notice_box
var pit_detector

var heart_particles
var skull_particles

## enter tree ###########################################################

func _enter_tree():
	add_to_group("npcs", true)

## ready ###########################################################

func _ready():
	U.set_optional_nodes(self, {
		notice_box="NoticeBox",
		heart_particles="HeartParticles",
		skull_particles="SkullParticles",
		pit_detector="PitDetector",

		action_detector="ActionDetector",
		action_hint="ActionHint",
		action_label="ActionLabel",
		action_arrow="ActionArrow",
		produce_icon="Item/ProduceIcon",
		seed_icon="Item/SeedIcon",
		seed_type_icon="Item/SeedIcon/SeedTypeIcon",
		tool_icon="Item/ToolIcon",
		})

	if notice_box:
		notice_box.body_entered.connect(on_notice_box_entered)
		notice_box.body_exited.connect(on_notice_box_exited)

	if heart_particles:
		heart_particles.set_emitting(false)
	if skull_particles:
		skull_particles.set_emitting(false)

	machine.transitioned.connect(_on_transit)

	set_collision_layer_value(1, false) # walls,doors,env
	set_collision_layer_value(10, true) # npc
	set_collision_mask_value(1, true) # walls/env
	set_collision_mask_value(3, true) # player projectiles
	set_collision_mask_value(5, true) # enemy projectiles
	set_collision_mask_value(10, true) # npcs
	set_collision_mask_value(11, true) # fences, low-walls

## physics_process ###########################################################

func _physics_process(_delta):
	if notice_box:
		notice_box_bodies = notice_box_bodies.filter(func(b):
			return is_instance_valid(b) and not b.is_dead)

	var mv = get_move_vector()
	if mv != null:
		move_vector = mv

# overwritten in subclass
func get_move_vector():
	return null

## process ###########################################################

func _process(_delta):
	update_action_label()
	point_arrow()

## on_transit ###########################################################

func _on_transit(label):
	state_label.text = "[center]%s" % label

## actions #########################################################

var actions = [
	Action.mk({
		label="Grab",
		fn=grabbed_by_entity,
		show_on_source=true, show_on_actor=false,
		source_can_execute=func(): return can_be_grabbed_thrown and \
			not machine.state.name in ["Thrown"],
		actor_can_execute=func(player): return player.can_grab() and not is_dead,
		}),
	Action.mk({
		label="Throw",
		show_on_source=true, show_on_actor=false,
		fn=thrown_by_player,
		source_can_execute=func(): return can_be_grabbed_thrown and grabbed_by != null,
		actor_can_execute=func(player): return player.grabbing == self and not is_dead,
		})
	]

## collision ###########################################################

# Should be called immediately after move_and_slide in physics_process
# if it returns true, the calling physics_process should return to avoid moving to another state
# func collision_check():
# 	for i in get_slide_collision_count():
# 		var collision = get_slide_collision(i)
# 		var collider = collision.get_collider()
# 		if is_instance_valid(collider) and collider.is_in_group("pits"):
# 			Log.info("pit hit", collider)

## facing ###########################################################

func update_facing():
	if move_vector != Vector2.ZERO:
		facing_vector = move_vector
	# all art should face RIGHT by default
	anim.flip_h = facing_vector.x < 0

func face_body(body):
	if not body:
		return
	var pos_diff = body.global_position - global_position
	facing_vector = pos_diff.normalized()
	update_facing()

func update_directional_anim(vec, anim_prefix):
	# favors x-dir over y-dir
	if vec.x > 0:
		anim.play(str(anim_prefix, "_right"))
	elif vec.x < 0:
		# assumes anim h_flip is done elsewhere
		anim.play(str(anim_prefix, "_right"))
	elif vec.y > 0:
		anim.play(str(anim_prefix, "_down"))
	elif vec.y < 0:
		anim.play(str(anim_prefix, "_up"))

func update_run_anim():
	update_directional_anim(move_vector, "run")

func update_idle_anim():
	update_directional_anim(facing_vector, "idle")

func update_jump_anim():
	update_directional_anim(move_vector, "jump")

## death ###########################################################

signal died()

func die(_opts={}):
	is_dead = true

## damage ###########################################################

func take_hit(opts):
	take_damage(opts)
	var hit_type = opts.get("type")
	var body = opts.get("body")
	# probably worth supporting direction as well
	var _dir = opts.get("direction")

	# Sounds.play(Sounds.S.playerhurt)

	if health <= 0:
		die()
		machine.transit("Dying", {killed_by=body})
	else:
		machine.transit("KnockedBack", {knocked_by=body, hit_type=hit_type})

func take_damage(opts):
	var hit_type = opts.get("type")
	var damage = opts.get("damage")

	if damage == null:
		match hit_type:
			_:
				damage = 1
	health -= damage
	health = clamp(health, 0, initial_health)

## pits ###################################################################

func on_pit_entered():
	machine.transit("Fall")

## recover health ###########################################################

# if no arg passed, recovers _all_ health
func recover_health(h=null):
	if h == null:
		health = initial_health
	else:
		health += h

	health = clamp(health, 0, initial_health)

# reset after death
func reset():
	recover_health()
	is_dead = false
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)

## notice_box ###########################################################

var notice_box_bodies = []

func on_notice_box_entered(body):
	if not body is TDPlayer:
		return
	if not body.is_dead and not body.machine.state.name in ["KnockedBack", "Dying", "Dead"]:
		if not body in notice_box_bodies:
			notice_box_bodies.append(body)

func on_notice_box_exited(body):
	notice_box_bodies.erase(body)

## stamp ##########################################################################

# Supports 'perma-stamp' with ttl=0
# TODO refactor into shared anim/util lib (juice?)
func stamp(opts={}):
	var new_scale = opts.get("scale", 0.3)
	var new_anim = AnimatedSprite2D.new()
	new_anim.sprite_frames = anim.sprite_frames
	new_anim.animation = anim.animation
	new_anim.frame = anim.frame

	if opts.get("include_action_hint", false) and self.get("action_hint"):
		var ax_hint = self["action_hint"].duplicate()
		new_anim.add_child(ax_hint)

	new_anim.global_position = global_position + anim.position
	U.add_child_to_level(self, new_anim)

	var ttl = opts.get("ttl", 0.2)
	if ttl > 0:
		var t = create_tween()
		t.tween_property(new_anim, "scale", Vector2(new_scale, new_scale), ttl)
		t.parallel().tween_property(new_anim, "modulate:a", 0.3, ttl)
		t.tween_callback(new_anim.queue_free)

## follow #########################################################

func follow_entity(ent):
	# Sounds.play(Sounds.S.coin)
	if ent.has_signal("died"):
		U._connect(ent.died, func(): following = null)
	following = ent
	machine.transit("Follow")

## grabbed/thrown #########################################################

func grabbed_by_entity(ent):
	if ent.has_signal("died"):
		U._connect(ent.died, func(): grabbed_by = null)
	if ent.has_method("grab"):
		ent.grab(self)
	grabbed_by = ent
	machine.transit("Grabbed")

func thrown_by_player(player):
	var opts = player.throw(self)
	if opts != null:
		machine.transit("Thrown", {
			direction=opts.get("direction", Vector2.LEFT),
			throw_speed=opts.get("throw_speed")
			})

## point_arrow ###########################################################

func point_arrow():
	if not action_detector:
		return

	if action_detector.actions.size() == 0:
		action_arrow.set_visible(false)
		return
	action_arrow.set_visible(true)

	var ax = action_detector.nearest_action()
	if ax and ax.source:
		var rot = get_angle_to(ax.source.get_global_position()) + (PI / 2)
		action_arrow.set_rotation(rot)

## action detection ###########################################################

func update_action_label():
	if not action_label or not action_detector:
		return

	var ax = action_detector.nearest_action()

	if ax == null:
		action_label.text = ""
		return

	action_label.text = "[center]" + ax.label.capitalize() + "[/center]"

	# fade label if action is not current (i.e. not possible?) bit of naming could help here
	if action_detector.current_action():
		action_label.modulate.a = 1
	elif action_detector.find_nearest(action_detector.potential_actions()):
		action_label.modulate.a = 0.7
	else:
		action_label.modulate.a = 0.4

## items ###########################################################

func drop_held_item():
	produce_icon.set_visible(false)
	seed_icon.set_visible(false)
	tool_icon.set_visible(false)

	item_seed = null
	item_tool = null
	item_produce = null

func pickup_seed(produce_type):
	drop_held_item()
	seed_icon.set_visible(true)
	seed_type_icon.animation = produce_type
	item_seed = produce_type

func pickup_produce(produce_type):
	drop_held_item()
	produce_icon.set_visible(true)
	produce_icon.animation = produce_type
	item_produce = produce_type

func pickup_tool(tool_type):
	drop_held_item()
	tool_icon.set_visible(true)
	tool_icon.animation = tool_type
	item_tool = tool_type

## seeds ###########################################################

func has_seed():
	if item_seed:
		return true
	else:
		return false

func plant_seed():
	var type = item_seed

	item_seed = null
	drop_held_item()

	return type

## tools, water ###########################################################

func has_tool():
	if item_tool:
		return true
	else:
		return false

func has_water():
	if item_tool == "watering-pail":
		return true
	else:
		return false

func water_plant():
	pass

func action_source_needs_water():
	for src in action_detector.actions.map(func(ax): return ax.source).filter(func(src): return src):
		if src.has_method("needs_water"):
			if src.needs_water():
				return true

## produce ############################################################

func harvest_produce(produce_type):
	pickup_produce(produce_type)

func has_produce():
	if item_produce:
		return true
	else:
		return false

signal produce_delivered(item_produce)

func deliver_produce():
	produce_delivered.emit(item_produce)
	drop_held_item()
