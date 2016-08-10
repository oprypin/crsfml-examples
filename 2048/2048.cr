require "crsfml"
require "./rounded_rectangle"


$font = SF::Font.from_file("resources/font/Ubuntu-M.ttf")

def hex_color(s)
  SF::Color.new(s[0..1].to_i(16), s[2..3].to_i(16), s[4..5].to_i(16))
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

struct SF::Rect
  def size
    SF.vector2(width, height)
  end
end


class Tile < SF::Transformable
  include SF::Drawable

  def initialize(@value : Int32, position)
    super()
    @rectangle = RoundedRectangleShape.new(SF.vector2(0.9, 0.9), 0.05)
    @rectangle.origin = {0.45, 0.45}
    self.position = position
    # The tile is initially small, will be enlarged
    self.scale = {0, 0}
  end
  @text_height : Float32?

  def value
    @value
  end
  def value=(value)
    @value = value
    # Bump tile size when it's merged
    self.scale = {1.15, 1.15}
    # Reset cached Text
    @text_height = nil
  end

  def draw(g, states)
    # Gradually return to normal scale
    if scale.y < 1
      sc = {scale.y + 0.2, 1}.min
      self.scale = {sc, sc}
    elsif scale.y > 1
      sc = {scale.y - 0.025, 1}.max
      self.scale = {sc, sc}
    end

    states.transform *= transform

    # Coordinates are scaled grid size/window size.
    # We can't use a font of height 1 pixel, because then it would be just a big blur
    # So we find out the real screen-coordinates height of the tile,
    # use that for the font size, then proportionally scale the Text down.
    h = states.transform.transform_rect(SF.float_rect(0, 0, 1, 1)).height
    if h != @text_height
      # Recreate the text object only when necessary (window was resized
      # or cache was otherwise reset: `@text_height = nil`)
      @text_height = h

      # Adjust for wide numbers
      size = 0.45
      l = value.to_s.size
      while l > 2
        size *= 0.8
        l -= 1
      end
      @text = text = SF::Text.new(value.to_s, $font, (size * h).to_i)
      # Center the text. Slightly more to the left because the font is weird.
      # And significantly more to the top because of baseline...
      text.origin = text.local_bounds.size * {0.53, 0.83}
      # Scaling down as mentioned
      text.scale({1.0/h, 1.0/h})

      text.color, @rectangle.fill_color = TILE_COLORS.fetch(value, TILE_COLORS[0])
    end

    g.draw @rectangle, states
    g.draw @text.not_nil!, states
  end
end

