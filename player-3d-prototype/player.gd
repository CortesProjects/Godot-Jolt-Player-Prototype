extends CharacterBody3D

@export var speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var jump_velocity: float = 10.5
@export var crouch_height: float = 1.5
@export var stand_height: float = 2.0
@export var crouch_jump_boost: float = 2.0
@export var climable_height: float = 10.0 #higher short height

var is_crouching := false
var has_crouch_jumped := false
var head_offset_from_top: float
var target_head_y: float
var is_ascending := false
var ascend_target_position: Vector3
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var head: Node3D
var camera: Camera3D

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var capsule_shape: CapsuleShape3D = collision_shape.shape
@onready var original_position: Vector3 = collision_shape.position
@onready var uncrouch_ray = $RayCast3D

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	head = $Head
	camera = $Head/Camera3D
	camera.current = is_multiplayer_authority()

	capsule_shape = capsule_shape.duplicate()
	collision_shape.shape = capsule_shape
	
	var shape_top_y = collision_shape.position.y + (capsule_shape.height / 2.0)
	head_offset_from_top = head.position.y - shape_top_y
	target_head_y = head.position.y


func _unhandled_input(event):
	if event is InputEventMouseMotion and is_multiplayer_authority():
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-90), deg_to_rad(90))

func _physics_process(delta):
	if not is_multiplayer_authority():
		return

	var was_in_air = not is_on_floor()
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	##Ledge Climbing
	if is_ascending:
		global_position = lerp(global_position, ascend_target_position, delta * 5.0)
		if global_position.distance_to(ascend_target_position) < 0.1:
			is_ascending = false
			velocity = Vector3.ZERO
		return

	if not is_on_floor() and velocity.y > 0 and $RayCast3D.is_colliding():
		var collision_point = $RayCast3D.get_collision_point()
		ascend_target_position = collision_point + Vector3(0, capsule_shape.height / climable_height, 0)
		is_ascending = true
	##Jump
	if is_on_floor():
		has_crouch_jumped = false
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta
	
	if Input.is_action_just_pressed("quit"):
		$"../".exit_game(name.to_int())

	##Crouching Tuck up & Duck down
	if Input.is_action_pressed("crouch"):
		if not is_crouching:
			is_crouching = true
			rpc("sync_crouch_state", true, is_on_floor())
			_update_crouch_state()

			# Apply vertical boost if crouching mid-air
			if not is_on_floor() and not has_crouch_jumped:
				velocity.y += crouch_jump_boost
				has_crouch_jumped = true
	else:
		if is_crouching and not uncrouch_ray.is_colliding():
			is_crouching = false
			rpc("sync_crouch_state", false, is_on_floor())
			_update_crouch_state()

	# Horizontal movement
	var horizontal_velocity = Vector3.ZERO
	horizontal_velocity.x = direction.x * speed
	horizontal_velocity.z = direction.z * speed

	if is_on_floor():
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
	else:
		velocity.x = lerp(velocity.x, horizontal_velocity.x, 0.1)
		velocity.z = lerp(velocity.z, horizontal_velocity.z, 0.1)

	move_and_slide()

	# Post-movement logic
	var just_landed = was_in_air and is_on_floor()
	if just_landed and is_crouching:
		rpc("sync_crouch_state", is_crouching, true)
		
	head.position.y = lerp(head.position.y, target_head_y, delta * 10.0)


@rpc("any_peer", "reliable")
func sync_crouch_state(state: bool, was_on_floor: bool):
	is_crouching = state
	_update_crouch_state(was_on_floor)

func _update_crouch_state(was_on_floor := true):
	if is_crouching:
		capsule_shape.height = crouch_height
		if was_on_floor:
			collision_shape.position = original_position - Vector3(0, (stand_height - crouch_height) / 2.0, 0)
		else:
			collision_shape.position = original_position + Vector3(0, (stand_height - crouch_height) / 2.0, 0)
	else:
		capsule_shape.height = stand_height
		collision_shape.position = original_position

	var shape_top_y = collision_shape.position.y + (capsule_shape.height / 2.0)
	target_head_y = shape_top_y + head_offset_from_top


func Teleport_on_jump():
	var collision_point = $RayCast3D.get_collision_point()
	var new_position = collision_point + Vector3(0, capsule_shape.height / 2.0, 0)
	global_position = new_position
	velocity.y = 0
