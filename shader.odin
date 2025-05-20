package green_lightning

import "core:fmt"
import "core:os"
import gl "vendor:OpenGL"

// Shader management
Shader :: struct {
	program:       u32,
	vertex_path:   string,
	fragment_path: string,
}

// Map of OpenGL uniform types to human-readable names
gl_type_to_string :: proc(type: u32) -> string {
	switch type {
	case gl.FLOAT:
		return "FLOAT"
	case gl.FLOAT_VEC2:
		return "FLOAT_VEC2"
	case gl.FLOAT_VEC3:
		return "FLOAT_VEC3"
	case gl.FLOAT_VEC4:
		return "FLOAT_VEC4"
	case gl.INT:
		return "INT"
	case gl.INT_VEC2:
		return "INT_VEC2"
	case gl.INT_VEC3:
		return "INT_VEC3"
	case gl.INT_VEC4:
		return "INT_VEC4"
	case gl.BOOL:
		return "BOOL"
	case gl.BOOL_VEC2:
		return "BOOL_VEC2"
	case gl.BOOL_VEC3:
		return "BOOL_VEC3"
	case gl.BOOL_VEC4:
		return "BOOL_VEC4"
	case gl.FLOAT_MAT2:
		return "FLOAT_MAT2"
	case gl.FLOAT_MAT3:
		return "FLOAT_MAT3"
	case gl.FLOAT_MAT4:
		return "FLOAT_MAT4"
	case gl.SAMPLER_2D:
		return "SAMPLER_2D"
	case gl.SAMPLER_CUBE:
		return "SAMPLER_CUBE"
	case 36304:
		return "SAMPLER_BUFFER_INT" // GL_INT_SAMPLER_BUFFER
	case 36290:
		return "SAMPLER_BUFFER" // GL_SAMPLER_BUFFER
	case:
		return fmt.tprintf("UNKNOWN_TYPE(0x%x)", type)
	}
}

// Load shaders more robustly
load_shader :: proc(vertex_path, fragment_path: string) -> (shader: Shader, success: bool) {
	shader.vertex_path = vertex_path
	shader.fragment_path = fragment_path

	fmt.println("Loading shaders from:")
	fmt.println("  Vertex:", vertex_path)
	fmt.println("  Fragment:", fragment_path)

	// Check if files exist
	if !os.exists(vertex_path) {
		fmt.println("ERROR: Vertex shader file does not exist:", vertex_path)
		return shader, false
	}

	if !os.exists(fragment_path) {
		fmt.println("ERROR: Fragment shader file does not exist:", fragment_path)
		return shader, false
	}

	vertex_code, v_success := os.read_entire_file(vertex_path)
	if !v_success {
		fmt.println("ERROR: Failed to read vertex shader:", vertex_path)
		return shader, false
	}
	defer delete(vertex_code)

	fragment_code, f_success := os.read_entire_file(fragment_path)
	if !f_success {
		fmt.println("ERROR: Failed to read fragment shader:", fragment_path)
		return shader, false
	}
	defer delete(fragment_code)

	// Compile vertex shader
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	vertex_str := cstring(raw_data(vertex_code))
	vertex_len := i32(len(vertex_code))
	gl.ShaderSource(vertex_shader, 1, &vertex_str, &vertex_len)
	gl.CompileShader(vertex_shader)

	// Check vertex shader compilation
	status: i32
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &status)
	if status == 0 {
		log_length: i32
		gl.GetShaderiv(vertex_shader, gl.INFO_LOG_LENGTH, &log_length)
		if log_length > 0 {
			log_data := make([]u8, log_length)
			defer delete(log_data)
			gl.GetShaderInfoLog(vertex_shader, log_length, nil, raw_data(log_data))
			fmt.println("ERROR: Vertex shader compilation failed:", string(log_data))
		} else {
			fmt.println("ERROR: Vertex shader compilation failed with no log")
		}
		gl.DeleteShader(vertex_shader)
		return shader, false
	}

	// Compile fragment shader
	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	fragment_str := cstring(raw_data(fragment_code))
	fragment_len := i32(len(fragment_code))
	gl.ShaderSource(fragment_shader, 1, &fragment_str, &fragment_len)
	gl.CompileShader(fragment_shader)

	// Check fragment shader compilation
	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &status)
	if status == 0 {
		log_length: i32
		gl.GetShaderiv(fragment_shader, gl.INFO_LOG_LENGTH, &log_length)
		if log_length > 0 {
			log_data := make([]u8, log_length)
			defer delete(log_data)
			gl.GetShaderInfoLog(fragment_shader, log_length, nil, raw_data(log_data))
			fmt.println("ERROR: Fragment shader compilation failed:", string(log_data))
		} else {
			fmt.println("ERROR: Fragment shader compilation failed with no log")
		}
		gl.DeleteShader(vertex_shader)
		gl.DeleteShader(fragment_shader)
		return shader, false
	}

	// Link shaders
	program := gl.CreateProgram()
	gl.AttachShader(program, vertex_shader)
	gl.AttachShader(program, fragment_shader)
	gl.LinkProgram(program)

	// Check program linking
	gl.GetProgramiv(program, gl.LINK_STATUS, &status)
	if status == 0 {
		log_length: i32
		gl.GetProgramiv(program, gl.INFO_LOG_LENGTH, &log_length)
		if log_length > 0 {
			log_data := make([]u8, log_length)
			defer delete(log_data)
			gl.GetProgramInfoLog(program, log_length, nil, raw_data(log_data))
			fmt.println("ERROR: Program linking failed:", string(log_data))
		} else {
			fmt.println("ERROR: Program linking failed with no log")
		}
		gl.DeleteShader(vertex_shader)
		gl.DeleteShader(fragment_shader)
		gl.DeleteProgram(program)
		return shader, false
	}

	// Clean up
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)

	shader.program = program
	fmt.println("Shader program created successfully, ID:", program)

	// Check if program is valid - using the correct check for Odin
	if gl.IsProgram(program) == gl.FALSE {
		fmt.println("ERROR: gl.IsProgram reports the program is not valid!")
	}

	// Print all active uniforms for debugging
	num_uniforms: i32
	gl.GetProgramiv(program, gl.ACTIVE_UNIFORMS, &num_uniforms)
	fmt.println("Active uniforms in program:", program, "(count:", num_uniforms, ")")

	for i: i32 = 0; i < num_uniforms; i += 1 {
		name_buf: [256]u8
		length, size: i32
		type: u32
		gl.GetActiveUniform(program, u32(i), 256, &length, &size, &type, &name_buf[0])
		name := string(name_buf[:length])

		// Get the actual location as well
		location := gl.GetUniformLocation(program, cstring(&name_buf[0]))

		fmt.printf(
			"  Uniform #%d: %s (type: %s, size: %d, location: %d)\n",
			i,
			name,
			gl_type_to_string(type),
			size,
			location,
		)
	}

	return shader, true
}

// Helper procedure to get uniform locations safely with error checking
get_uniform_location :: proc(program: u32, name: string) -> (i32, bool) {
	location := gl.GetUniformLocation(program, cstring(raw_data(name)))
	if location < 0 {
		fmt.println("WARNING: Could not find uniform location for:", name)
		return location, false
	}
	return location, true
}
