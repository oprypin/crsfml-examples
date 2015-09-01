require "crsfml"


$tiles_texture = SF::Texture.from_file("resources/tiles.png")
$digits_texture = SF::Texture.from_file("resources/digits.png")


class Minefield
  Flag = -1
  Mine = -2
  MineNotFound = -3
  MineError = -4
  
  def initialize(@width=8, @height=8, @mine_count=10)
    @mines = Set({Int32, Int32}).new
    @display = {} of {Int32, Int32} => Int32
    @new = true
    setup
  end
  getter width
  getter height
  getter mine_count

  def setup
    to_plant = @mine_count
    @mines = Set({Int32, Int32}).new
    while to_plant > 0
      mine = {rand(@width), rand(@height)}
      next if @mines.includes? mine
      @mines << mine
      to_plant -= 1
    end
  end
  
  def check(xy)
    x, y = xy
    return nil if @display.has_key? xy
    if @mines.includes? xy
      if @new
        setup
        return check(xy)
      end
      @display[xy] = Mine
      return false
    end
    neighboring_mines = 0
    (y-1 .. y+1).each do |j|
      (x-1 .. x+1).each do |i|
        neighboring_mines += 1 if @mines.includes?({i, j})
      end
    end
    if neighboring_mines > 0 && @new
      setup
      return check(xy)
    end
    @new = false
    @display[xy] = neighboring_mines
    if neighboring_mines == 0
      ({0, y-1}.max .. {y+1, @height-1}.min).each do |j|
        ({0, x-1}.max .. {x+1, @width-1}.min).each do |i|
          check({i, j})
        end
      end
    end
    marks = 0
    @display.each do |xy, val|
      if val < 0
        marks += 1
        return nil if marks > @mine_count
      end
    end
    true
  end
  
  def flag(xy)
    x, y = xy
    if !@display.has_key? xy
      @display[xy] = Flag
    elsif @display[xy] == Flag
      @display.delete xy
    else
      false
    end
  end
  
  def draw(target, states)
    tiles_array = SF::VertexArray.new(SF::Quads, @width*@height*4)
    digits_array = SF::VertexArray.new(SF::Quads)
    
    (0...@height).each do |y|
      (0...@width).each do |x|
        offset = y + x*width
        
        begin
          val = @display[{x, y}]
          tile_number = val >= 0 ? 0 : 1-val
        rescue
          tile_number = 1
        end
        
        [{0, 0}, {1, 0}, {1, 1}, {0, 1}].each_with_index do |d, di|
          dx, dy = d
          
          tiles_array[offset*4 + di] = SF.vertex(
            position: {x+dx, y+dy},
            tex_coords: {(tile_number+dx)*9, dy*9}
          )
          
          border = 2 /9.0
          if (val || 0) > 0
            digits_array.append SF.vertex(
              position: {x+border+dx*(1-border*2), y+border+dy*(1-border*2)},
              tex_coords: {(val+dx)*5, dy*5}
            )
          end
        end
      end
    end
    
    states.texture = $tiles_texture
    target.draw tiles_array, states
    states.texture = $digits_texture
    target.draw digits_array, states
  end
end


field = Minefield.new

scale = 100

window = SF::RenderWindow.new(
  SF.video_mode(field.width*scale, field.height*scale), "Minesweeper"
)
window.vertical_sync_enabled = true


transform = SF::Transform::Identity
transform.scale(scale, scale)

states = SF.render_states(transform: transform)



while window.open?
  while event = window.poll_event
    case event.type
    when SF::Event::Closed
      window.close
    when SF::Event::MouseButtonPressed
      coord = {(event.x / scale).to_i, (event.y / scale).to_i}
      field.check coord if event.button == SF::Mouse::Left
      field.flag coord if event.button == SF::Mouse::Right
    end
  end
  
  window.clear SF::Color::Black
  
  window.draw field, states
  
  window.display
end