class Game2048
  include SF::Drawable

  def initialize(@size=4)
    @pts = 0

    @grid = {} of {Int32, Int32} => Tile
    # Position -> Tile
    # Note that a tile has 2 positions: its coordinates in the grid affect the logic, and
    # the .position is the current on-screen coordinates (it differs during animations)

    @extra = [] of Tile # Leftover tiles that are in the process of being merged onto

    @all_coords = [] of {Int32, Int32}
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
    pos = empties[rand(empties.size)]
    # 1/10 chance to spawn a 4
    @grid[pos] = Tile.new(rand(10) == 0 ? 4 : 2, pos)
    # Note how we use `pos` twice for grid-coordinates and animation-coordinates
  end

  def draw(window, states)
    m = {window.size.x, window.size.y}.min
    scale = m / (@size+0.1)

    window.clear BG_COLOR

    states.transform = states.transform
      # Position the field in the center of the window,
      # adding horizontal or vertical borders if the window is not square
      .translate((window.size - {m, m}) / 2.0)
      # Scale so every tile has size 1x1
      .scale({scale, scale})
      # Adjust by 0.5 because tiles have (0, 0) in their center
      # and by 0.05 for border
      .translate({0.55, 0.55})

    @all_coords.each do |p|
      @empty.position = p
      window.draw @empty, states
    end

    @grid.each do |p, tile|
      window.draw tile, states
    end
    # Leftover tiles are drawn on top, so tiles appear to slide under them on merge.
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
        case event
        when SF::Event::Closed
          return

        when SF::Event::Resized
          # Prevent stretching, to make custom adaptive stretching.
          window.view = SF::View.new(SF.float_rect(0, 0, event.width, event.height))

        when SF::Event::KeyPressed
          return if event.code == SF::Keyboard::Escape

          deltas = {
            SF::Keyboard::Right => {1, 0}, SF::Keyboard::D => {1, 0},
            SF::Keyboard::Left => {-1, 0}, SF::Keyboard::A => {-1, 0},
            SF::Keyboard::Up => {0, -1},   SF::Keyboard::W => {0, -1},
            SF::Keyboard::Down => {0, 1},  SF::Keyboard::S => {0, 1},
          }

          if deltas.has_key? event.code
            dx, dy = deltas[event.code]

            # The destinations of all tiles that are to be moved.
            # We don't need to store the source positions because that's the tile's screen-coordinates.
            to_move = {} of Tile => {Int32, Int32}

            # All tiles that have already participated in a merge, so they can't merge anymore.
            merged = Set(Tile).new

            # The following code chooses the order in which the tiles will be traversed.
            # Ex.: when the "right" direction is pressed, the order is the following:
            #   09 05 01 --
            #   10 06 02 --
            #   11 07 03 --
            #   12 08 04 --
            # (Rightmost tiles are not traversed)
            # To do this, we take a product of two ranges.
            # In the first part horizontal and vertical movement are equivalent
            # because they're a transpose away.
            if (dx == 1 || dy == 1) # moving right or down
              aa = (0...@size-1).to_a.reverse
            else
              aa = (1...@size).to_a
            end
            bb = (0..@size-1).to_a

            loop do  # Keep checking all tiles and trying to move them until no tiles have moved
              any_moved = false

              aa.product(bb) do |a, b|
                # The mentioned transpose
                x, y = (dx != 0 ? {a, b} : {b, a})

                # Can we move this tile?
                move = false

                this = @grid[{x, y}]?
                next unless this

                # The tile we will be trying to move onto
                nxt = @grid[{x+dx, y+dy}]?
                if nxt
                  # We can merge only equal value tiles that haven't been merged this turn
                  if this.value == nxt.value && (!merged.includes? this) && (!merged.includes? nxt)
                    move = true
                    # The neighbor will be overwritten in the grid,
                    # but we want to keep drawing it until the animation ends
                    @extra << nxt
                    merged << this
                  end
                else # free slot
                  move = true
                end
                if move
                  # Mark the tile to be moved to the neighboring slot.
                  # Grid-coordinates will be updated accordingly, but screen-coordinates
                  # still keep the original location.
                  to_move[this] = {x+dx, y+dy}

                  # Move from here to the neighboring slot.
                  # possibly overwriting a tile (which was saved to @extra previously).
                  @grid.delete({x, y})
                  @grid[{x+dx, y+dy}] = this

                  # We move the tile on grid in each iteration, but even though it may have
                  # been moved multiple times, its screen-coordinates still contain the
                  # original location. Long movements' animation has the same duration
                  # as 1-tile movements.

                  # All tiles will be traversed again
                  any_moved = true
                end
              end

              break unless any_moved
            end

            unless to_move.empty?
              n = @size+1 # animation happens in n frames
              start_positions = to_move.keys.map { |tile| {tile, tile.position} } .to_h
              (1..n).each do |i|
                to_move.each do |tile, destination|
                  # Linear interpolation between two points
                  tile.position = start_positions[tile]*(1 - i.fdiv n) + SF.vector2(*destination)*(i.fdiv n)
                end
                # We actually interrupt the normal flow of the event loop,
                # drawing frames and waiting for sync, for simplicity.
                frame(window)
              end
            end

            # Forget merged tiles
            @extra.clear

            merged.each do |tile|
              tile.value *= 2
              @pts += tile.value
            end

            # `to_move.empty` means nothing moved, so an invalid move
            spawn_tile unless to_move.empty?

            if is_game_over
              window.draw self

              rect = SF::RectangleShape.new(window.size)
              rect.fill_color = SF.color(255, 255, 255, 100)
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
    # Game is not over if there are empty slots
    return false if @grid.size < @size*@size
    # Game is not over if there are neighbors with equal values
    @grid.each do |p, tile|
      x, y = p
      return false if x+1 < @size && tile.value == @grid[{x+1, y}].value
      return false if y+1 < @size && tile.value == @grid[{x, y+1}].value
    end
    true
  end
end

window = SF::RenderWindow.new(
  SF::VideoMode.new(1000, 1000), "2048",
  settings: SF::ContextSettings.new(depth: 24, antialiasing: 8)
)
window.framerate_limit = 60

Game2048.new.run(window)

window.close()
