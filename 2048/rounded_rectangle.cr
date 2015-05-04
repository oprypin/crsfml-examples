require "crsfml"


macro event_property(name, code)
  getter {{name}}
  def {{name.id}}=(value)
    @{{name.id}} = value
    {{code}}
  end
end

class RoundedRectangleShape < SF::ConvexShape
  def initialize(@size: SF::Vector2, @radius: Number, @corner_points=5: Int)
    super()
    update
  end
  
  event_property size, update
  event_property radius, update
  event_property corner_points, update
  
  def update
    self.point_count = corner_points*4
    
    centers = [
      {size.x - radius, radius}, {radius, radius},
      {radius, size.y - radius}, {size.x - radius, size.y - radius}
    ]
    
    (0...point_count).each do |index|
      center_index = index / corner_points
      angle = (index - center_index) * Math::PI / 2 / (corner_points - 1)
      center = centers[center_index]
      self[index] = {
        center[0] + radius*Math.cos(angle),
        center[1] - radius*Math.sin(angle)
      }
    end
  end
end
