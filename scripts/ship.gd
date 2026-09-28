class_name Ship
extends RigidBody2D

enum ControlMode { MANUAL, AUTOPILOT }

@export var SPEED_LIMITTER: bool = false
@export var BASE_THRUST: float = 5.0
@export var BASE_TORQUE: float = 150.0

var thrust_mod: float = 0.0
var torque_mod: float = 0.0
var max_speed: float = 1000.0
var forces_state
var thrust_direction: Vector2 = Vector2.ZERO
var spin_direction: float = 0.0
var move_actions: Array[StringName] = [&"up", &"down", &"left", &"right", &"rot_left", &"rot_right"]


func _process(_delta: float) -> void:
	thrust_direction = Vector2(
		Input.get_axis(&"left", &"right"),
		Input.get_axis(&"up", &"down"),
	).normalized()
	spin_direction = Input.get_axis(&"rot_left", &"rot_right")


func _physics_process(_delta: float) -> void:
	if not sleeping:
		return
	if thrust_direction != Vector2.ZERO or not is_zero_approx(spin_direction):
		sleeping = false


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	forces_state = state

	state.apply_central_impulse(thrust_direction * (BASE_THRUST + thrust_mod))
	state.apply_torque_impulse(spin_direction * (BASE_TORQUE + torque_mod))

	if SPEED_LIMITTER:
		state.linear_velocity = state.linear_velocity.limit_length(max_speed)
