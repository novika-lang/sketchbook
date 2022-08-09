module Sketchbook
  # Represents a 2D Cartesian point, with an *x* and *y*
  # floating point coordinates.
  record Point, x : Float64, y : Float64 do
    # Performs component-wise addition.
    def +(other : Point)
      Point.new(x + other.x, y + other.y)
    end

    # Performs component-wise subtraction.
    def -(other : Point)
      Point.new(x - other.x, y - other.y)
    end

    # Performs component-wise multiplication.
    def *(other : Point)
      Point.new(x * other.x, y * other.y)
    end

    # Performs component-wise multiplication by *factor*.
    def *(factor : Number)
      Point.new(x * factor, y * factor)
    end

    # Performs component-wise division by *factor*.
    def /(factor : Number)
      Point.new(x / factor, y / factor)
    end

    # Returns whether this point is above and to the left
    # of *other* point.
    def <=(other : Point)
      x <= other.x && y <= other.y
    end

    # Component-wise `Math.min` with *other*.
    def min(other : Point)
      Point.new(Math.min(x, other.x), Math.min(y, other.y))
    end

    # Component-wise `Math.max` with *other*.
    def max(other : Point)
      Point.new(Math.max(x, other.x), Math.max(y, other.y))
    end

    # Converts this point to `SF::Vector2i`.
    def vec2 : SF::Vector2i
      SF.vector2i(x.to_i, y.to_i)
    end
  end
end
