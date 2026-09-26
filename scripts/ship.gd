class_name Ship
extends RigidBody2D

@export var SPEED_LIMITTER: bool = false
@export var BASE_THRUST: float = 5.0
@export var BASE_TORQUE: float = 150.0

var thrust_mod: float = 0.0
var torque_mod: float = 0.0
var max_speed: float = 1000.0
var forces_state
var move_actions: Array[StringName] = [&"up", &"down", &"left", &"right", &"rot_left", &"rot_right"]
var thrust_direction: Vector2 = Vector2.ZERO
var spin_direction: float = 0.0


func _process(delta: float) -> void:
	thrust_direction = Vector2(
		Input.get_axis(&"left", &"right"),
		Input.get_axis(&"up", &"down"),
	).normalized()
	spin_direction = Input.get_axis(&"rot_left", &"rot_right")


func _physics_process(delta: float) -> void:
	if !sleeping:
		return
	for action in move_actions:
		if Input.is_action_just_pressed(action):
			sleeping = false


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	forces_state = state

	if Input.is_action_pressed("up"):
		state.apply_central_impulse(Vector2(0, -(BASE_THRUST + thrust_mod)))
	if Input.is_action_pressed("down"):
		state.apply_central_impulse(Vector2(0, (BASE_THRUST + thrust_mod)))
	if Input.is_action_pressed("left"):
		state.apply_central_impulse(Vector2(-(BASE_THRUST + thrust_mod), 0))
	if Input.is_action_pressed("right"):
		state.apply_central_impulse(Vector2((BASE_THRUST + thrust_mod), 0))

	if Input.is_action_pressed("rot_right"):
		state.apply_torque_impulse((BASE_TORQUE + torque_mod))
	if Input.is_action_pressed("rot_left"):
		state.apply_torque_impulse(-(BASE_TORQUE + torque_mod))

	if SPEED_LIMITTER:
		state.linear_velocity = state.linear_velocity.limit_length(max_speed)
