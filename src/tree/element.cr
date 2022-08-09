module Sketchbook::Element
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

  # Whether this element is being dragged.
  @dragging = false

  # Pumps {point, in bounds} for whether the cursor entered
  # or left this element (at a specific point).
  #
  # Does not pump when dragging. See `drag` for the reason.
  def transit(stream = events) : Stream({Point, Bool})
    stream.when(SF::Event::MouseMoved)
      .except { @dragging }
      .map { |event| Point.new(event.x, event.y) }
      .map { |point| {point, point.in?(bounds)} }
      .uniq { |inside, _| inside }
  end

  # Pumps when cursor enters this element. Only `true`
  # is pumped.
  def enter(stream = events) : Stream(Point)
    transit(stream)
      .when { |_, inside| inside }
      .map { |point, _| point }
  end

  # Pumps when cursor leaves this element. Only `false`
  # is pumped.
  def leave(stream = events) : Stream(Point)
    transit(stream)
      .except { |_, inside| inside }
      .map { |point, _| point }
  end

  # Emits mouse position deltas when this element is
  # being dragged, as per the given event *stream*.
  #
  # NOTE: when this element is being dragged, `transit`
  # events (and therefore `enter` and `leave` events)
  # are all ignored (because you can drag faster than
  # the element moves, and so go in/out of its bounds,
  # leaving it but not finishing the drag).
  def drag(stream = events) : Stream(Point)
    grip = nil

    stream.all(
      # All between mouse PRESS on this frame...
      between: stream
        .when(SF::Event::MouseButtonPressed)
        .when(&.button.left?)
        .map { |event| Point.new(event.x, event.y) }
        .when(&.in?(bounds))
        .each { |point| grip = point - pos }
        .each { @dragging = true },
      # ... and mouse RELEASE on this frame...
      and: stream
        .when(SF::Event::MouseButtonReleased)
        .when(&.button.left?)
        .each { @dragging = false },
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

  # Brings this element to the top of Z axis of its parent.
  # Does nothing if this element has no parent.
  def bring_to_front
    parent.bring_to_front(self) if parent?
  end

  # Hook called when this element is added as a child to an
  # element capable of holding children.
  def adopted
  end

  # Hook called when this element is removed as a child
  # from an element capable of holding children.
  def rejected
  end

  # Renders this element on the screen.
  def render(target)
  end
end
