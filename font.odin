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
	fmt.println("Creating curve buffers...")

	// Delete any existing buffers/textures first (in case this gets called more than once)
	if curves_buffer != 0 {
		gl.DeleteBuffers(1, &curves_buffer)
		gl.DeleteTextures(1, &curves_tbo)
		gl.DeleteBuffers(1, &glyphs_buffer)
		gl.DeleteTextures(1, &glyphs_tbo)
	}

	// Create buffer for curves
	gl.GenBuffers(1, &curves_buffer)
	gl.BindBuffer(gl.TEXTURE_BUFFER, curves_buffer)

	// Define curve data - make sure it has the right format
	// Each curve is 3 vec2 points = 6 floats
	curve_data := [6]f32 {
		-0.5,
		-0.5, // p0 
		0.0,
		0.5, // p1
		0.5,
		-0.5, // p2
	}

	gl.BufferData(gl.TEXTURE_BUFFER, size_of(curve_data), &curve_data, gl.STATIC_DRAW)

	// Create and bind texture buffer for curves
	gl.GenTextures(1, &curves_tbo)
	gl.BindTexture(gl.TEXTURE_BUFFER, curves_tbo)
	gl.TexBuffer(gl.TEXTURE_BUFFER, gl.RG32F, curves_buffer)

	// Check for errors
	error := gl.GetError()
	if error != gl.NO_ERROR {
		fmt.println("OpenGL error after curve buffer setup:", error)
		return false
	}

	// Create buffer for glyphs
	gl.GenBuffers(1, &glyphs_buffer)
	gl.BindBuffer(gl.TEXTURE_BUFFER, glyphs_buffer)

	// Define glyph data
	// Format: start index, count of curves
	glyph_data := [2]i32{0, 1}

	gl.BufferData(gl.TEXTURE_BUFFER, size_of(glyph_data), &glyph_data, gl.STATIC_DRAW)

	// Create and bind texture buffer for glyphs
	gl.GenTextures(1, &glyphs_tbo)
	gl.BindTexture(gl.TEXTURE_BUFFER, glyphs_tbo)
	gl.TexBuffer(gl.TEXTURE_BUFFER, gl.RG32I, glyphs_buffer)

	// Check for errors again
	error = gl.GetError()
	if error != gl.NO_ERROR {
		fmt.println("OpenGL error after glyph buffer setup:", error)
		return false
	}

	fmt.println("Curve buffers created successfully")
	fmt.println("Curves buffer ID:", curves_buffer)
	fmt.println("Curves TBO ID:", curves_tbo)
	fmt.println("Glyphs buffer ID:", glyphs_buffer)
	fmt.println("Glyphs TBO ID:", glyphs_tbo)

	return true
}

// Create a quad to render our curve on
create_test_vao :: proc() -> u32 {
	fmt.println("Creating test VAO...")

	vao, vbo, ebo: u32
	gl.GenVertexArrays(1, &vao)
	gl.GenBuffers(1, &vbo)
	gl.GenBuffers(1, &ebo)

	// Data for a quad to render our curve on
	vertices := [?]f32 {
		// pos     // uv     // buffer index
		-0.5,
		-0.5,
		0.0,
		0.0,
		0, // bottom left
		0.5,
		-0.5,
		1.0,
		0.0,
		0, // bottom right
		0.5,
		0.5,
		1.0,
		1.0,
		0, // top right
		-0.5,
		0.5,
		0.0,
		1.0,
		0, // top left
	}

	indices := [?]u32 {
		0,
		1,
		2, // first triangle
		2,
		3,
		0, // second triangle
	}

	// Bind the VAO first, then bind and set vertex buffers
	gl.BindVertexArray(vao)

	// Bind and initialize VBO
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, size_of(vertices), &vertices, gl.STATIC_DRAW)

	// Bind and initialize EBO
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, size_of(indices), &indices, gl.STATIC_DRAW)

	// Set up vertex attribute pointers
	// Position attribute (vec2)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(0))
	gl.EnableVertexAttribArray(0)

	// UV attribute (vec2)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, 5 * size_of(f32), uintptr(2 * size_of(f32)))
	gl.EnableVertexAttribArray(1)

	// Buffer index attribute (int)
	gl.VertexAttribIPointer(2, 1, gl.INT, 5 * size_of(f32), uintptr(4 * size_of(f32)))
	gl.EnableVertexAttribArray(2)

	// Check for errors
	error := gl.GetError()
	if error != gl.NO_ERROR {
		fmt.println("OpenGL error in VAO setup:", error)
	} else {
		fmt.println("Test VAO created successfully")
	}

	// Unbind VAO but not EBO (it stays bound to the VAO)
	gl.BindVertexArray(0)

	return vao
}

