require "crsfml"
require "./stream"

CODE_FONT = SF::Font.from_file("res/cozette.bdf")

record Point, x : Float64, y : Float64 do
  def +(other : Point)
    Point.new(x + other.x, y + other.y)
  end

  def -(other : Point)
    Point.new(x - other.x, y - other.y)
  end

  def *(num : Number)
    Point.new(x * num, y * num)
  end

  def /(num : Number)
    Point.new(x / num, y / num)
  end

  def <=(other : Point)
    x <= other.x && y <= other.y
  end

  def max(other : Point)
    Point.new(Math.max(x, other.x), Math.max(y, other.y))
  end

  def vec2 : SF::Vector2
    SF.vector2i(x.to_i, y.to_i)
  end
end

record Rect, origin : Point, corner : Point do
  def includes?(point : Point)
    origin <= point <= corner
  end

  def includes?(other : Rect)
    includes?(other.origin) && includes?(other.corner)
  end

  def intersects?(other : Rect)
    r_origin = other.origin
    r_corner = other.corner

    return false if r_corner.x <= origin.x
    return false if r_corner.y <= origin.y
    return false if r_origin.x >= corner.x
    return false if r_origin.y >= corner.y

    true
  end
end

# ---------------------------------------------------------

module Element
  # Central hub for events coming into this element.
  #
  # The window (one that sent the event and the event
  # itself are pumped.
  getter intake = Stream({SF::Window, SF::Event}).new

  # Pumps the event part of `intake`.
  getter events : Stream(SF::Event) do
    intake.map { |_, event| event }
  end

  # Pumps events from *stream* if they are in bounds
  # of this element (that is, if this element has mouse
  # over it).
  def inbound(stream : Stream({SF::Window, SF::Event}) = intake) : Stream(SF::Event)
    stream.when do |window, event|
      mouse = SF::Mouse.get_position(window)
      mouse_pt = Point.new(mouse.x, mouse.y)
      mouse_pt.in?(bounds)
    end.map { |_, event| event }
  end

  # Pumps booleans for whether the cursor entered or left
  # this element. This element must be in front of others.
  def transit(stream = events) : Stream(Bool)
    stream.when(SF::Event::MouseMoved)
      .map { |event| Point.new(event.x, event.y) }
      .map { |point| point.in?(bounds) }
      .uniq
  end

  # Pumps when cursor enters this element. Only `true`
  # is pumped.
  def enter(stream = events) : Stream(Bool)
    transit(stream).when(&.itself)
  end

  # Pumps when cursor leaves this element. Only `false`
  # is pumped.
  def leave(stream = events) : Stream(Bool)
    transit(stream).except(&.itself)
  end

  # Emits mouse position deltas when this element
  # is being dragged.
  getter drag : Stream(Point) do
    grip = nil

    events.all(
      # All between mouse PRESS on this frame...
      between: inbound
        .when(SF::Event::MouseButtonPressed)
        .when(&.button.left?)
        .map { |event| Point.new(event.x, event.y) }
        .each { |point| grip = point - pos },
      # ... and mouse RELEASE on this frame...
      and: inbound
        .when(SF::Event::MouseButtonReleased)
        .when(&.button.left?),
    )
      # ... for all mouse moved events ...
      .when(SF::Event::MouseMoved)
      .map do |event|
        # ... pump position deltas which take the grip (where
        # the user initially grabbed this form) into account:
        Point.new(event.x, event.y) - pos - grip.not_nil!
      end
  end

  # Pumps printable characters that the user types with
  # the keyboard from *stream*.
  def input(stream = inbound) : Stream(Char)
    stream.when(SF::Event::TextEntered)
      .map(&.unicode.chr)
      .when(&.printable?)
  end

  # Pumps mouse pressed events from *stream*.
  def mouse_press(stream = inbound) : Stream(SF::Event::MouseButtonPressed)
    stream.when(SF::Event::MouseButtonPressed)
  end

  # Pumps key events for keys that the user presses/releases
  # from *stream*.
  def keys(stream = inbound) : Stream(SF::Event::KeyEvent)
    stream.when(SF::Event::KeyEvent)
  end

  # Pumps key press events from *stream*.
  def keypress(stream = inbound) : Stream(SF::Event::KeyPressed)
    keys(stream).when(SF::Event::KeyPressed)
  end

  # Holds the size of this frame. Sizes smaller than
  # the `req`uired size will be ignored.
  setter size = Point.new(0, 0)

  # :ditto:
  def size
    @size.max(req)
  end

  # Holds the local position (offset from parent) of
  # this frame.
  property offset = Point.new(0, 0)

  # Returns the parent element of this element. May be nil
  # when this element is top-level.
  property! parent : Group?

  # Whether this element is below others in `parent`. Set
  # by `parent` automatically.
  property? tucked = false

  # Returns the global position of this element.
  #
  # NOTE: this method is recursive over parent and will fail
  # at (very) deep element trees.
  def pos(accum = offset)
    # Tail recursion is a desperate plea to the optimizer.
    parent? ? parent.pos(accum + parent.offset) : accum
  end

  # Returns the minimum required size for this element.
  abstract def req

  # Returns the *global* bounding rect of this element.
  def bounds : Rect
    Rect.new(pos, pos + size)
  end

  # Returns whether this element is topmost (frontmost)
  # on Z axis. Returns true if this element has no parent.
  def frontmost?
    !tucked?
  end

  # Brings this element to the top of Z axis of its parent.
  # Does nothing if this element has no parent.
  def bring_to_front
    parent.bring_to_front(self) if parent?
  end

  # Hook called when this element is added as a child
  # to an element capable of holding children.
  def adopted
  end

  # Renders this element on the screen.
  def render(target)
  end
