class_name Ship
extends RigidBody2D

enum ControlMode { MANUAL, AUTOPILOT }

@export var SPEED_LIMITTER: bool = false
@export var BASE_THRUST: float = 5.0
@export var BASE_TORQUE: float = 150.0
@export var is_player: bool = false
@export var silhouette: Polygon2D

# local center of mass
var com_local: Vector2 = Vector2.ZERO
var thrust_mod: float = 0.0
var torque_mod: float = 0.0
var max_speed: float = 1000.0
var forces_state
var thrust_direction: Vector2 = Vector2.ZERO
var spin_direction: float = 0.0
var move_actions: Array[StringName] = [&"up", &"down", &"left", &"right", &"rot_left", &"rot_right"]
var control_mode: ControlMode = ControlMode.MANUAL

@onready var autopilot: DockingAutopilot = $DockingAutopilot


func _process(_delta: float) -> void:
	if not is_player:
		return
	if control_mode == ControlMode.AUTOPILOT:
		if not _manual_override():
			return
		autopilot.disengage()

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


func com_global() -> Vector2:
	return com_local * global_transform


func _manual_override() -> bool:
	for action in move_actions:
		if Input.is_action_just_pressed(action):
			return true
	return false


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	com_local = state.center_of_mass_local
	forces_state = state

	state.apply_central_impulse(thrust_direction * (BASE_THRUST + thrust_mod))
	state.apply_torque_impulse(spin_direction * (BASE_TORQUE + torque_mod))

	if SPEED_LIMITTER:
		state.linear_velocity = state.linear_velocity.limit_length(max_speed)
