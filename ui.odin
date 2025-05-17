package green_lightning

import "core:c"
import "core:fmt"
import "core:math"
import la "core:math/linalg"
import glsl "core:math/linalg/glsl"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"
import stbi "vendor:stb/image"

Transform :: struct {
	fovy:     f32,
	distance: f32,
	rotation: glsl.mat4,
	position: glsl.vec4,
}

DEFAULT_TRANSFORM :: Transform {
	fovy     = math.PI * 60.0 / 180,
	distance = 0.42,
	rotation = glsl.mat4(1.0),
	position = glsl.vec4(0.0),
}

get_projection_matrix :: proc "c" (transform: ^Transform, aspect: f32) -> glsl.mat4 {
	return glsl.mat4Perspective(transform.fovy, aspect, 0.002, 12.0)
}

get_view_matrix :: proc "c" (transform: ^Transform) -> glsl.mat4 {
	translation := glsl.mat4Translate(transform.position.xyz)
	look_at := glsl.mat4LookAt({0, 0, transform.distance}, {0, 0, 0}, {0, 1, 0})
	return look_at * glsl.mat4(transform.rotation) * translation
}

DragAction :: enum {
	None,
	Translate,
	Rotate_Turntable,
	Rotate_Trackball,
}

DragController :: struct {
	transform:            ^Transform,
	active_button:        i32,
	active_action:        DragAction,
	drag_x, drag_y:       f64,
	wrap_x, wrap_y:       f64,
	virtual_x, virtual_y: f64,
	drag_target:          glsl.vec3,
}

// Initialize the drag controller
init_drag_controller :: proc(controller: ^DragController, transform: ^Transform) {
	controller.transform = transform
	controller.active_button = -1
	controller.active_action = .None
}

// Reset the transform to default values
reset_transform :: proc "c" (controller: ^DragController) {
	controller.transform^ = Transform{}
	controller.active_button = -1
	controller.active_action = .None
}

// Helper to project mouse position to XY plane
unproject_mouse_position_to_xy_plane :: proc "c" (
	controller: ^DragController,
	window: glfw.WindowHandle,
	x, y: f64,
	result: ^glsl.vec3,
) -> bool {
	width, height := glfw.GetWindowSize(window)

	width_f64, height_f64 := f64(width), f64(height)

	projection := get_projection_matrix(controller.transform, f32(width_f64 / height_f64))
	view := get_view_matrix(controller.transform)

	rel_x := f32(x / width_f64 * 2.0 - 1.0)
	rel_y := f32(y / height_f64 * 2.0 - 1.0)

	clip_pos := [4]f32{rel_x, -rel_y, 0.5, 1.0}
	inv_mat := glsl.inverse(projection * view)
	world_pos := inv_mat * clip_pos
	world_pos *= 1.0 / world_pos.w

	inv_view := glsl.inverse(view)
	pos := [3]f32{inv_view[0, 3], inv_view[1, 3], inv_view[2, 3]}

	dir := la.normalize(world_pos.xyz - pos.xyz)
	t := -pos.z / dir.z

	result^ = pos + t * dir
	return t > 0.0
}


// Callback implementations
mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	if action == glfw.PRESS && drag_controller.active_button == -1 {
		drag_controller.active_button = button

		if (mods & glfw.MOD_CONTROL) != 0 {
			drag_controller.active_action = .Translate
		} else {
			if button == glfw.MOUSE_BUTTON_2 {
				drag_controller.active_action = .Translate
			} else if button == glfw.MOUSE_BUTTON_3 {
				drag_controller.active_action = .Rotate_Turntable
			} else {
				drag_controller.active_action = .Rotate_Trackball
			}
		}

		drag_controller.drag_x, drag_controller.drag_y = glfw.GetCursorPos(window)
		drag_controller.wrap_x = math.nan_f64()
		drag_controller.wrap_y = math.nan_f64()
		drag_controller.virtual_x = drag_controller.drag_x
		drag_controller.virtual_y = drag_controller.drag_y

		target: glsl.vec3
		ok := unproject_mouse_position_to_xy_plane(
			&drag_controller,
			window,
			drag_controller.drag_x,
			drag_controller.drag_y,
			&target,
		)
		drag_controller.drag_target = ok ? target : glsl.vec3(0)
	} else if action == glfw.RELEASE && drag_controller.active_button == button {
		drag_controller.active_button = -1
		drag_controller.active_action = .None
		drag_controller.drag_x = 0
		drag_controller.drag_y = 0
		drag_controller.wrap_x = math.nan_f64()
		drag_controller.wrap_y = math.nan_f64()
		drag_controller.virtual_x = 0
		drag_controller.virtual_y = 0
		drag_controller.drag_target = glsl.vec3(0)
	}
}

