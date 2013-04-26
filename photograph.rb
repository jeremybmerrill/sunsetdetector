require 'fileutils'

class Photograph
  #Look at this photograph
  #every time I do it makes me RT
  include Comparable
  attr_accessor :filename, :is_a_sunset, :test, :sunsettiness, :sunset_proportion_threshold

  def initialize(filename, test=false)
    self.filename = filename
    self.is_a_sunset = nil
    self.test = test
    self.sunsettiness = self.find_sunsettiness
  end

  def move(dest)
      FileUtils.move(self.filename, dest)
      self.filename = dest
  end

  def <=>(another_photo)
    if self.sunsettiness < another_photo.sunsettiness
      -1
    elsif self.sunsettiness > another_photo.sunsettiness
      1
    else
      0
    end
  end

  def is_a_sunset?(sunset_proportion_threshold=0.04)
    return self.is_a_sunset if (!self.is_a_sunset.nil? && sunset_proportion_threshold == self.sunset_proportion_threshold)
    self.is_a_sunset = self.sunsettiness > sunset_proportion_threshold
    puts "#{self.filename}: #{self.sunsettiness}"
    self.sunset_proportion_threshold = sunset_proportion_threshold
    return self.is_a_sunset
  end

  def tweet(status)
    info = {}
    info["lat"] = 40.706996
    info["long"] = -74.013283
    Twitter.update_with_media(status, open(self.filename, 'rb').read, info)
    puts "Tweeted: #{status} #{self.filename}"
  end

  def find_sunsettiness
    c = ColorCounter::count_sunsetty_colors(self.filename) #optionally, color_distance_threshold can be set here for distance from sunset color points.
    return c[true].to_f / c[false].to_f
  end

end