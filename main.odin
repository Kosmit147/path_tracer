package path_tracer

import "base:runtime"
import "core:log"
import "core:mem"
import "core:c"
import "vendor:glfw"
import gl "vendor:OpenGL"

g_context: runtime.Context

GL_VERSION_MAJOR :: 4
GL_VERSION_MINOR :: 6

glfw_error_callback :: proc "c" (error: c.int, description: cstring) {
  context = g_context
  log.errorf("GLFW error %v: %v", error, description)
}

glfw_key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: c.int) {
  if key == glfw.KEY_ESCAPE && action == glfw.PRESS {
    glfw.SetWindowShouldClose(window, true)
  }
}

main :: proc() {
  context.logger = log.create_console_logger(.Debug when ODIN_DEBUG else .Info)
  defer log.destroy_console_logger(context.logger)

  when ODIN_DEBUG {
    tracking_allocator: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    defer {
      if len(tracking_allocator.allocation_map) > 0 {
        log.warnf("MEMORY LEAK: %v allocations not freed:", len(tracking_allocator.allocation_map))
        for _, entry in tracking_allocator.allocation_map {
          log.warnf("- %v bytes at %v", entry.size, entry.location)
        }
      }
      mem.tracking_allocator_destroy(&tracking_allocator)
    }
  }

  g_context = context

  glfw.SetErrorCallback(glfw_error_callback)

  if !glfw.Init() do log.panicf("Failed to initialize GLFW.")
  defer glfw.Terminate()

  glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, GL_VERSION_MAJOR)
  glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, GL_VERSION_MINOR)
  glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
  glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, glfw.TRUE when ODIN_DEBUG else glfw.FALSE)

  window := glfw.CreateWindow(1920, 1080, "Path Tracer", monitor = nil, share = nil)
  if window == nil do log.panicf("Failed to create a window.")
  defer glfw.DestroyWindow(window)

  glfw.MakeContextCurrent(window)
  glfw.SwapInterval(1)

  gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, glfw.gl_set_proc_address)

  glfw.SetKeyCallback(window, glfw_key_callback)

  free_all(context.temp_allocator)

  for !glfw.WindowShouldClose(window) {
    glfw.PollEvents()
    glfw.SwapBuffers(window)
    free_all(context.temp_allocator)
  }
}
