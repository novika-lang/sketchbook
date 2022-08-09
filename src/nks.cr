require "crsfml"

require "./sys/*"
require "./tree/*"

include Sketchbook # TODO

CODE_FONT = SF::Font.from_file("res/cozette.bdf")

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

  def req
    super + Point.new(1, 2) * padding + Point.new(border_width, border_width) * 4
  end

  def adopt(child)
    child.offset += padding
    super
  end

  # Returns the background color of this frame.
  def bg
    !focused? ? SF::Color.new(0xBD, 0xBD, 0xBD) : SF::Color.new(0xE0, 0xE0, 0xE0)
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
    SF::Color.new(0x00, 0x00, 0x00, 0x30)
  end

  # Returns `Point` extra of this frame's shadow.
  def shadow_extra
    !focused? ? Point.new(0, 0) : Point.new(1, 2)
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

class REPLFrame < Frame
  def initialize
    @editor = CodeEditor.new("")
    intake.sub(@editor.intake)
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
  # Sinkhole is the frame which gets all world's events,
  # except those world handles itself (such as dragging
  # frames around and changing the sinkhole).
  #
  # Sinkhole is by definition in focus (see `Frame#focused?`).
  getter sinkhole : Frame?

  # :ditto:
  def sinkhole=(frame : Frame?)
    frame.try &.focused = true
    sinkhole.try &.focused = false
    @sinkhole = frame
  end

  def initialize
    # When the user types something, and no sinkhole frame
    # is active, create and adopt a REPL frame under the
    # mouse cursor.
    intake
      .when { sinkhole.nil? }
      .when { |_, event| event.is_a?(SF::Event::TextEntered) }
      .each do |(window, event)|
        mouse = SF::Mouse.get_position(window)
        mouse_at = Point.new(mouse.x, mouse.y)

        frame = REPLFrame.new
        frame.offset = mouse_at - frame.size/2
        self.sinkhole = frame

        adopt(frame)
      end

    # Pump events received by world into the sinkhole frame,
    # when one is available.
    intake.each do |window, event|
      (sinkhole || next).intake.pump({window, event})
    end
  end

  def adopt(frame : Frame)
    super

    # When the mouse enters a frame, unless there is another
    # sinkhole frame, it becomes the sinkhole frame.
    frame.enter(stream: events)
      .when { sinkhole.nil? }
      .each do
        frame.bring_to_front
        self.sinkhole = frame
      end

    frame.drag(stream: events)
      .when { !sinkhole.nil? && frame.same?(sinkhole) }
      .each { |delta| frame.offset += delta }

    frame.leave(stream: events)
      .when { !sinkhole.nil? && frame.same?(sinkhole) }
      .each do |point|
        # Do not wait for entry: check if mouse is over another
        # frame and focus immediately. This makes the experience
        # a bit more enjoyable.
        self.sinkhole = children.each do |other|
          next unless point.in?(other.bounds)
          next unless other.is_a?(Frame)
          other.focused = true
          self.sinkhole = other
        end
      end
  end
end

# ---------------------------------------------------------

ICON = {{read_file("./res/icon.bmp")}}

window = SF::RenderWindow.new(SF::VideoMode.new(1000, 1000), title: "Novika Sketchbook", settings: SF::ContextSettings.new(depth: 24, antialiasing: 8))
window.framerate_limit = 60

icon = SF::Image.from_memory(ICON.to_slice)
window.set_icon(64, 64, icon.pixels_ptr)

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
