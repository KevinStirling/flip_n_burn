class_name DockingAutopilot
extends Node

signal docked(anchor_mount: MountPoint)

enum Phase { IDLE, ALIGN, APPROACH, DOCKED }

## Distance out along the port axis where ship lines up before moving in
@export var standoff: float = 180.0
## Position error -> desired velocity. Units: 1/s. Att 100px error, wants 150 px/s
@export var pos_gain: float = 1.5
## Velocity error (px/s) that commands full thrust
@export var vel_err_full: float = 120.0
## Angle error -> desired spin. Units 1/s
@export var rot_gain: float = 3.0
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
@export var undock_impulse: float = 10.0

var phase: Phase = Phase.IDLE
var _mover: Ship
var _mover_mount: MountPoint
var _anchor_mount: MountPoint
var _anchor: PhysicsBody2D


func _ready() -> void:
	_mover = get_parent() as Ship
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_anchor_mount) or not is_instance_valid(_mover_mount):
		disengage()
		return

	var target: Transform2D = _anchor_mount.dock_target_for(_mover_mount)
	var outward: Vector2 = -_anchor_mount.global_transform.y.normalized()

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
					and _closing_speed(setpoint) < capture_speed_tol:
				_capture(target)
				return
		_:
			return
	_steer(setpoint, target.get_rotation(), speed_cap)


func engage(mover_mount: MountPoint, anchor_mount: MountPoint) -> void:
	_mover_mount = mover_mount
	_anchor_mount = anchor_mount
	_anchor = anchor_mount._body
	if _anchor is CollisionObject2D:
		_mover.add_collision_exception_with(_anchor)
	phase = Phase.ALIGN
	_mover.control_mode = Ship.ControlMode.AUTOPILOT
	_mover.freeze = false
	_mover.sleeping = false
	set_physics_process(true)


## handles both player aborted autopilot and player undocked
func disengage() -> void:
	if phase == Phase.IDLE:
		return
	if phase == Phase.DOCKED:
		var outward: Vector2 = -_anchor_mount.global_transform.y.normalized()
		DockLink.split(_mover, outward, undock_impulse)
		_mover_mount.docked_to = null
		_anchor_mount.docked_to = null
		_anchor_mount.docked_shell = null
		_mover_mount.set_dock_sensing(true)
		_anchor_mount.set_dock_sensing(true)
	phase = Phase.IDLE
	_mover.freeze = false
	_mover.control_mode = Ship.ControlMode.MANUAL
	_mover.thrust_direction = Vector2.ZERO
	_mover.spin_direction = 0.0
	_mover.sleeping = false
	set_physics_process(false)


## World velocity of the point `p`, treated as rigidly attached to the anchor.
func _anchor_vel_at(p: Vector2) -> Vector2:
	var rb := _anchor as RigidBody2D
	if rb == null:
		# this means its a station, does not move
		return Vector2.ZERO
	# velocity of the anchored point, whether its a craft or station
	var r := p - (rb as Ship).com_global() if rb is Ship else p - rb.global_position
	return rb.linear_velocity + rb.angular_velocity * Vector2(-r.y, r.x)


func _anchor_spin() -> float:
	var rb := _anchor as RigidBody2D
	return 0.0 if rb == null else rb.angular_velocity


func _steer(setpoint: Vector2, want_rot: float, speed_cap: float) -> void:
	# carry: what the mover must match just to hold position relative to the port.
	# correction: the part that actually closes the gap, and the only part capped.
	var carry := _anchor_vel_at(setpoint)
	var correction := ((setpoint - _mover.global_position) * pos_gain).limit_length(speed_cap)
	var desired_vel := carry + correction

	var thrust := ((desired_vel - _mover.linear_velocity) / vel_err_full).limit_length(1.0)
	_mover.thrust_direction = thrust if thrust.length() > 0.05 else Vector2.ZERO

	var ang_err := wrapf(want_rot - _mover.global_rotation, -PI, PI)
	var desired_spin := _anchor_spin() + clampf(ang_err * rot_gain, -max_spin, max_spin)
	_mover.spin_direction = clampf(
		(desired_spin - _mover.angular_velocity) / spin_err_full,
		-1.0,
		1.0,
	)


func _closing_speed(setpoint: Vector2) -> float:
	return (_mover.linear_velocity - _anchor_vel_at(setpoint)).length()


func _capture(target: Transform2D) -> void:
	DockLink.merge(_mover, _anchor, _mover_mount, _anchor_mount, target)
	phase = Phase.DOCKED
	set_physics_process(false)
	docked.emit(_anchor_mount)


func _settled(setpoint: Vector2, target: Transform2D, pos_tol: float, rot_tol: float) -> bool:
	if _mover.global_position.distance_to(setpoint) > pos_tol:
		return false
	return absf(wrapf(target.get_rotation() - _mover.global_rotation, -PI, PI)) <= rot_tol
