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

	vertex_code, v_success := os.read_entire_file(vertex_path)
	if !v_success {
		fmt.println("Failed to read vertex shader:", vertex_path)
		return shader, false
	}
	defer delete(vertex_code)

	fragment_code, f_success := os.read_entire_file(fragment_path)
	if !f_success {
		fmt.println("Failed to read fragment shader:", fragment_path)
		return shader, false
	}
	defer delete(fragment_code)

	// Compile shaders
	vertex_shader := gl.CreateShader(gl.VERTEX_SHADER)
	vertex_str := cstring(raw_data(vertex_code))
	gl.ShaderSource(vertex_shader, 1, &vertex_str, nil)
	gl.CompileShader(vertex_shader)

	fragment_shader := gl.CreateShader(gl.FRAGMENT_SHADER)
	fragment_str := cstring(raw_data(fragment_code))
	gl.ShaderSource(fragment_shader, 1, &fragment_str, nil)
	gl.CompileShader(fragment_shader)

	// Check compilation errors
	status, log_string: i32
	gl.GetShaderiv(vertex_shader, gl.COMPILE_STATUS, &status)
	if status == 0 {
		gl.GetShaderiv(vertex_shader, gl.INFO_LOG_LENGTH, &log_string)
		log := make([]u8, log_string)
		defer delete(log)
		gl.GetShaderInfoLog(vertex_shader, log_string, nil, raw_data(log))
		fmt.println("Vertex shader compilation error:", string(log))
		return shader, false
	}

	gl.GetShaderiv(fragment_shader, gl.COMPILE_STATUS, &status)
	if status == 0 {
		gl.GetShaderiv(fragment_shader, gl.INFO_LOG_LENGTH, &log_string)
		log := make([]u8, log_string)
		defer delete(log)
		gl.GetShaderInfoLog(fragment_shader, log_string, nil, raw_data(log))
		fmt.println("Fragment shader compilation error:", string(log))
		return shader, false
	}

	// Link shaders
	shader.program = gl.CreateProgram()
	gl.AttachShader(shader.program, vertex_shader)
	gl.AttachShader(shader.program, fragment_shader)
	gl.LinkProgram(shader.program)

	// Check linking errors
	gl.GetProgramiv(shader.program, gl.LINK_STATUS, &status)
	if status == 0 {
		gl.GetProgramiv(shader.program, gl.INFO_LOG_LENGTH, &log_string)
		log := make([]u8, log_string)
		defer delete(log)
		gl.GetProgramInfoLog(shader.program, log_string, nil, raw_data(log))
		fmt.println("Shader program linking error:", string(log))
		return shader, false
	}

	// Clean up
	gl.DeleteShader(vertex_shader)
	gl.DeleteShader(fragment_shader)

	return shader, true
}
