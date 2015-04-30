require "crsfml"


Parts = [
  {"---- -#--
    #### -#--
    ---- -#--
    ---- -#--",
    SF.color(255, 133, 27) # Orange
  }
  {"##
    ##",
    SF.color(242, 89, 75) # Red
  }
  {"--- -#- -#- -#-
    ### ##- ### -##
    -#- -#- --- -#-",
    SF.color(255, 220, 0) # Yellow
  }
  {"--- -#- #-- -##
    ### -#- ### -#-
    --# ##- --- -#-",
    SF.color(133, 20, 75) # Purple
  }
  {"--- ##- --# -#-
    ### -#- ### -#-
    #-- -#- --- -##",
    SF.color(0, 116, 217) # Blue
  }
  {"--- #--
    -## ##-
    ##- -#-",
    SF.color(127, 219, 255) # Cyan
  }
  {"--- --#
    ##- -##
    -## -#-",
    SF.color(46, 204, 64) # Green
  }
]


class Part
  def initialize(@field)
    parts, color = Parts[rand(Parts.length)]
    height = parts.lines.length
    count = parts.split.length / height
    @states = Array.new(count) { [] of Array(SF::Color?) }
    parts.split.each_with_index do |part, i|
      @states[i % count].push part.chars.map { |c| color if c == '#'}
    end
    
    @state = 0
    @x = (@field.width - width) / 2
    
    @y = -height
    @y += 1 while collides? == :invalid
  end
  
  getter x
  getter y
  
  def body
    @states[@state]
  end
  def width
    body[0].length
  end
  def height
    body.length
  end
  
  def each_with_pos
    body.each_with_index do |line, y|
      line.each_with_index do |b, x|
        next unless b
        yield b, @x + x, @y + y
      end
    end
  end
  
  def collides?
    each_with_pos do |b, x, y|
      return :invalid if x < 0 || x >= @field.width || y < 0
      return :collides if y >= @field.height || @field[x, y]
    end
    false
  end
  
  def [](x, y)
    body[y][x]
  end
  
  def left
    @x -= 1
    right if out = collides?
    out
  end
  def right
    @x += 1
    left if out = collides?
    out
  end

  def down
    @y += 1
    @y -= 1 if out = collides?
    out
  end
  def cw
    @state = (@state + 1) % @states.length
    ccw if out = collides?
    out
  end
  def ccw
    @state = (@state - 1) % @states.length
    cw if out = collides?
    out
  end
  
  def draw(target, states)
    rect = SF::RectangleShape.new(SF.vector2f(1, 1))
    each_with_pos do |b, x, y|
      rect.fill_color = b
      rect.position = SF.vector2f(x, y)
      target.draw(rect, states)
    end
  end
end

class Field
  def initialize(@width=10, @height=20)
    @clock = SF::Clock.new
    @body = Array.new(20) { Array(SF::Color?).new(10, nil) }
    @over = false
    @part = nil
    @interval = 1
    step
  end
  
  getter width
  getter height
  getter part
  property interval
  getter over
  
  def [](x, y)
    @body[y][x]
  end
  
  def each_with_pos
    @body.each_with_index do |line, y|
      line.each_with_index do |b, x|
        next unless b
        yield b, x, y
      end
    end
  end
  
  def step
    @clock.restart
    if !@part
      @part = Part.new(self)
      if @part.not_nil!.collides?
        @over = true
      end
    else
      if @part.not_nil!.down
        @part.not_nil!.each_with_pos do |b, x, y|
          @body[y][x] = b if b
        end
        @part = nil
        lines
        step
      end
    end
    true
  end
  
  def draw(target, states)
    rect = SF::RectangleShape.new(SF.vector2f(1, 1))
    each_with_pos do |b, x, y|
      rect.fill_color = b
      rect.position = SF.vector2f(x, y)
      target.draw(rect, states)
    end
    if @part
      @part.not_nil!.draw(target, states)
    end
  end
  
  def lines
    @body.reject! { |line| line.all? { |b| b } }
    while @body.length < height
      @body.insert(0, Array(SF::Color?).new 10, nil)
    end
  end
  
  def act
    step if @clock.elapsed_time.as_seconds >= @interval
  end
end


field = Field.new

scale = 20

window = SF::RenderWindow.new(
  SF.video_mode(field.width*scale, field.height*scale), "Tetrominos",
  settings: SF.context_settings(depth: 32, antialiasing: 8)
)
window.vertical_sync_enabled = true


transform = SF::Transform::Identity
transform.scale(scale, scale)

states = SF.render_states(transform: transform)


while window.open?
  while event = window.poll_event
    if event.type == SF::Event::Closed ||\
    (event.type == SF::Event::KeyPressed && event.key.code == SF::Keyboard::Escape)
      window.close
    elsif event.type == SF::Event::KeyPressed
      case event.key.code
        when SF::Keyboard::Left, SF::Keyboard::A
          field.part.try { |part| part.left }
        when SF::Keyboard::Right, SF::Keyboard::D
          field.part.try { |part| part.right }
        when SF::Keyboard::Q
          field.part.try { |part| part.ccw }
        when SF::Keyboard::Up, SF::Keyboard::W, SF::Keyboard::E
          field.part.try { |part| part.cw }
        when SF::Keyboard::Down, SF::Keyboard::S
          field.part.try { |part| field.step }
      end
    end
  end
  
  field.act
  
  window.close if field.over
  
  window.clear SF::Color::Black
  window.draw field, states
  
  window.display
end
