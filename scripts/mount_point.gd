class_name MountPoint
extends Node2D

enum Mount { AIRLOCK, HARDPOINT }
enum Location { SHIP, STATION, WEAPON }

@export var mount: Mount = Mount.AIRLOCK
@export var location: Location = Location.SHIP
@export var highlight_color: Color = Color.WHITE
@export var mouseover_color: Color = Color.GREEN

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
