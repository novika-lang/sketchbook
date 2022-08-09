module Sketchbook
  # Multiple `Element`s with a common origin (local coordinate
  # system). Group can `adopt` and `reject` children dynamically.
  class Group
    include Element

    # Returns the children of this group. The more right an element
    # is, the greater its Z index is (it will appear on top of the
    # elements before it). The last element is considered frontmost.
    getter children = [] of Element

    # Adds *element* as a child of this group.
    #
    # WARNING: this method does not link up this and *element*'s
    # `intake`s. Do this yourself explicitly or via an override.
    def adopt(element : Element)
      children << element
      element.parent = self
      element.adopted
    end

    # Removes *element* from this group.
    def reject(element : Element)
      children.delete(element)
      element.parent = nil
      element.rejected
    end

    # Brings a child *element* in front of all others.
    #
    # Does nothing if *element* is not a child of this group.
    def bring_to_front(element : Element)
      children << (children.delete(element) || return)
    end

    # Returns the minimum required size of this group:
    # the position of the corner of its rightmost &
    # bottommost element.
    def req
      mx = children.max_of? { |child| (child.offset + child.req).x } || 0f64
      my = children.max_of? { |child| (child.offset + child.req).y } || 0f64
      Point.new(mx, my)
    end

    def render(target)
      @children.each &.render(target)
    end
  end
end
