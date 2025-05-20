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

load_shader :: proc(vertex_path, fragment_path: string) -> (shader: Shader, success: bool) {
	shader.vertex_path = vertex_path
	shader.fragment_path = fragment_path

	// Add path verification
	fmt.println("Loading shaders from:")
	fmt.println("  Vertex:", vertex_path)
	fmt.println("  Fragment:", fragment_path)

	// Check if files exist first
	if !os.exists(vertex_path) {
		fmt.println("ERROR: Vertex shader file does not exist!")
		return shader, false
	}

	if !os.exists(fragment_path) {
		fmt.println("ERROR: Fragment shader file does not exist!")
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

	// Log first few bytes of each shader to confirm content
	fmt.println(
		"Vertex shader content (first 50 bytes):",
		string(vertex_code[:min(50, len(vertex_code))]),
	)
	fmt.println(
		"Fragment shader content (first 50 bytes):",
		string(fragment_code[:min(50, len(fragment_code))]),
	)

	// Compile shaders
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	vertex_str := cstring(raw_data(vertex_code))
	gl.ShaderSource(vertex_shader, 1, &vertex_str, nil)
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

	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	fragment_str := cstring(raw_data(fragment_code))
	gl.ShaderSource(fragment_shader, 1, &fragment_str, nil)
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

	// Verify program is valid
	if gl.IsProgram(program) {
		fmt.println("WARNING: gl.IsProgram reports the program is not valid!")
	}

	return shader, true
}
