package green_lightning

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

// Enable OpenGL debug output if available
enable_debug_output :: proc() {
	when ODIN_DEBUG {
		if gl.DebugMessageCallback != nil {
			gl.Enable(gl.DEBUG_OUTPUT)
			gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
			gl.DebugMessageCallback(debug_callback, nil)
			fmt.println("OpenGL debug output enabled")
		} else {
			fmt.println("OpenGL debug output not available")
		}
	}
}

debug_callback :: proc "c" (
	source: u32,
	type: u32,
	id: u32,
	severity: u32,
	length: i32,
	message: cstring,
	userParam: rawptr,
) {
	context = runtime.default_context()
	source_str := debug_source_string(source)
	type_str := debug_type_string(type)
	severity_str := debug_severity_string(severity)

	if severity == gl.DEBUG_SEVERITY_NOTIFICATION {
		fmt.printf("GL DEBUG: %s [%s] %s: %s\n", severity_str, source_str, type_str, message)
	} else {
		fmt.printf("GL DEBUG: %s [%s] %s: %s\n", severity_str, source_str, type_str, message)
	}
}

debug_source_string :: proc(source: u32) -> string {
	switch source {
	case gl.DEBUG_SOURCE_API:
		return "API"
	case gl.DEBUG_SOURCE_WINDOW_SYSTEM:
		return "Window System"
	case gl.DEBUG_SOURCE_SHADER_COMPILER:
		return "Shader Compiler"
	case gl.DEBUG_SOURCE_THIRD_PARTY:
		return "Third Party"
	case gl.DEBUG_SOURCE_APPLICATION:
		return "Application"
	case gl.DEBUG_SOURCE_OTHER:
		return "Other"
	case:
		return "Unknown"
	}
}

debug_type_string :: proc(type: u32) -> string {
	switch type {
	case gl.DEBUG_TYPE_ERROR:
		return "Error"
	case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR:
		return "Deprecated Behavior"
	case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR:
		return "Undefined Behavior"
	case gl.DEBUG_TYPE_PORTABILITY:
		return "Portability"
	case gl.DEBUG_TYPE_PERFORMANCE:
		return "Performance"
	case gl.DEBUG_TYPE_MARKER:
		return "Marker"
	case gl.DEBUG_TYPE_PUSH_GROUP:
		return "Push Group"
	case gl.DEBUG_TYPE_POP_GROUP:
		return "Pop Group"
	case gl.DEBUG_TYPE_OTHER:
		return "Other"
	case:
		return "Unknown"
	}
}

debug_severity_string :: proc(severity: u32) -> string {
	switch severity {
	case gl.DEBUG_SEVERITY_HIGH:
		return "HIGH"
	case gl.DEBUG_SEVERITY_MEDIUM:
		return "MEDIUM"
	case gl.DEBUG_SEVERITY_LOW:
		return "LOW"
	case gl.DEBUG_SEVERITY_NOTIFICATION:
		return "NOTIFICATION"
	case:
		return "Unknown"
	}
}
