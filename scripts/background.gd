extends ColorRect

@export var camera_override: Camera2D
## 1.0 tracks the camera exactly; lower values lag behind for depth.
@export_range(0.0, 1.0) var parallax: float = 1.0

var _camera: Camera2D


func _ready() -> void:
	material.set_shader_parameter("parallax", parallax)


func _process(_delta: float) -> void:
	if _camera == null or not _camera.is_inside_tree():
		_camera = camera_override if camera_override != null else get_viewport().get_camera_2d()
		if _camera == null:
			return

	material.set_shader_parameter("camera_pos", _camera.get_screen_center_position())
	material.set_shader_parameter("camera_zoom", _camera.zoom)
