require "crsfml"
require "./rounded_rectangle"


$font = SF::Font.from_file("resources/font/Ubuntu-M.ttf")

def hex_color(s)
  SF.color(s[0..1].to_i(16), s[2..3].to_i(16), s[4..5].to_i(16))
end

BG_COLOR = hex_color("bbada0")
EMPTY_COLOR = hex_color("ccc0b3")
TILE_COLORS = "
   2 776e65 eee4da
   4 776e65 ede0c8
   8 f9f6f2 f2b179
  16 f9f6f2 f59563
  32 f9f6f2 f67c5f
  64 f9f6f2 f65e3b
 128 f9f6f2 edcf72
 256 f9f6f2 edcc61
 512 f9f6f2 edc850
1024 f9f6f2 edc53f
2048 f9f6f2 edc22e
   0 f9f6f2 3c3a32
".strip.lines
  .map(&.split)
  .map { |l| {l[0].to_i, {hex_color(l[1]), hex_color(l[2])}} }
  .to_h

struct SF::FloatRect
  def size
    SF.vector2(width, height)
  end
end


class Tile
  include SF::TransformableM
  
  def initialize(@value, position)
    @rectangle = RoundedRectangleShape.new(SF.vector2(0.9, 0.9), 0.05)
    @rectangle.origin = {0.45, 0.45}
    self.position = position
    self.scale = {0.1, 0.1}
  end
  
  def value
    @value
  end
  def value=(value)
    @value = value
    self.scale = {1.15, 1.15}
    @text_height = nil
  end
  property joined
  
  def draw(g, states)
    if scale.y < 1
      sc = {scale.y + 0.2, 1}.min
      self.scale = {sc, sc}
    elsif scale.y > 1
      sc = {scale.y - 0.02, 1}.max
      self.scale = {sc, sc}
    end
    
    states.transform *= transform
    
    h = states.transform.transform_rect(SF.float_rect(0, 0, 1, 1)).height
    if h != @text_height
      # Recreate the objects only when necessary
      @text_height = h
      
      size = 0.45
      l = value.to_s.length
      while l > 2
        size *= 0.8
        l -= 1
      end
      @text = text = SF::Text.new(value.to_s, $font, (size * h).to_i)
      text.origin = text.local_bounds.size * {0.55, 0.83}
      text.scale({1.0/h, 1.0/h})
    
      begin
        info = TILE_COLORS[value]
      rescue
        info = TILE_COLORS[0]
      end
      text.color, @rectangle.fill_color = info
    end
    
    g.draw @rectangle, states
    g.draw @text.not_nil!, states
  end
end

