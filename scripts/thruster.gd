class_name Thruster
extends GPUParticles2D
## Thrusters can be placed on the ship and manually rotated so the x direction
## points in the direction of the exhaust. The emitting property will be automatically
## toggled based on its rotation and the ship' thrust vector

enum Role { TRANSLATION, ROTATION }

@export var role: Role = Role.TRANSLATION
@export_range(0.0, 1.0) var activation: float = 0.5

var _ship: Ship
var _exhuast: Vector2


func _ready() -> void:
	_ship = get_parent() as Ship
	_exhuast = Vector2.RIGHT.rotated(rotation)
	emitting = false


func _process(delta: float) -> void:
	if _ship == null:
		return
	emitting = _wants_translation() if role == Role.TRANSLATION else _wants_rotation()


func _wants_translation() -> bool:
	var want = _ship.thrust_direction
	if want == Vector2.ZERO:
		emitting = false
		return false

	# desired rotation based on the ship hull frame
	var local_want: Vector2 = want.rotated(-_ship.global_rotation)

	# this nodes local rotation is the exhaust direction. thruster pushes
	# opposite of the exhuast direction, so we check if the want direction
	# is opposite of the exhause direction.
	return _exhuast.dot(-local_want) >= activation


func _wants_rotation() -> bool:
	var spin = _ship.spin_direction
	if spin == 0.0:
		return false

	var arm = position - _ship.center_of_mass
	# fancy math to determine the "level arm" from the center of mass
	return signf(arm.cross(-_exhuast)) == signf(spin)
