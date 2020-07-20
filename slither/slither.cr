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


snake_textures = ["resources/texture1.png", "resources/texture2.jpg"].map do |fn|
  t = SF::Texture.from_file(fn)
  t.smooth = true
  t
end

grass_texture = SF::Texture.from_file("resources/grass.jpg")
grass_texture.repeated = true


struct SF::Vector2
  def length
    Math.sqrt(x*x + y*y)
  end
end

def orthogonal(a, b)
  ortho = SF.vector2(a.y - b.y, b.x - a.x)
  ortho / ortho.length
end


class Snake
  include SF::Drawable

  DENSITY = 0.5f32
  getter body
  property speed = 0.0f32
  property left = false
  property right = false
  @dt = 0.0f32
  @direction = 0.0f32

  def initialize(start, @texture : SF::Texture,
                 @size = 1200.0f32, @thickness = 70.0f32, @max_speed = 350.0f32,
                 @max_turn_rate = 4.5f32, @friction = 0.9f32, @turn_penalty = 0.7f32)
    @body = Deque(SF::Vector2(Float32)).new
    (0...(@size / DENSITY).to_i).each do |i|
      @body.push(start + {0, (i * DENSITY).to_f32})
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
    isplit = 0
    while ib < @body.size
      a, b = @body[ia], @body[ib]
      pos = (a + b) / 2

      head = @thickness*4
      if ia / DENSITY <= head
        th = @thickness * (ia/(head/2))**0.3
      else
        x = ib.fdiv(@body.size-1-draw_rate)
        th = @thickness * 0.008 * Math.sqrt(7198 + 39750*x - 46875*x*x)
      end
      ort = orthogonal(a, b) * th / 2

      ty = sz.y*isplit.abs/splits
      va << SF::Vertex.new(pos + ort, tex_coords: {0, ty})
      va << SF::Vertex.new(pos - ort, tex_coords: {sz.x, ty})

      if ib == draw_rate*6
        eyes = [pos + ort*0.75, pos - ort*0.75]
        eyes_angle = Math.atan2(ort.y, ort.x)
      end

      delta = Math.max(Math.min(draw_rate, @body.size-1 - ib), 1)
      ia += delta
      ib += delta

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
  SF::Style::Fullscreen, SF::ContextSettings.new(depth: 24, antialiasing: 8)
)
window.vertical_sync_enabled = true


snake1 = Snake.new(SF.vector2(window.size.x * 1 // 3, window.size.y // 2), snake_textures[0])
snake2 = Snake.new(SF.vector2(window.size.x * 2 // 3, window.size.y // 2), snake_textures[1])
snakes = [snake1, snake2]

background = SF::RectangleShape.new(window.size)
background.texture = grass_texture
background.texture_rect = SF.int_rect(0, 0, window.size.x, window.size.y)


clock = SF::Clock.new

while window.open?
  while event = window.poll_event()
    if event.is_a?(SF::Event::Closed) || (
      event.is_a?(SF::Event::KeyPressed) && event.code.escape?
    )
      window.close()
    end
  end

  snake1.left = SF::Keyboard.key_pressed?(SF::Keyboard::A)
  snake1.right = SF::Keyboard.key_pressed?(SF::Keyboard::D)
  snake2.left = SF::Keyboard.key_pressed?(SF::Keyboard::Left)
  snake2.right = SF::Keyboard.key_pressed?(SF::Keyboard::Right)

  dt = clock.restart.as_seconds
  snakes.each &.step(dt)

  window.draw background
  snakes.each do |s|
    window.draw s
  end

  window.display()
end
