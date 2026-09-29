class_name MountPoint
extends Node2D

enum Mount { AIRLOCK, HARDPOINT }
enum Location { SHIP, STATION, WEAPON }

@export var mount: Mount = Mount.AIRLOCK
@export var location: Location = Location.SHIP
@export var highlight_color: Color = Color.WHITE
@export var mouseover_color: Color = Color.GREEN
@export var dock_gap: float = 0.0
@export var debug_docking_ghost_enabled: bool = true

var in_range: bool = false
var _ship: Ship
var _default_color: Color
var _obj_in_radius: MountPoint

@onready var mount_radius: Area2D = %MountRadius
@onready var mount_point: Polygon2D = %MountPoint
@onready var line_point: Marker2D = %IndicatorLinePoint
@onready var hover_radius: Area2D = %HoverRadius


## detect if a mount area enters another mount area
## determine where each mount is located (if mount parent is ship)
## if mount area is ship (player ship), and both mounts are airlock, move player ship to non player ship airlock
func _ready() -> void:
	if location == Location.SHIP:
		_ship = get_parent() as Ship

	_default_color = mount_point.color
	mount_radius.area_entered.connect(enter_mount_radius)
	mount_radius.area_exited.connect(exit_mount_radius)
	hover_radius.mouse_entered.connect(mouse_entered)
	hover_radius.mouse_exited.connect(mouse_exited)
	hover_radius.input_event.connect(_on_hover_input)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if in_range:
		draw_line(
			to_local(line_point.global_position),
			to_local(_obj_in_radius.line_point.global_position),
			Color.GREEN,
			2.0,
		)

		if location != Location.STATION or _obj_in_radius._ship == null:
			return

		if debug_docking_ghost_enabled:
			# draw an outline of the ships target position for docking
			var target := dock_target_for(_obj_in_radius)
			draw_set_transform_matrix(global_transform.affine_inverse() * target)
			draw_polyline(_ghost_points(_obj_in_radius._ship), Color(0.2, 1.0, 0.4, 0.45), 1.0)
			draw_set_transform_matrix(Transform2D.IDENTITY)


## world transfor the must much reach to mount the statsion. uses dock_gap
## to prevent unwanted physics collisions with the dock
## TODO can remove dock_gap by just making the mounting point on a seperate layer
func dock_target_for(ship_mount: MountPoint) -> Transform2D:
	var ship := ship_mount._ship
	var mount_local := ship.global_transform.affine_inverse() * ship_mount.global_transform
	return global_transform \
			* Transform2D(PI, Vector2(0, -dock_gap)) \
			* mount_local.affine_inverse()


func mouse_exited() -> void:
	if location != Location.STATION:
		return
	mount_point.color = highlight_color
	if !in_range:
		mount_point.color = _default_color


func mouse_entered() -> void:
	print("mouse entered")
	if location != Location.STATION:
		return
	if in_range:
		mount_point.color = mouseover_color


func enter_mount_radius(area: Area2D) -> void:
	if not area.get_parent() is MountPoint:
		return
	_obj_in_radius = area.get_parent() as MountPoint

	print(mount, " mount point detected for ", location)
	in_range = true
	if location == Location.STATION:
		mount_point.color = highlight_color
	print("line_point pos: ", line_point.global_position)


func exit_mount_radius(area: Area2D) -> void:
	if not area.get_parent() is MountPoint:
		return
	_obj_in_radius = null
	print(mount, " mount point has left radius of ", location)
	in_range = false
	if location == Location.STATION:
		mount_point.color = _default_color


func _on_hover_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if location != Location.STATION or not in_range or _obj_in_radius == null:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	var ship: Ship = _obj_in_radius._ship
	if ship == null:
		return

	if ship.autopilot.phase == DockingAutopilot.Phase.IDLE:
		ship.autopilot.engage(_obj_in_radius, self)
	else:
		ship.autopilot.disengage() # click again to cancel or undock, probably want to change this later
		get_viewport().set_input_as_handled()


func _ghost_points(ship: Ship) -> PackedVector2Array:
	var pts := (ship.get_node("Polygon2D") as Polygon2D).polygon.duplicate()
	pts.append(pts[0])
	return pts
