extends RigidBody3D

# Nodes

@onready var head = $Smoothing/head
@onready var pitch = $Smoothing/head/Pitch
@onready var ground_ray_cast = $GroundRayCast
@onready var can_stand_ray_cast = $CanStandRayCast
@onready var standing_collision_shape = $standingCollisionShape
@onready var crouching_collision_shape = $crouchingCollisionShape
@onready var csg_mesh_3d = $Smoothing/CSGMesh3D

# Control Variables

@export var walking_speed = 4500.0
@export var crouch_speed = 1500.0
@export var max_speed = 8.5
@export var max_crouch_speed = 4.5
@export var max_air_speed = 6.5
@export var drag = 0.15
@export var jump_strength = 600
@export var lerp_speed = 15.0
@export var mouse_sens = 0.15

# Helper Variables

var direction = Vector3.ZERO
var current_speed = Vector3.ZERO

var jumpTimer = 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	
	# Mouse logic
	
	if event is InputEventMouseMotion:
		head.rotate_y(deg_to_rad(-event.relative.x * mouse_sens))
		pitch.rotate_x(deg_to_rad(-event.relative.y * mouse_sens))
		
		# Prevent from looking too far up or down
		pitch.rotation.x = clamp(pitch.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	
	# Press esc for mouse, click anywhere in game to lock it again
	
	if Input.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	current_speed = walking_speed
	
	# Get the input vector
	var input_dir = Input.get_vector("left", "right", "forward", "backward")

	# Calculate the movement direction relative to the camera
	var camera_transform = head.global_transform
	var camera_basis = camera_transform.basis

	var forward_dir = -camera_basis.z.normalized()
	var right_dir = camera_basis.x.normalized()

	direction = (right_dir * input_dir.x - forward_dir * input_dir.y)
	
	# Start the jump buffer timer
	if Input.is_action_just_pressed("jump"):
		jumpTimer = 0.1
	jumpTimer -= delta
	
	if jumpTimer > 0 and ground_ray_cast.is_colliding():
		jumpTimer = 0.0
		apply_central_impulse(Vector3.UP * jump_strength * delta)
		
	# Crouching logic
	if Input.is_action_pressed("crouch"):
		
		# Switch the collision shapes
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
		
		# Smootly change the mesh and camera height/position
		csg_mesh_3d.mesh.height = lerp(csg_mesh_3d.mesh.height, 1.1, delta * lerp_speed)
		csg_mesh_3d.position.y = lerp(csg_mesh_3d.position.y, -0.45, delta * lerp_speed)
		head.position.y = lerp(head.position.y, -0.45, delta * lerp_speed)
		
		current_speed = crouch_speed
	elif (!can_stand_ray_cast.is_colliding()):
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		csg_mesh_3d.mesh.height = 2
		csg_mesh_3d.position = Vector3.ZERO
		head.position.y = lerp(head.position.y, 0.8, delta * lerp_speed)
	
	apply_central_force(direction * current_speed * delta)

# This section needs to be in _integrate_forces() because the code directly manipulates the velocity of the rb,
# if this is done outside of _integrate_forces() then this could break physics. (For more info check out godots documentation)
func _integrate_forces(state):
	
	var xz_velocity = Vector2(state.linear_velocity.x, state.linear_velocity.z)
	
	# Apply drag if the rigid body is on the ground
	if ground_ray_cast.is_colliding():
		var drag_force = -drag * state.linear_velocity
		state.linear_velocity += drag_force
		
		# Max speed while on ground
		if xz_velocity.length() > max_speed:
			
			# Limit X and Z velocity
			xz_velocity = Vector2(state.linear_velocity.x, state.linear_velocity.z)
			var limitedVelXZ = xz_velocity.normalized() * max_speed
			state.linear_velocity.x = limitedVelXZ.x
			state.linear_velocity.z = limitedVelXZ.y
	else:
		
		# Max speed while in air
		if xz_velocity.length() > max_air_speed:
			
			# Limit X and Z velocity
			xz_velocity = Vector2(state.linear_velocity.x, state.linear_velocity.z)
			var limitedVelXZ = xz_velocity.normalized() * max_air_speed
			state.linear_velocity.x = limitedVelXZ.x
			state.linear_velocity.z = limitedVelXZ.y
	
	# Stop the character if speed is low enough
	if state.linear_velocity.length() < 0.1:
		state.linear_velocity = Vector3.ZERO
	
