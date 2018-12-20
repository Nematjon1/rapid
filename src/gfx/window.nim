from unicode import toUtf8

import ../lib/glad/gl
import glfw

import ../data/data
import gfx

type
  RWindow* = object
    glwindow: Window
    gfx: RGfx
    events: RWindowEvents
    gldebug: bool
    fps, dt: float64
  RWindowEvents = object
    onChar: proc (character: string)
    onKeyDown: proc (key: Key, scancode: int32)
    onKeyUp: proc (key: Key, scancode: int32)
    onKeyRepeat: proc (key: Key, scancode: int32)
    onMousePress: proc (button: MouseButton)
    onMouseRelease: proc (button: MouseButton)
    onMouseMove: proc (x, y: float)
    onMouseEnter: proc ()
    onMouseLeave: proc ()
    onMouseWheel: proc (x, y: float)
    onResize: proc (width, height: int)
    onClose: proc (): bool
  RWindowBuilder = object
    config: OpenglWindowConfig

###
# RWindow
###

proc newRWindow*(): RWindowBuilder =
  glfw.initialize()

  var config = DefaultOpenglWindowConfig
  config.title = "rapid"
  config.size = (800, 600)
  config.bits = (r: 8, g: 8, b: 8, a: 8, stencil: 8, depth: 16)
  config.version = glv33

  result = RWindowBuilder(config: config)

proc size*(win: RWindowBuilder, width, height: int): RWindowBuilder =
  var win = win
  win.config.size = (width, height)
  win

proc title*(win: RWindowBuilder, title: string): RWindowBuilder =
  var win = win
  win.config.title = title
  win

proc resizable*(win: RWindowBuilder, resizable: bool): RWindowBuilder =
  var win = win
  win.config.resizable = resizable
  win

proc decorated*(win: RWindowBuilder, decorated: bool): RWindowBuilder =
  var win = win
  win.config.decorated = decorated
  win

proc focused*(win: RWindowBuilder, focused: bool): RWindowBuilder =
  var win = win
  win.config.focused = focused
  win

proc maximized*(win: RWindowBuilder, maximized: bool): RWindowBuilder =
  var win = win
  win.config.maximized = maximized
  win

proc open*(builder: RWindowBuilder): RWindow =
  var win = newWindow(builder.config)

  var rwin = RWindow(
    glwindow: win,
    gfx: newRGfx(builder.config.size.w.int, builder.config.size.h.int),
    events: RWindowEvents(
      onChar: proc (character: string) = discard,
      onKeyDown: proc (key: Key, scancode: int32) = discard,
      onKeyUp: proc (key: Key, scancode: int32) = discard,
      onKeyRepeat: proc (key: Key, scancode: int32) = discard,
      onMousePress: proc (button: MouseButton) = discard,
      onMouseRelease: proc (button: MouseButton) = discard,
      onMouseMove: proc (x, y: float) = discard,
      onMouseLeave: proc () = discard,
      onMouseEnter: proc () = discard,
      onMouseWheel: proc (x, y: float) = discard,
      onResize: proc (width, height: int) = discard,
      onClose: proc (): bool = return true
    )
  )

  if not gladLoadGL(getProcAddress):
    quit "rd fatal: couldn't create gl context"

  rwin.gfx.start()

  return rwin

proc debug*(self: var RWindow, state: bool) =
  self.gldebug = state

proc debugCallback(
    source: GLenum, etype: GLenum,
    id: GLuint, severity: GLenum,
    length: GLsizei, message: ptr GLchar,
    userParam: pointer) {.stdcall.} =
  echo "rd/gl debug | type: " & $etype & "; severity: " & $severity & "; message: " & $message

proc registerCallbacks(self: RWindow) =
  var win = self.glwindow
  self.glwindow.charCb = proc (w: Window, codePoint: Rune) = self.events.onChar(codePoint.toUTF8())
  win.keyCb = proc (w: Window, key: Key, scancode: int32, action: KeyAction, mods: set[ModifierKey]) =
    case action
    of kaDown: self.events.onKeyDown(key, scancode)
    of kaRepeat: self.events.onKeyRepeat(key, scancode)
    of kaUp: self.events.onKeyUp(key, scancode)
  self.glwindow.mouseButtonCb = proc (w: Window, button: MouseButton, pressed: bool, modKeys: set[ModifierKey]) =
    if pressed: self.events.onMousePress(button)
    else: self.events.onMouseRelease(button)
  self.glwindow.cursorPositionCb = proc (w: Window, pos: tuple[x, y: float64]) = self.events.onMouseMove(pos.x, pos.y)
  self.glwindow.cursorEnterCb = proc (w: Window, entered: bool) =
    if entered: self.events.onMouseEnter()
    else: self.events.onMouseLeave()
  self.glwindow.scrollCb = proc (w: Window, off: tuple[x, y: float64]) = self.events.onMouseWheel(off.x, off.y)
  self.glwindow.windowCloseCb = proc (w: Window) =
    let close = self.events.onClose()
    win.shouldClose = close
  self.glwindow.windowSizeCb = proc (w: Window, size: tuple[w, h: int32]) =
    var wg = self.gfx
    wg.resize(size.w, size.h)
    self.events.onResize(size.w, size.h)

  if self.gldebug:
    glEnable(GL_DEBUG_OUTPUT)
    glDebugMessageCallback(debugCallback, cast[pointer](0))

proc load*(self: var RWindow, data: RData) =
  self.gfx.load(data)

proc render*(self: var RWindow, f: proc (ctx: var RGfxContext)) =
  self.gfx.render do (ctx: var RGfxContext):
    f(ctx)

proc loop*(self: var RWindow, loopf: proc (ctx: var RGfxContext)) =
  var win = self.glwindow
  registerCallbacks(self)

  var gfx = self.gfx

  glfw.swapInterval(1)

  var ptime: float64
  while not win.shouldClose:
    self.dt = getTime() - ptime

    win.swapBuffers()
    glfw.pollEvents()

    gfx.render do (ctx: var RGfxContext):
      loopf(ctx)

    ptime = getTime()
    self.fps = 1 / self.dt

  glfw.terminate()
