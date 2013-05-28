# encoding: utf-8

#eventually, implement some sort of supervised ML.

require 'RMagick'
include Magick

module ColorCounter
  DEFAULT_COLOR_DISTANCE_THRESHOLD = 100

  def initialize; end

  def ColorCounter.distance(a, b)
    x = (a[0] - b[0]).abs ** 2
    y = (a[1] - b[1]).abs ** 2
    z = (a[2] - b[2]).abs ** 2
    Math.sqrt(x + y + z)
  end

  def ColorCounter.is_sunsety(rgb, color_distance_threshold=DEFAULT_COLOR_DISTANCE_THRESHOLD)
    #sunsety if within $color_distance_threshold units of (255, 55, 0) or (255, 0, 0)
    orangish_red = [255, 200, 0]
    reddish_red = [255, 0, 0]
    orangereddish_red = [255, 100, 0]
    return ColorCounter.distance(rgb, orangish_red) < color_distance_threshold || 
          ColorCounter.distance(rgb, reddish_red) < color_distance_threshold ||
          ColorCounter.distance(rgb, orangereddish_red) < color_distance_threshold
  end

  def ColorCounter.highlight_sunsety_colors(image_filename) #returns new filename
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
    #new_image.display
    new_filename = File.join(File.dirname(image_filename), "highlight_" + File.basename(image_filename))
    new_image.write( new_filename  )
    new_filename
  end

  # def ColorCounter.count_colors(photo_filename)
  #   #ColorCounter.highlight_sunsety_colors(photo_filename)
  #   histogram = `convert  #{photo_filename}  -format %c  -depth 8  histogram:info:-`
  #   histogram_lines = histogram.split("\n")
  #           #        11: ( 98, 72, 83) #624853 srgb(98,72,83)
  #   #puts "#{histogram_lines.count} distinct colors in #{photo_filename}"
  #   rgbs = histogram_lines.map do |hist_item|
  #     #3: (255,255,235) #FFFFEB srgb(255,255,235)
  #     count = hist_item[0...hist_item.index(":")].strip.to_i
  #     color_str = hist_item[hist_item.index(":") + 1..hist_item.index(") ")].strip
  #     colors = eval(color_str.gsub("(", "[").gsub(")", "]"))
  #     [colors, count]
  #   end
  #   results = rgbs.group_by {|color, count| ColorCounter.is_sunsety(color) }.map{|bool, list| [bool, list.inject(0){|memo, color_count| memo + color_count[1]}]}
  #   return Hash[*results.flatten]
  # end

  def ColorCounter.color_to_8bit(color)
    #e.g. #D6539DF089F4
    begin
      r = (color[1...5].to_s.to_i(16) / 255)
      g = (color[5...9].to_s.to_i(16) / 255)
      b = (color[9...13].to_s.to_i(16) / 255)
    rescue ArgumentError
      puts color
      raise ArgumentError
    end
    [r, g, b]
  end

  def ColorCounter.count_sunsetty_colors(image_filename, color_distance_threshold=DEFAULT_COLOR_DISTANCE_THRESHOLD)
    original_image = Image::read(image_filename).first
    image = original_image.quantize(32, RGBColorspace)
    original_image.destroy! #heh memleaks.
    image_size = image.columns * image.rows
    hist =  image.color_histogram.to_a
    hist.map!{|color, count| [ColorCounter.color_to_8bit(color.to_color), count.to_f /  image_size] }
    #puts hist.inspect
    sunsetty_colors = hist.group_by{|color, count| ColorCounter.is_sunsety(color, color_distance_threshold) }.map{|bool, list| [bool, list.inject(0){|memo, color_count| memo + color_count[1]}]}
    #puts image.color_histogram()
    image.destroy!
    return Hash[*sunsetty_colors.flatten]
  end
end