# Copyright (C) 2015 Oleh Prypin <blaxpirit@gmail.com>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


require "deque"
require "crsfml"

$snake_textures = ["resources/texture1.png", "resources/texture2.jpg"].map do |fn|
  t = SF::Texture.from_file(fn)
  t.smooth = true
  t
end

$grass_texture = SF::Texture.from_file("resources/grass.jpg")
$grass_texture.repeated = true


struct SF::Vector2
  def length
    Math.sqrt(x**2 + y**2)
  end
  
  def dot(other: self)
    x*other.x + y*other.y
  end
end

# https://en.wikipedia.org/wiki/Line-line_intersection#Given_two_points_on_each_line
def intersection(a1, a2, b1, b2)
  v1 = a1-a2
  v2 = b1-b2
  cos = (v1.dot v2)/(v1.length*v2.length)
  if cos.abs > 0.999
    return (a1+a2+b1+b2)/4
  end
  x1, y1 = a1; x2, y2 = a2
  x3, y3 = b1; x4, y4 = b2
  SF.vector2(
    ( (x1*y2-y1*x2)*(x3-x4)-(x1-x2)*(x3*y4-y3*x4) ) / ( (x1-x2)*(y3-y4)-(y1-y2)*(x3-x4) ),
    ( (x1*y2-y1*x2)*(y3-y4)-(y1-y2)*(x3*y4-y3*x4) ) / ( (x1-x2)*(y3-y4)-(y1-y2)*(x3-x4) )
  )
end

def orthogonal(a, b, d=1.0)
  ortho = SF.vector2(a.y-b.y, b.x-a.x)
  ortho *= d / ortho.length
end


class Snake
  DENSITY = 0.5
  getter body
  property speed
  property left
  property right
  @dt = 0.0
  @left = false
  @right = false
  @speed = 0
  @direction = 0.0
  
  def initialize(start, @texture, @size=1200.0, @thickness=70.0, @max_speed=350.0, @max_turn_rate=4.5, @friction=0.9, @turn_penalty=0.7)
    @body = Deque(SF::Vector2(Float64)).new
    (0...(@size / DENSITY).to_i).each do |i|
      @body.push(start + {0, i * DENSITY})
    end
  end
  
  def step(dt)
    if left ^ right
      @speed += @max_speed * dt
      @speed = Math.min(@speed, @max_speed)
    else
      @speed *= (1 - @friction) ** dt
    end
    
    turn_rate = @max_turn_rate * (@speed / @max_speed) ** (1 / (1 - @turn_penalty))
    @direction += turn_rate * dt if right
    @direction -= turn_rate * dt if left
    
    acc_dt = dt + @dt  # Add the extra time saved from the previous step
    dist = acc_dt * @speed
    steps = (dist / DENSITY).to_i
    used_dt = steps * DENSITY / @speed

    return unless steps > 0
    @dt = acc_dt - used_dt

    steps.times do
      head = @body[0] + {DENSITY * Math.sin(@direction), DENSITY * -Math.cos(@direction)}
      @body.unshift(head)
      @body.pop()
    end
  end
  
  def draw(target, states)
    va = [] of SF::Vertex
    
    states.texture = @texture
    sz = @texture.size
    
    k = 10
    splits = (k * sz.y / sz.x).to_i
    draw_rate = (@thickness / DENSITY / k).to_i
    ia = 0
    ib = ia + draw_rate
    ic = ib + draw_rate
    isplit = 0
    while ic < @body.size
      a, b, c = @body[ia], @body[ib], @body[ic]
      
      head = @thickness*4
      if ia / DENSITY <= head
        th = @thickness * (ia/(head/2))**0.3
      else
        x = ib.fdiv(@body.size-1-draw_rate)
        th = @thickness * 0.008 * Math.sqrt(7198 + 39750*x - 46875*x*x)
      end
      o1 = orthogonal(a, b, th / 2)
      o2 = orthogonal(b, c, th / 2)
      
      ty = sz.y*isplit.abs/splits
      va << SF.vertex(intersection(a+o1, b+o1, b+o2, c+o2), tex_coords: {0, ty})
      va << SF.vertex(intersection(a-o1, b-o1, b-o2, c-o2), tex_coords: {sz.x, ty})

      if ib == draw_rate*6
        eyes = [b+o1*0.75, b-o1*0.75]
        eyes_angle = Math.atan2(o1.y, o1.x)
      end
      
      delta = Math.max(Math.min(draw_rate, @body.size-1 - ic), 1)
      ia += delta
      ib += delta
      ic += delta
      
      isplit = (isplit + 1 + splits) % (splits + splits) - splits
    end
    
    va.reverse!
    target.draw va, SF::TrianglesStrip, states

    eye = SF::CircleShape.new(@thickness / 15)
    eye.origin = {eye.radius, eye.radius}
    eye.fill_color = SF.color(220, 220, 30)
    eye.rotate(eyes_angle.not_nil! * 180/Math::PI)
    pupil = eye.dup
    pupil.fill_color = SF::Color::Black
    eye.scale({0.9, 1})
    pupil.scale({0.3, 1})
    eyes.not_nil!.each do |p|
      eye.position = p
      pupil.position = p
      
      target.draw eye, states
      target.draw pupil, states
    end
  end
end


window = SF::RenderWindow.new(
  SF::VideoMode.desktop_mode, "Slither",
  SF::Fullscreen, SF.context_settings(depth: 24, antialiasing: 8)
)
window.vertical_sync_enabled = true


snake1 = Snake.new(window.size / 2 - {window.size.x / 6, 0}, $snake_textures[0])
snake2 = Snake.new(window.size / 2 + {window.size.x / 6, 0}, $snake_textures[1])
snakes = [snake1, snake2]

background = SF::RectangleShape.new()
background.texture = $grass_texture
background.size = window.size
background.texture_rect = SF.int_rect(0, 0, window.size.x, window.size.y)


clock = SF::Clock.new

while window.open?
  while event = window.poll_event()
    if event.type == SF::Event::Closed ||\
    (event.type == SF::Event::KeyPressed && event.key.code == SF::Keyboard::Escape)
      window.close()
    end
  end
  
  snake1.left = SF::Keyboard.is_key_pressed(SF::Keyboard::A)
  snake1.right = SF::Keyboard.is_key_pressed(SF::Keyboard::D)
  snake2.left = SF::Keyboard.is_key_pressed(SF::Keyboard::Left)
  snake2.right = SF::Keyboard.is_key_pressed(SF::Keyboard::Right)
  
  dt = clock.restart.as_seconds
  snakes.each &.step(dt)
  
  window.draw background
  snakes.each do |s|
    window.draw s
  end
  
  window.display()
end
