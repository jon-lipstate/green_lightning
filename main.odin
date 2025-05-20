package green_lightning

import "../runic/shaper"
import "../runic/ttf"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import la "core:math/linalg"
import glsl "core:math/linalg/glsl"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"
import stbi "vendor:stb/image"


width: i32 = 800
height: i32 = 600

// Global state
transform: Transform
drag_controller: DragController
empty_vao: u32
background_shader, font_shader: Shader
anti_aliasing_window_size: i32 = 1
enable_supersampling_anti_aliasing: bool = true
enable_control_points_visualization: bool = true
show_help: bool = true

curves_tbo: u32
curves_buffer: u32
glyphs_tbo: u32
glyphs_buffer: u32

setup_transform :: proc() {
	transform.fovy = math.to_radians_f32(60.0)
	transform.distance = 3.0
	transform.rotation = glsl.mat4(1.0)
	transform.position = glsl.vec4(0.0)
}
setup :: proc() -> bool {
	enable_debug_output()

	gl.GenVertexArrays(1, &empty_vao)
	fmt.println("Background VAO:", empty_vao)

	background_shader_loaded, ok := load_shader("shaders/background.vs", "shaders/background.fs")
	if !ok {return false}
	background_shader = background_shader_loaded

	font_shader_loaded, sok := load_shader("shaders/font.vs", "shaders/font.fs")
	if !sok {return false}
	font_shader = font_shader_loaded

	if !create_curve_buffers() {
		fmt.println("Failed to create curve buffers")
		return false
	}

	init_drag_controller(&drag_controller, &transform)

	return true
}

cleanup :: proc() {
	gl.DeleteProgram(background_shader.program)
	gl.DeleteProgram(font_shader.program)
	gl.DeleteVertexArrays(1, &empty_vao)

	if curves_buffer != 0 {
		gl.DeleteBuffers(1, &curves_buffer)
		gl.DeleteTextures(1, &curves_tbo)
		gl.DeleteBuffers(1, &glyphs_buffer)
		gl.DeleteTextures(1, &glyphs_tbo)
	}
}

main :: proc() {
	if !glfw.Init() {
		fmt.println("failed to init glfw")
		return
	}
	defer glfw.Terminate()

	major, minor, rev := glfw.GetVersion()
	fmt.printf("GLFW Version: %d.%d.%d\n", major, minor, rev)

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE)
	glfw.WindowHint(glfw.SRGB_CAPABLE, glfw.TRUE)

	when ODIN_DEBUG {
		glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, glfw.TRUE)
	}

	window := glfw.CreateWindow(width, height, "Green Lightning Bezier Curve Demo", nil, nil)
	if window == nil {
		fmt.println("failed to create window")
		return
	}
	defer glfw.DestroyWindow(window)

	glfw.MakeContextCurrent(window)

	// Load OpenGL functions
	gl.load_up_to(3, 3, glfw.gl_set_proc_address)

	// Print OpenGL version
	fmt.println("OpenGL Version:", gl.GetString(gl.VERSION))
	fmt.println("OpenGL Vendor:", gl.GetString(gl.VENDOR))
	fmt.println("OpenGL Renderer:", gl.GetString(gl.RENDERER))
	fmt.println("GLSL Version:", gl.GetString(gl.SHADING_LANGUAGE_VERSION))

	// Callbacks
	glfw.SetFramebufferSizeCallback(window, size_callback)
	glfw.SetMouseButtonCallback(window, mouse_button_callback)
	glfw.SetCursorPosCallback(window, mouse_callback)
	glfw.SetScrollCallback(window, scroll_callback)
	glfw.SetKeyCallback(window, key_callback)

	if !setup() {
		fmt.println("Failed to set up OpenGL resources")
		return
	}
	defer cleanup()
	setup_transform()

	// Create our test VAO for the bezier curve
	font_vao := create_test_vao()
	defer gl.DeleteVertexArrays(1, &font_vao)

	font, fok := ttf.load_font_from_path("../runic/arial.ttf", context.allocator)
	assert(fok == nil, "Failed to load font")
	engine := shaper.create_engine()
	font_id, ok := shaper.register_font(engine, font)
	buf, sok := shaper.shape_string(engine, font_id, "A")
	glyf, err := ttf.load_glyf_table(font)
	outline, ook := ttf.extract_glyph(transmute(^ttf.Glyf_Table)glyf, buf.glyphs[0].glyph_id)
	fmt.println("outline", outline, ook)
	if true do return
	for !glfw.WindowShouldClose(window) {
		process_input(window)

		fb_width, fb_height := glfw.GetFramebufferSize(window)
		gl.Viewport(0, 0, fb_width, fb_height)

		gl.ClearColor(0.0, 0.0, 0.0, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT)

		// Draw background
		gl.UseProgram(background_shader.program)
		gl.BindVertexArray(empty_vao)
		gl.DrawArrays(gl.TRIANGLE_STRIP, 0, 4)
		gl.BindVertexArray(0)

		// Enable blending for bezier curve rendering
		gl.Enable(gl.BLEND)
		gl.BlendEquation(gl.FUNC_ADD)
		gl.BlendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)

		// Calculate matrices
		aspect := f32(fb_width) / f32(fb_height)
		projection := get_projection_matrix(&transform, aspect)
		view := get_view_matrix(&transform)
		model := glsl.mat4(1.0)

		// Render the bezier curve
		render_curve(font_vao, font_shader.program, projection, view, model)

		// Disable blending
		gl.Disable(gl.BLEND)

		// Check for OpenGL errors
		error := gl.GetError()
		if error != gl.NO_ERROR {
			fmt.println("OpenGL error in main loop:", error)
		}

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
}

size_callback :: proc "c" (window: glfw.WindowHandle, w, h: c.int) {
	gl.Viewport(0, 0, w, h)
}