end

class Group
  include Element

  # Returns the children of this frame.
  getter children = [] of Element

  def adopt(child : Element)
    children.last?.try &.tucked = true
    children << child
    child.parent = self
    intake.sub(child.intake)
    child.adopted
  end

  def req
    mx = children.max_of? { |child| (child.offset + child.req).x.as(Float64) } || 0f64
    my = children.max_of? { |child| (child.offset + child.req).y.as(Float64) } || 0f64
    Point.new(mx, my)
  end

  # Brings a child *element* to front (so that there is no
  # child "above" it).
  #
  # Does nothing if *element* is not a child of this group.
  def bring_to_front(element : Element)
    if children.delete(element)
      children.last?.try &.tucked = true
      element.tucked = false
      children << element
    end
  end

  def render(target)
    children.each &.render(target)
  end
end

class CodeEditor
  include Element

  getter code : String

  def initialize(@code : String)
    @label = SF::Text.new(@code, CODE_FONT, 13)
    @label.color = SF::Color.new(0x42, 0x42, 0x42)
  end

  def code=(@code)
    @label.string = code
  end

  def adopted
    parent
      .input(stream: parent.events)
      .all(between: parent.enter, and: parent.leave, now: true)
      .each { |char| self.code += char }

    parent
      .keypress(stream: parent.events)
      .all(between: parent.enter, and: parent.leave, now: true)
      .when(&.code.backspace?)
      .each { self.code = code.rchop }
  end

  def req
    Point.new(@label.local_bounds.width, @label.local_bounds.height)
  end

  def render(target)
    @label.position = pos.vec2
    target.draw(@label)
  end
end

class Frame < Group
  # Holds whether this frame has focus.
  property? focused = false

  # Returns the main shape of this frame.
  getter shape = SF::RectangleShape.new

  # Returns the shadow shape of this frame.
  getter shadow = SF::RectangleShape.new

  def initialize
    drag.when { focused? }.each { |delta| self.offset += delta }
  end

  def req
    super + padding * 2 + shadow_extra
  end

  def adopt(child)
    child.offset += padding
    super
  end

  # Returns the background color of this frame.
  def bg
    tucked? ? SF::Color.new(0xBD, 0xBD, 0xBD) : SF::Color.new(0xE0, 0xE0, 0xE0)
  end

  # Returns the content padding of this form.
  def padding
    Point.new(0, 0)
  end

  # Returns width of this frame's border.
  def border_width
    1
  end

  # Returns the color of this frame's border.
  def border_color
    SF::Color.new(0x90, 0xA4, 0xAE)
  end

  # Returns the color of this frame's shadow.
  def shadow_color
    SF::Color.new(0x90, 0xA4, 0xAE)
  end

  # Returns `Point` extra of this frame's shadow.
  def shadow_extra
    tucked? ? Point.new(0, 0) : Point.new(1, 2)
  end

  def render(target)
    pos_ = pos

    # Update SFML's shape object with our "custom" properties:
    shape.size = size.vec2
    shape.position = pos_.vec2
    shape.fill_color = bg
    shape.outline_color = border_color
    shape.outline_thickness = border_width

    # Update shadow with our "custom" properties:
    shadow.size = size.vec2
    shadow.position = (pos_ + shadow_extra).vec2
    shadow.fill_color = shadow_color

    # Draw them both to the target:
    target.draw(shadow)
    target.draw(shape)

    super
  end
end

class ReplFrame < Frame
  def initialize
    super
    @editor = CodeEditor.new("")
    adopt(@editor)
  end

  def border_color
    focused? ? SF::Color.new(0x21, 0x96, 0xF3) : super
  end

  def shadow_extra
    focused? ? Point.new(2, 3) : super
  end

  def padding : Point
    Point.new(6, 3)
  end
end

class World < Group
  def initialize
    intake
      .when { |_, event| event.is_a?(SF::Event::TextEntered) }
      .each do |(window, event)|
        mouse = SF::Mouse.get_position(window)
        mouse_at = Point.new(mouse.x, mouse.y)
        unless locked?
          frame = ReplFrame.new
          frame.offset = mouse_at - frame.size/2
          frame.focused = true
          adopt(frame)
          # Forward it to frame so it's not lost. That's the idea.
          frame.intake.pump({window, event})
        end
      end
  end

  def adopt(child : Frame)
    super
    child.enter(stream: events).each do
      next if locked?
      child.focused = true
      child.bring_to_front
    end
    child.leave(stream: events).each do
      child.focused = false
    end
  end

  def locked?
    children.any? { |child| child.is_a?(Frame) && child.focused? }
  end
end

# ---------------------------------------------------------

window = SF::RenderWindow.new(SF::VideoMode.new(1000, 1000), title: "Novika Sketchbook", settings: SF::ContextSettings.new(depth: 24, antialiasing: 8))
window.framerate_limit = 60

world = World.new

while window.open?
  while event = window.poll_event
    case event
    when SF::Event::Closed
      window.close
    when SF::Event::Resized
      window.view = SF::View.new(SF.float_rect(0, 0, event.width, event.height))
    end
    world.intake.pump({window, event})
  end

  window.clear(SF::Color::White)
  world.render(window)
  window.display
end
