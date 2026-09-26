shader_type canvas_item;

uniform sampler2D tex : repeat_enable, filter_linear_mipmap;
uniform vec2 tile_size = vec2(1024.0);
uniform vec2 camera_pos = vec2(0.0);
uniform vec2 camera_zoom = vec2(1.0);
uniform float parallax = 1.0;

void fragment() {
	vec2 viewport = vec2(1.0) / SCREEN_PIXEL_SIZE;
	vec2 screen_px = SCREEN_UV * viewport;

	// Screen pixel -> world unit (origin at screen centre, undo zoom),
	// then slide by where the camera is looking.
	vec2 world = (screen_px - viewport * 0.5) / camera_zoom + camera_pos * parallax;

	// No fract() needed: repeat_enable wraps UVs outside 0..1 for us.
	COLOR = texture(tex, world / tile_size);
}