class Game2048
  def initialize(@size=4)
    @pts = 0
    
    @grid = {} of {Int32, Int32} => Tile
    @extra = [] of Tile
    
    @all_coords = Set({Int32, Int32}).new
    (0...@size).each do |y|
      (0...@size).each do |x|
        @all_coords << {x, y}
      end
    end
    
    @empty = RoundedRectangleShape.new(SF.vector2(0.9, 0.9), 0.05)
    @empty.fill_color = EMPTY_COLOR
    @empty.origin = {0.45, 0.45}
    
    spawn_tile
    spawn_tile
  end
  
  def spawn_tile
    empties = @all_coords.reject { |p| @grid.has_key? p }
    pos = empties[rand(empties.length)]
    @grid[pos] = Tile.new(rand(10) == 0 ? 4 : 2, SF.vector2(pos))
  end
  
  def draw(window, states)
    m = {window.size.x, window.size.y}.min
    scale = m / (@size+0.1)
    
    window.clear BG_COLOR
    
    states.transform = states.transform
      .translate((window.size - {m, m}) / 2.0)
      .scale({scale, scale})
      .translate({0.55, 0.55})
    
    @all_coords.each do |p|
      @empty.position = SF.vector2(p)
      window.draw @empty, states
    end
    
    @grid.each do |p, tile|
      window.draw tile, states
    end
    @extra.each do |tile|
      window.draw tile, states
    end
  end
  
  def frame(window)
    window.clear
    window.draw self
    window.display
  end
  
  def run(window)
    loop do
      while event = window.poll_event
        case event.type
        when SF::Event::Closed
          return
        
        when SF::Event::Resized
          window.view = SF::View.from_rect(SF.float_rect(0, 0, event.width, event.height))
        
        when SF::Event::KeyPressed
          return if event.key.code == SF::Keyboard::Escape
          
          deltas = {
            SF::Keyboard::Right => {1, 0}, SF::Keyboard::D => {1, 0},
            SF::Keyboard::Left => {-1, 0}, SF::Keyboard::A => {-1, 0},
            SF::Keyboard::Up => {0, -1},   SF::Keyboard::W => {0, -1},
            SF::Keyboard::Down => {0, 1},  SF::Keyboard::S => {0, 1},
          }
          
          if deltas.has_key? event.code
            dx, dy = deltas[event.code]
            
            to_move = {} of Tile => { {Int32, Int32}, {Int32, Int32} }
            
            if (dx == 1 || dy == 1)
              aa = (0...@size-1).to_a.reverse
            else
              aa = (1...@size).to_a
            end
            bb = (0..@size-1).to_a
            
            loop do
              any_moved = false
              
              aa.product(bb) do |a, b|
                x, y = (dx != 0 ? {a, b} : {b, a})
                
                move = false
                
                this = @grid[{x, y}]?
                next unless this
                
                nxt = @grid[{x+dx, y+dy}]?
                if nxt
                  if this.value == nxt.value && !this.joined && !nxt.joined
                    move = true
                    @extra.push nxt
                    this.joined = true
                  end
                else
                  move = true
                end
                if move
                  if to_move.has_key? this
                    to_move[this] = {to_move[this][0], {x+dx, y+dy}}
                  else
                    to_move[this] = { {x, y}, {x+dx, y+dy} }
                  end
                  @grid.delete({x, y})
                  @grid[{x+dx, y+dy}] = this
                  
                  any_moved = true
                end
              end
              
              break unless any_moved
            end
            
            unless to_move.empty?
              n = @size+1 # animation duration
              (1..n).each do |i|
                to_move.each do |tile, ab|
                  a, b = ab
                  tile.position = SF.vector2(a)*(1 - i.fdiv n) + SF.vector2(b)*(i .fdiv n)
                end
                frame(window)
              end
            end
            
            @extra.clear
            
            @grid.each_value do |tile|
              if tile.joined
                tile.joined = false
                tile.value *= 2
                @pts += tile.value
              end
            end
            
            spawn_tile unless to_move.empty?
            
            if is_game_over
              window.draw self
              
              rect = SF::RectangleShape.new(window.size)
              rect.fill_color = SF.color(255, 255, 255, 64)
              window.draw rect
              
              text = SF::Text.new("Game over!", $font, 100)
              text.origin = text.local_bounds.size / 2
              text.position = window.size / 2 + {0, -75}
              text.color = SF::Color::Black
              window.draw text
              
              text = SF::Text.new("#{@pts} pts", $font, 100)
              text.origin = text.local_bounds.size / 2
              text.position = window.size / 2 + {0, 75}
              text.color = SF::Color::Black
              window.draw text
              
              window.display
              SF.sleep SF.seconds(3)
              return
            end
          end
        end
      end
      
      frame(window)
    end
  end
  
  def is_game_over
    return false if @grid.length < @size*@size
    @all_coords.each do |p|
      x, y = p
      begin
        return false if @grid[{x, y}].value == @grid[{x+1, y}].value
      rescue
      end
      begin
        return false if @grid[{x, y}].value == @grid[{x, y+1}].value
      rescue
      end
    end
    true
  end
end

window = SF::RenderWindow.new(
  SF.video_mode(1000, 1000), "2048",
  settings: SF.context_settings(32, antialiasing: 8)
)
window.framerate_limit = 60

Game2048.new.run(window)

window.close()
