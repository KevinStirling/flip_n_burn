class_name DockingAutopilot
extends Node

signal docked(station_mount: MountPoint)

enum Phase { IDLE, ALIGN, APPROACH, DOCKED }

## Distance out along the port axis where ship lines up before moving in
@export var standoff: float = 180.0
## Position error -> desired velocity. Units: 1/s. Att 100px error, wants 150 px/s
@export var pos_gain: float = 1.5
## Velocity error (px/s) that commands full thrust
@export var vel_err_full: float = 120.0
## Angle error -> desired spin. Units 1/s
@export var rot_gan: float = 3.0
## Angular velocity error (rad/s) that commads full torque
@export var spin_err_full: float = 1.5
@export var cruise_speed: float = 400.0
@export var approach_speed: float = 45.0
@export var max_spin: float = 2.0
@export var align_pos_tol: float = 15.0
@export var align_rot_tol: float = 0.05
@export var capture_pos_tol: float = 5.0
@export var capture_rot_tol: float = 0.03
@export var capture_speed_tol: float = 20.0

var phase: Phase = Phase.IDLE
var _ship: Ship
var _ship_mount: MountPoint
var _station_mount: MountPoint


func _ready() -> void:
	_ship = get_parent() as Ship
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_station_mount) or not is_instance_valid(_ship_mount):
		disengage()
		return

	var target: Transform2D = _station_mount.dock_target_for(_ship_mount)
	var outward: Vector2 = -_station_mount.global_transform.y.normalized()

	var setpoint: Vector2
	var speed_cap: float

	match phase:
		Phase.ALIGN:
			setpoint = target.origin + outward * standoff
			speed_cap = cruise_speed
			if _settled(setpoint, target, align_pos_tol, align_rot_tol):
				phase = Phase.APPROACH
		Phase.APPROACH:
			setpoint = target.origin
			speed_cap = approach_speed
			if _settled(setpoint, target, capture_pos_tol, capture_rot_tol) \
					and _ship.linear_velocity.length() < capture_speed_tol:
				_capture(target)
				return
		_:
			return
	_steer(setpoint, target.get_rotation(), speed_cap)


func engage(ship_mount: MountPoint, station_mount: MountPoint) -> void:
	_ship_mount = ship_mount
	_station_mount = station_mount
	phase = Phase.ALIGN
	_ship.control_mode = Ship.ControlMode.AUTOPILOT
	_ship.freeze = false
	_ship.sleeping = false
	set_physics_process(true)


## handles both player aborted autopilot and player undocked
func disengage() -> void:
	if phase == Phase.IDLE:
		return
	phase = Phase.IDLE
	_ship.freeze = false
	_ship.control_mode = Ship.ControlMode.MANUAL
	_ship.thrust_direction = Vector2.ZERO
	_ship.spin_direction = 0.0
	_ship.sleeping = false
	set_physics_process(false)


func _steer(setpoint: Vector2, want_rot: float, speed_cap: float) -> void:
	var desired_vel := ((setpoint - _ship.global_position) * pos_gain).limit_length(speed_cap)
	var thrust := ((desired_vel - _ship.linear_velocity) / vel_err_full).limit_length(1.0)
	_ship.thrust_direction = thrust if thrust.length() > 0.05 else Vector2.ZERO

	var ang_err := wrapf(want_rot - _ship.global_rotation, -PI, PI)
	var desired_spin := clampf(ang_err * rot_gan, -max_spin, max_spin)
	_ship.spin_direction = clampf(
		(desired_spin - _ship.angular_velocity) / spin_err_full,
		-1.0,
		1.0,
	)


func _capture(target: Transform2D) -> void:
	_ship.thrust_direction = Vector2.ZERO
	_ship.spin_direction = 0.0
	_ship.linear_velocity = Vector2.ZERO
	_ship.angular_velocity = 0.0
	_ship.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	_ship.freeze = true
	_ship.global_transform = target
	phase = Phase.DOCKED
	docked.emit(_station_mount)


func _settled(setpoint: Vector2, target: Transform2D, pos_tol: float, rot_tol: float) -> bool:
	if _ship.global_position.distance_to(setpoint) > pos_tol:
		return false
	return absf(wrapf(target.get_rotation() - _ship.global_rotation, -PI, PI)) <= rot_tol
