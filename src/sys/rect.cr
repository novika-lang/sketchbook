module Sketchbook
  # Represents a *logical* rectangle with an *origin* and
  # *corner* points.
  record Rect, origin : Point, corner : Point do
    # Returns whether this rectangle includes *other* point.
    def includes?(point : Point)
      origin <= point <= corner
    end

    # Returns whether this rectangle includes *other* rectangle
    # (in its entirety).
    def includes?(other : Rect)
      includes?(other.origin) && includes?(other.corner)
    end

    # Returns whether this rectangle intersects with *other*
    # rectangle.
    def intersects?(other : Rect)
      # Copied from Smalltalk because I can't wrap my head
      # around this... ¯\_(ツ)_/¯
      r_origin = other.origin
      r_corner = other.corner

      return false if r_corner.x <= origin.x
      return false if r_corner.y <= origin.y
      return false if r_origin.x >= corner.x
      return false if r_origin.y >= corner.y

      true
    end
  end
end
