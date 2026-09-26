class_name Ship
extends RigidBody2D

@export var SPEED_LIMITTER: bool = false

var thrust: float = 10.0
var torque: float = 100.0
var max_speed: float = 1000.0
var forces_state


func _physics_process(delta: float) -> void:
	pass


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	forces_state = state

	if Input.is_action_pressed("up"):
		state.apply_central_impulse(Vector2(0, -thrust))
	if Input.is_action_pressed("down"):
		state.apply_central_impulse(Vector2(0, thrust))
	if Input.is_action_pressed("left"):
		state.apply_central_impulse(Vector2(-thrust, 0))
	if Input.is_action_pressed("right"):
		state.apply_central_impulse(Vector2(thrust, 0))

	if Input.is_action_pressed("rot_right"):
		state.apply_torque_impulse(-torque)
	if Input.is_action_pressed("rot_left"):
		state.apply_torque_impulse(torque)

	if SPEED_LIMITTER:
		state.linear_velocity = state.linear_velocity.limit_length(max_speed)
