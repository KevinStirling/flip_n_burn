class_name MountPoint
extends Node2D

enum Mount { AIRLOCK, HARDPOINT }
enum Body {
	NONE,
	FIXED,
	CRAFT,
}

static var selected: MountPoint = null
static var hovered: MountPoint = null

@export var mount: Mount = Mount.AIRLOCK
@export var selected_color: Color = Color.BLUE
@export var highlight_color: Color = Color.WHITE
@export var mouseover_color: Color = Color.GREEN
@export var dock_gap: float = 0.0
@export var debug_docking_ghost_enabled: bool = true
@export var command_range: float = 1500.0

## derived enum	to describe the type of body the mount point is associated with
var body_kind: Body:
	get:
		if _craft != null && _craft.autopilot != null:
			return Body.CRAFT
		return Body.FIXED if _body != null else Body.NONE
var docked_to: MountPoint = null
var docked_shell: Ship = null
var _body: PhysicsBody2D # always set
var _craft: Ship # null if the body is a stationary body (i.e. station)
var _default_color: Color
var _obj_in_radius: MountPoint
var _candidates: Array[MountPoint] = []

@onready var mount_radius: Area2D = %MountRadius
@onready var mount_point: Polygon2D = %MountPoint
@onready var line_point: Marker2D = %IndicatorLinePoint
@onready var hover_radius: Area2D = %HoverRadius


## returns [anchor, mover] for an explicitly chosen pair, or [] if neither side can fly.
static func resolve_roles(first: MountPoint, second: MountPoint) -> Array:
	var f_fly := first.body_kind == Body.CRAFT
	var s_fly := second.body_kind == Body.CRAFT

	# station case: the craft flies
	if f_fly and not s_fly:
		return [second, first]
	if s_fly and not f_fly:
		return [first, second]
	# two fixed bodies, nothing to do
	if not f_fly and not s_fly:
		return []

	# both can fly: the player holds station, the module comes to it
	if first._is_player() and not second._is_player():
		return [first, second]
	if second._is_player() and not first._is_player():
		return [second, first]
	return [second, first] # tie: destination is the second click


## detect if a mount area enters another mount area
## determine where each mount is located (if mount parent is ship)
## if mount area is ship (player ship), and both mounts are airlock, move player ship to non player ship airlock
func _ready() -> void:
	add_to_group(&"mount_points")
	_resolve_body()
	_default_color = mount_point.color
	mount_radius.area_entered.connect(enter_mount_radius)
	mount_radius.area_exited.connect(exit_mount_radius)
	hover_radius.mouse_entered.connect(mouse_entered)
	hover_radius.mouse_exited.connect(mouse_exited)
	hover_radius.input_event.connect(_on_hover_input)


func _process(_delta: float) -> void:
	mount_point.color = _state_color()
	queue_redraw()


func _draw() -> void:
	if in_range():
		draw_line(
			to_local(line_point.global_position),
			to_local(nearest_candidate().line_point.global_position),
			Color.GREEN,
			2.0,
		)

		if body_kind != Body.FIXED or _obj_in_radius.body_kind == Body.NONE:
			return

		if debug_docking_ghost_enabled:
			# draw an outline of the ships target position for docking
			var target := dock_target_for(_obj_in_radius)
			draw_set_transform_matrix(global_transform.affine_inverse() * target)
			draw_polyline(_ghost_points(_obj_in_radius._ship), Color(0.2, 1.0, 0.4, 0.45), 1.0)
			draw_set_transform_matrix(Transform2D.IDENTITY)


## _resolve_body when node is reparented (dock / undocked)
func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED:
		_resolve_body()


func in_range() -> bool:
	return not _candidates.is_empty()


## world transfor the must much reach to mount the statsion. uses dock_gap
## to prevent unwanted physics collisions with the dock
## TODO can remove dock_gap by just making the mounting point on a seperate layer
func dock_target_for(mover_mount: MountPoint) -> Transform2D:
	var ship := mover_mount._craft
	var mount_local := ship.global_transform.affine_inverse() * mover_mount.global_transform
	return global_transform \
			* Transform2D(PI, Vector2(0, -dock_gap)) \
			* mount_local.affine_inverse()


## iterate through the candidates and determine the closest option
func nearest_candidate() -> MountPoint:
	var best: MountPoint = null
	var best_d := INF
	for c in _candidates:
		if not is_instance_valid(c):
			continue
		var d := global_position.distance_squared_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


func mouse_exited() -> void:
	if body_kind != Body.FIXED:
		return
	mount_point.color = highlight_color
	if !in_range():
		mount_point.color = _default_color


func mouse_entered() -> void:
	if body_kind != Body.FIXED:
		return
	if in_range():
		mount_point.color = mouseover_color


func enter_mount_radius(area: Area2D) -> void:
	var other := area.get_parent() as MountPoint
	if other == null or not _compatible(other):
		return
	if not _candidates.has(other):
		_candidates.append(other)
	mount_point.color = highlight_color


func exit_mount_radius(area: Area2D) -> void:
	var other := area.get_parent() as MountPoint
	if other == null:
		return
	_candidates.erase(other)
	if _candidates.is_empty():
		mount_point.color = _default_color


func _is_player() -> bool:
	return _craft != null and _craft.is_player


func _state_color() -> Color:
	if selected == self:
		return selected_color
	if hovered == self:
		return mouseover_color
	if in_range():
		return highlight_color
	return _default_color


func _compatible(other: MountPoint) -> bool:
	if other._body == _body:
		return false # own hull - see below
	if docked_to != null or other.docked_to != null:
		return false # already mated
	return other.mount == mount # airlock<->airlock, hardpoint<->hardpoint


func _resolve_body() -> void:
	_body = get_parent() as PhysicsBody2D
	_craft = _body.get_parent() as Ship


func _can_maneuver() -> bool:
	return _craft != null and _craft.autopilot != null


func _on_hover_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()

	# mid-docking event, click cancels
	var live := _live_autopilot()
	if live != null:
		live.disengage()
		selected = null
		return

	if not is_instance_valid(selected):
		# first click, arm
		selected = self
		return
	if selected == self:
		# clicked arm again, cancel
		selected = null
		return
	if not selected._compatible(self):
		# invalid pair, reset seleted to self
		selected = self
		return

	var roles := resolve_roles(selected, self)
	selected = null
	if roles.is_empty():
		return
	var mover_mount: MountPoint = roles[1]
	mover_mount._craft.autopilot.engage(mover_mount, roles[0])


## The autopilot a click on this mount should cancel: this craft's own if it is flying,
## otherwise the one belonging to a module docked here.
func _live_autopilot() -> DockingAutopilot:
	if _craft != null and _craft.autopilot != null and _craft.autopilot.phase != DockingAutopilot.Phase.IDLE:
		return _craft.autopilot
	var shell = docked_shell if docked_shell != null else (docked_to.docked_shell if docked_to != null else null)
	return shell.autopilot if shell != null else null


func _ghost_points(ship: Ship) -> PackedVector2Array:
	var pts := (ship.get_node("Polygon2D") as Polygon2D).polygon.duplicate()
	pts.append(pts[0])
	return pts