render_curve :: proc(vao: u32, shader_program: u32, projection, view, model: glsl.mat4) {
	// fmt.println("Rendering curve...")

	// Bind shader program
	gl.UseProgram(shader_program)

	// Check if program is valid
	if shader_program == 0 {
		fmt.println("ERROR: Shader program is invalid!")
		return
	}

	// Set matrices
	proj_loc := gl.GetUniformLocation(shader_program, "projection")
	view_loc := gl.GetUniformLocation(shader_program, "view")
	model_loc := gl.GetUniformLocation(shader_program, "model")

	if proj_loc < 0 || view_loc < 0 || model_loc < 0 {
		fmt.println("ERROR: Matrix uniform locations not found!")
	}

	projection := projection
	view := view
	model := model

	gl.UniformMatrix4fv(proj_loc, 1, gl.FALSE, &projection[0, 0])
	gl.UniformMatrix4fv(view_loc, 1, gl.FALSE, &view[0, 0])
	gl.UniformMatrix4fv(model_loc, 1, gl.FALSE, &model[0, 0])

	// Bind texture buffer objects
	glyphs_loc := gl.GetUniformLocation(shader_program, "glyphs")
	curves_loc := gl.GetUniformLocation(shader_program, "curves")

	if glyphs_loc < 0 || curves_loc < 0 {
		fmt.println("ERROR: Buffer uniform locations not found!")
		fmt.println("glyphs_loc:", glyphs_loc)
		fmt.println("curves_loc:", curves_loc)
	}

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_BUFFER, glyphs_tbo)
	gl.Uniform1i(glyphs_loc, 0)

	gl.ActiveTexture(gl.TEXTURE1)
	gl.BindTexture(gl.TEXTURE_BUFFER, curves_tbo)
	gl.Uniform1i(curves_loc, 1)

	// Set other uniform values
	color_loc := gl.GetUniformLocation(shader_program, "color")
	aa_loc := gl.GetUniformLocation(shader_program, "antiAliasingWindowSize")
	ssaa_loc := gl.GetUniformLocation(shader_program, "enableSuperSamplingAntiAliasing")
	viz_loc := gl.GetUniformLocation(shader_program, "enableControlPointsVisualization")

	gl.Uniform4f(color_loc, 1.0, 1.0, 1.0, 1.0)
	gl.Uniform1f(aa_loc, f32(anti_aliasing_window_size))
	gl.Uniform1i(ssaa_loc, i32(enable_supersampling_anti_aliasing))
	gl.Uniform1i(viz_loc, i32(enable_control_points_visualization))

	// Draw the curve
	gl.BindVertexArray(vao)

	// Check for errors before drawing
	error := gl.GetError()
	if error != gl.NO_ERROR {
		fmt.println("OpenGL error before drawing:", error)
	}

	gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, nil)

	// Check for errors after drawing
	error = gl.GetError()
	if error != gl.NO_ERROR {
		fmt.println("OpenGL error after drawing:", error)
	}

	gl.BindVertexArray(0)
	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_BUFFER, 0)
	gl.UseProgram(0)

	// fmt.println("Curve rendering complete")
}
