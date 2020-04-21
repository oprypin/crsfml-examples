require "crsfml"
require "gl"

def gl_color(color : SF::Color)
  GL.color3d(color.r / 255.0, color.g / 255.0, color.b / 255.0)
end

class Cube
  getter front, back, left, right, top, bottom
  def initialize
    @front = SF.color(0xC41E3Affu32)
    @back = SF.color(0xFF5800ffu32)
    @left = SF.color(0xDDDDDDffu32)
    @right = SF.color(0xFFD500ffu32)
    @top = SF.color(0x0051BAffu32)
    @bottom = SF.color(0x009E60ffu32)
  end
  def move_right
    @front, @left, @back, @right = @left, @back, @right, @front
  end
  def move_left
    @front, @right, @back, @left = @right, @back, @left, @front
  end
  def move_up
    @front, @top, @back, @bottom = @top, @back, @bottom, @front
  end
  def move_down
    @front, @bottom, @back, @top = @bottom, @back, @top, @front
  end
end

def zero?(x)
  -0.001 < x && x < 0.001
end

window = SF::RenderWindow.new(
  SF::VideoMode.new(500, 500), "Cube",
  settings: SF::ContextSettings.new(depth: 24, antialiasing: 8)
)
window.framerate_limit = 60

x = y = 0.0
speed_x = speed_y = 0.0
cube = Cube.new

MAX_SPEED = 8.0
MIN_SPEED = 1.5
SIZE = 0.8

GL.enable GL::DEPTH_TEST

while window.open?
  while event = window.poll_event()
    case event
    when SF::Event::Resized
      GL.viewport(0, 0, event.width, event.height)
    when SF::Event::Closed
      window.close()
    else
    end
  end

  if SF::Keyboard.key_pressed? SF::Keyboard::Left
    speed_x = MAX_SPEED if zero?(speed_y) && speed_x >= 0
  elsif SF::Keyboard.key_pressed? SF::Keyboard::Right
    speed_x = -MAX_SPEED if zero?(speed_y) && speed_x <= 0
  elsif SF::Keyboard.key_pressed? SF::Keyboard::Up
    speed_y = MAX_SPEED if zero?(speed_x) && speed_y >= 0
  elsif SF::Keyboard.key_pressed? SF::Keyboard::Down
    speed_y = -MAX_SPEED if zero?(speed_x) && speed_y <= 0
  end

  if !zero?(speed_x)
    speed_x = Math.copysign(Math.max(speed_x.abs*0.95, MIN_SPEED), speed_x)
    x += speed_x
    if x >= 90
      x = speed_x = 0.0
      cube.move_right
    elsif x <= -90
      x = speed_x = 0.0
      cube.move_left
    end
  elsif !zero?(speed_y)
    speed_y = Math.copysign(Math.max(speed_y.abs*0.95, MIN_SPEED), speed_y)
    y += speed_y
    if y >= 90
      y = speed_y = 0.0
      cube.move_down
    elsif y <= -90
      y = speed_y = 0.0
      cube.move_up
    end
  end

  window.clear SF::Color::Black
  GL.clear(GL::COLOR_BUFFER_BIT | GL::DEPTH_BUFFER_BIT)
  GL.load_identity

  GL.rotated(20.0, -1.0, -1.0, -0.1)
  GL.rotated(y, 1.0, 0.0, 0.0)
  GL.rotated(x, 0.0, 1.0, 0.0)

  d = SIZE / 2
  GL.begin_ GL::QUADS
    gl_color(cube.front);  GL.vertex3d( d, -d,  d); GL.vertex3d( d,  d,  d); GL.vertex3d(-d,  d,  d); GL.vertex3d(-d, -d,  d);
    gl_color(cube.back);   GL.vertex3d( d, -d, -d); GL.vertex3d( d,  d, -d); GL.vertex3d(-d,  d, -d); GL.vertex3d(-d, -d, -d);
    gl_color(cube.left);   GL.vertex3d(-d, -d,  d); GL.vertex3d(-d,  d,  d); GL.vertex3d(-d,  d, -d); GL.vertex3d(-d, -d, -d);
    gl_color(cube.right);  GL.vertex3d( d, -d, -d); GL.vertex3d( d,  d, -d); GL.vertex3d( d,  d,  d); GL.vertex3d( d, -d,  d);
    gl_color(cube.top);    GL.vertex3d( d, -d, -d); GL.vertex3d( d, -d,  d); GL.vertex3d(-d, -d,  d); GL.vertex3d(-d, -d, -d);
    gl_color(cube.bottom); GL.vertex3d( d,  d,  d); GL.vertex3d( d,  d, -d); GL.vertex3d(-d,  d, -d); GL.vertex3d(-d,  d,  d);
  GL.end_

  window.display()
end

