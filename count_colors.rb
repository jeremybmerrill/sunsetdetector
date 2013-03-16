#eventually, implement some sort of supervised ML.

require 'RMagick'
include Magick

def distance(a, b)
  x = (a[0] - b[0]).abs ** 2
  y = (a[1] - b[1]).abs ** 2
  z = (a[2] - b[2]).abs ** 2
  Math.sqrt(x + y + z)
end

def is_sunsety(rgb)
  #sunsety if within 200 units of (255, 55, 0) or (255, 0, 0)
  threshold = 120
  orangish_red = [255, 200, 0]
  reddish_red = [255, 0, 0]
  return distance(rgb, orangish_red) < threshold || distance(rgb, reddish_red) < threshold
end

def highlight_sunsety_colors(image_filename)
  magick_image = Image::read(image_filename).first
  new_image = magick_image.dup
  magick_image.each_pixel do |pxl, c, r|
    rgb = [pxl.red, pxl.green, pxl.blue].map{|n| n / 257}
    if is_sunsety(rgb)
      new_pxl = Pixel.new(QuantumRange,QuantumRange,QuantumRange,0)
    else
      new_pxl = Pixel.new(0,0,0,0)
    end
    new_image = new_image.store_pixels(c, r, 1, 1, [new_pxl])
  end
  new_image.display
end

Dir.glob("*.jpg").each do |photo_filename|
  #highlight_sunsety_colors(photo_filename)
  histogram = `convert  #{photo_filename}  -format %c  -depth 8  histogram:info:-`
  histogram_lines = histogram.split("\n")
          #        11: ( 98, 72, 83) #624853 srgb(98,72,83)
  puts "#{histogram_lines.count} distinct colors in #{photo_filename}"
  rgbs = histogram_lines.map do |hist_item|
    #3: (255,255,235) #FFFFEB srgb(255,255,235)
    count = hist_item[0...hist_item.index(":")].strip.to_i
    color_str = hist_item[hist_item.index(":") + 1..hist_item.index(") ")].strip
    colors = eval(color_str.gsub("(", "[").gsub(")", "]"))
    [colors, count]
  end
  puts photo_filename + ": " + rgbs.group_by {|color, count| is_sunsety(color) }.map{|bool, list| [bool, list.inject(0){|memo, color_count| memo + color_count[1]}]}.inspect
end