mouse_callback :: proc "c" (window: glfw.WindowHandle, x_pos, y_pos: f64) {
	if drag_controller.active_action == .None {return}

	width, height := glfw.GetWindowSize(window)

	width_f64, height_f64 := f64(width), f64(height)

	delta_x := x_pos - drag_controller.drag_x
	delta_y := y_pos - drag_controller.drag_y

	if !math.is_nan(drag_controller.wrap_x) && !math.is_nan(drag_controller.wrap_y) {
		wrap_delta_x := x_pos - drag_controller.wrap_x
		wrap_delta_y := y_pos - drag_controller.wrap_y

		if wrap_delta_x * wrap_delta_x + wrap_delta_y * wrap_delta_y <
		   delta_x * delta_x + delta_y * delta_y {
			delta_x = wrap_delta_x
			delta_y = wrap_delta_y
			drag_controller.wrap_x = math.nan_f64()
			drag_controller.wrap_y = math.nan_f64()
		}
	}

	drag_controller.drag_x = x_pos
	drag_controller.drag_y = y_pos

	target_x := x_pos
	target_y := y_pos
	changed := false

	if target_x < 0 {
		target_x += width_f64 - 1
		changed = true
	} else if target_x >= width_f64 {
		target_x -= width_f64 - 1
		changed = true
	}

	if target_y < 0 {
		target_y += height_f64 - 1
		changed = true
	} else if target_y >= height_f64 {
		target_y -= height_f64 - 1
		changed = true
	}

	if changed {
		glfw.SetCursorPos(window, target_x, target_y)
		drag_controller.wrap_x = target_x
		drag_controller.wrap_y = target_y
	}

	// Handle different actions
	if drag_controller.active_action == .Translate {
		drag_controller.virtual_x += delta_x
		drag_controller.virtual_y += delta_y

		target: glsl.vec3
		ok := unproject_mouse_position_to_xy_plane(
			&drag_controller,
			window,
			drag_controller.virtual_x,
			drag_controller.virtual_y,
			&target,
		)
		if ok {
			x := drag_controller.transform.position.x
			y := drag_controller.transform.position.y
			delta := target - drag_controller.drag_target
			drag_controller.transform.position.x = math.clamp(x + delta.x, -4.0, 4.0)
			drag_controller.transform.position.y = math.clamp(y + delta.y, -4.0, 4.0)
		}
	} else if drag_controller.active_action == .Rotate_Turntable {
		size := math.min(width_f64, height_f64)
		rx := glsl.mat4Rotate([3]f32{0, 0, 1}, f32(delta_x / size * math.PI))
		ry := glsl.mat4Rotate([3]f32{1, 0, 0}, f32(delta_y / size * math.PI))
		drag_controller.transform.rotation = ry * drag_controller.transform.rotation * rx
	} else if drag_controller.active_action == .Rotate_Trackball {
		size := math.min(width_f64, height_f64)
		rx := glsl.mat4Rotate([3]f32{0, 1, 0}, f32(delta_x / size * math.PI))
		ry := glsl.mat4Rotate([3]f32{1, 0, 0}, f32(delta_y / size * math.PI))
		drag_controller.transform.rotation = ry * rx * drag_controller.transform.rotation
	}
}

scroll_callback :: proc "c" (window: glfw.WindowHandle, x_offset, y_offset: f64) {
	factor := math.clamp(1.0 - f32(y_offset) / 10.0, 0.1, 1.9)
	drag_controller.transform.distance = math.clamp(
		drag_controller.transform.distance * factor,
		0.01,
		10.0,
	)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if action != glfw.PRESS {
		return
	}

	switch key {
	case glfw.KEY_R:
		reset_transform(&drag_controller)

	case glfw.KEY_C:
		enable_control_points_visualization = !enable_control_points_visualization

	case glfw.KEY_A:
		enable_supersampling_anti_aliasing = !enable_supersampling_anti_aliasing

	case glfw.KEY_0:
		anti_aliasing_window_size = 0

	case glfw.KEY_1:
		anti_aliasing_window_size = 1

	case glfw.KEY_2:
		anti_aliasing_window_size = 20

	case glfw.KEY_3:
		anti_aliasing_window_size = 40

	case glfw.KEY_S:
		anti_aliasing_window_size = 1
		enable_supersampling_anti_aliasing = true

	case glfw.KEY_H:
		show_help = !show_help
	}
}

process_input :: proc(window: glfw.WindowHandle) {
	if glfw.GetKey(window, glfw.KEY_ESCAPE) == glfw.PRESS {
		glfw.SetWindowShouldClose(window, true)
	}
}
