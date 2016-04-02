require "crsfml"
require "./utils"


Parts = [
  {"---- -#--
    #### -#--
    ---- -#--
    ---- -#--",
    SF.color(0x80BE1Fffu32) # Green
  },
  {"##
    ##",
    SF.color(0x1EA7E1ffu32) # Blue
  },
  {"--- -#- -#- -#-
    ### ##- ### -##
    -#- -#- --- -#-",
    SF.color(0xDDDDDDffu32) # Grey
  },
  {"--- -#- #-- -##
    ### -#- ### -#-
    --# ##- --- -#-",
    SF.color(0xC83E3Effu32) # Red
  },
  {"--- ##- --# -#-
    ### -#- ### -#-
    #-- -#- --- -##",
    SF.color(0xFF99CCffu32) # Pink
  },
  {"--- #--
    -## ##-
    ##- -#-",
    SF.color(0xE86A17ffu32) # Orange
  },
  {"--- --#
    ##- -##
    -## -#-",
    SF.color(0xFFCC00ffu32) # Yellow
  },
]


class Part
  def initialize(@field)
    parts, color = Parts[rand(Parts.size)]
    height = parts.lines.size
    count = parts.split.size / height
    @states = Array.new(count) { [] of Array(SF::Color?) }
    parts.split.each_with_index do |part, i|
      @states[i % count].push part.chars.map { |c| color if c == '#'}
    end
    
    @state = 0
    @x = (@field.width - width) / 2
    
    @y = -height
    while collides? == :invalid
      @y += 1
    end
  end
  
  getter x
  getter y
  
  def body
    @states[@state]
  end
  def width
    body[0].size
  end
  def height
    body.size
  end
  
  def each_with_pos
    body.each_with_index do |line, y|
      line.each_with_index do |b, x|
        next unless b
        yield b, SF.vector2(@x + x, @y + y)
      end
    end
  end
  
  def collides?
    each_with_pos do |b, p|
      return :invalid if p.x < 0 || p.x >= @field.width || p.y < 0
    end
    each_with_pos do |b, p|
      return :collides if p.y >= @field.height || @field[p]
    end
    false
  end
  
  def [](p)
    x, y = p
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
    @state = (@state + 1) % @states.size
    ccw if out = collides?
    out
  end
  def ccw
    @state = (@state - 1) % @states.size
    cw if out = collides?
    out
  end
  
  def draw(target, states)
    rect = BlockShape.new({1, 1})
    each_with_pos do |b, p|
      rect.fill_color = b
      rect.position = p
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
  
  def [](p)
    x, y = p
    @body[y][x]
  end
  
  def each_with_pos
    @body.each_with_index do |line, y|
      line.each_with_index do |b, x|
        next unless b
        yield b, SF.vector2(x, y)
      end
    end
  end
  
  def step
    @clock.restart
    if part = @part
      if part.down
        part.each_with_pos do |b, p|
          @body[p.y][p.x] = b if b
        end
        @part = nil
        lines
        step
      end
    else
      part = @part = Part.new(self)
      if part.collides?
        @over = true
      end
    end
    true
  end
  
  def draw(target, states)
    rect = BlockShape.new({1, 1})
    each_with_pos do |b, p|
      rect.fill_color = b
      rect.position = p
      target.draw(rect, states)
    end
    @part.try &.draw(target, states)
  end
  
  def lines
    @body.reject! { |line| line.all? { |b| b } }
    while @body.size < height
      @body.insert(0, Array(SF::Color?).new 10, nil)
    end
  end
  
  def act
    step if @clock.elapsed_time.as_seconds >= @interval
  end
end


field = Field.new

scale = 40

window = SF::RenderWindow.new(
  SF.video_mode(field.width*scale, field.height*scale), "Tetrominos",
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
          field.step
      end
    end
  end
  
  field.act
  
  window.close if field.over
  
  window.clear SF::Color::Black
  window.draw field, states
  
  window.display
end
