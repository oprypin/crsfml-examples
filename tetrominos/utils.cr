require "crsfml"


# 3D-looking box
class BlockShape < SF::RectangleShape
  # Cache of darkened/lightened color sets
  @@colors = {} of SF::Color => Array(SF::Color)

  private def colors
    c = fill_color
    @@colors.fetch(c) do
      h, s, l = rgb_to_hsl(c.r / 255.0, c.g / 255.0, c.b / 255.0)
      @@colors[c] = [-0.23, -0.07, 0.0, 0.11, -0.14].map { |d|
        rgb = hsl_to_rgb(h, (s + d/2).clamp(0.0, 1.0), (l + d).clamp(0.0, 1.0))
        SF::Color.new(*rgb.map { |c| (c * 255).to_u8 }, c.a)
      }
    end
  end

  def draw(target, states)
    states.transform = (states.transform * transform).scale(size)

    back, out, ins = {0.0, 0.02, 0.18}.map { |k|
      [{k, k}, {1-k, k}, {1-k, 1-k}, {k, 1-k}]
    }
    ins.reverse!
    [
      back, out, ins, # background, sides, middle
      out[0..1] + ins[2..3], # top
      ins[0..1] + out[2..3], # bottom
    ].zip(colors) do |pts, color|
      target.draw(pts.map { |p| SF::Vertex.new(p, color) }, SF::TrianglesFan, states)
    end
  end
end



# http://axonflux.com/handy-rgb-to-hsl-and-rgb-to-hsv-color-model-c

# Converts an RGB color value to HSL. Conversion formula
# adapted from http://en.wikipedia.org/wiki/HSL_color_space.
# Values are 0.0 .. 1.0
def rgb_to_hsl(r : Float, g : Float, b : Float) : {Float64, Float64, Float64}
  max, min = {r, g, b}.max, {r, g, b}.min
  l = (max + min) / 2

  if max == min
    return {0.0, 0.0, l} # achromatic
  end

  d = max - min
  s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
  h = case max
    when r
      (g - b) / d + (g < b ? 6 : 0)
    when g
      (b - r) / d + 2
    else
      (r - g) / d + 4
  end
  h /= 6

  {h, s, l}
end

private def hue_to_rgb(p : Float, q : Float, t : Float) : Float64
  t %= 1
  if t < 1/6.0
    p + (q - p) * 6 * t
  elsif t < 3/6.0
    q
  elsif t < 4/6.0
    p + (q - p) * (2/3.0 - t) * 6
  else
    p
  end
end

# Converts an HSL color value to RGB. Conversion formula
# adapted from http://en.wikipedia.org/wiki/HSL_color_space.
# Values are 0.0 .. 1.0
def hsl_to_rgb(h : Float, s : Float, l : Float) : {Float64, Float64, Float64}
  if s == 0.0
    return {l, l, l} # achromatic
  end

  q = l < 0.5 ? l * (1 + s) : l + s - l * s
  p = 2 * l - q
  {hue_to_rgb(p, q, h + 1/3.0),
   hue_to_rgb(p, q, h),
   hue_to_rgb(p, q, h - 1/3.0)}
end
