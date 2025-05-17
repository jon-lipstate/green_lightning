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

create_curve_buffers :: proc() -> bool {
	// Create buffer for curves
	gl.GenBuffers(1, &curves_buffer)
	gl.BindBuffer(gl.TEXTURE_BUFFER, curves_buffer)

	// Define a simple test curve (quadratic Bézier curve)
	// Format: p0, p1, p2 as 2D points (6 floats total per curve)
	curve_data := [6]f32 {
		-0.5,
		-0.5, // p0
		0.0,
		0.5, // p1
		0.5,
		-0.5, // p2
	}

	gl.BufferData(gl.TEXTURE_BUFFER, size_of(curve_data), &curve_data, gl.STATIC_DRAW)

	// Create texture buffer for curves
	gl.GenTextures(1, &curves_tbo)
	gl.BindTexture(gl.TEXTURE_BUFFER, curves_tbo)
	gl.TexBuffer(gl.TEXTURE_BUFFER, gl.RG32F, curves_buffer)

	// Create buffer for glyphs
	gl.GenBuffers(1, &glyphs_buffer)
	gl.BindBuffer(gl.TEXTURE_BUFFER, glyphs_buffer)

	// Define a single glyph that references our test curve
	// Format: start index, count
	glyph_data := [2]i32 {
		0,
		1, // Start at index 0, count of 1 curve
	}

	gl.BufferData(gl.TEXTURE_BUFFER, size_of(glyph_data), &glyph_data, gl.STATIC_DRAW)

	// Create texture buffer for glyphs
	gl.GenTextures(1, &glyphs_tbo)
	gl.BindTexture(gl.TEXTURE_BUFFER, glyphs_tbo)
	gl.TexBuffer(gl.TEXTURE_BUFFER, gl.RG32I, glyphs_buffer)

	return true
}

// Simple data for a Bezier curve to render
create_test_vao :: proc() -> u32 {
	vao, vbo: u32
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)

	gl.BindVertexArray(vao)

	// Create a simple quad to render our curve on
	vertices := [?]f32 {
		// position (2D)    // uv         // index (glyph)
		-1.0,
		-1.0,
		0.0,
		0.0,
		0,
		1.0,
		-1.0,
		1.0,
		0.0,
		0,
		-1.0,
		1.0,
		0.0,
		1.0,
		0,
		-1.0,
		1.0,
		0.0,
		1.0,
		0,
		1.0,
		-1.0,
		1.0,
		0.0,
		0,
		1.0,
		1.0,
		1.0,
		1.0,
		0,
	}

	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

	// Position attribute (vec2)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	// UV attribute (vec2)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), 2 * size_of(f32))
	gl.EnableVertexAttribArray(1)

	// Index attribute (int)
	gl.VertexAttribIPointer(2, 1, gl.INT, 5 * size_of(f32), uintptr(4 * size_of(f32)))
	gl.EnableVertexAttribArray(2)

	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	return vao
}

render_curve :: proc() {
	gl.UseProgram(font_shader.program)

	// Bind our texture buffer objects
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_BUFFER, glyphs_tbo)
	gl.Uniform1i(gl.GetUniformLocation(font_shader.program, "glyphs"), 0)

	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_BUFFER, curves_tbo)
	gl.Uniform1i(gl.GetUniformLocation(font_shader.program, "curves"), 1)

	// Set other uniforms
	gl.Uniform4f(gl.GetUniformLocation(font_shader.program, "color"), 1.0, 1.0, 1.0, 1.0)
	gl.Uniform1f(
		gl.GetUniformLocation(font_shader.program, "antiAliasingWindowSize"),
		f32(anti_aliasing_window_size),
	)
	gl.Uniform1i(
		gl.GetUniformLocation(font_shader.program, "enableSuperSamplingAntiAliasing"),
		i32(enable_supersampling_anti_aliasing),
	)
	gl.Uniform1i(
		gl.GetUniformLocation(font_shader.program, "enableControlPointsVisualization"),
		i32(enable_control_points_visualization),
	)

	// Draw the test curve
	gl.BindVertexArray(curve_vao)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)
	gl.BindVertexArray(0)

	gl.UseProgram(0)
}
