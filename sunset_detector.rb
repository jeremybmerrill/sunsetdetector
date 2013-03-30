require './count_colors'
require 'fileutils'
require 'open3'
require 'twitter'

# TODO: 
# tweet pictures of sunsets; wait five minutes, if picture n is less sunsetty than picture n-1, tweet picture n-1
# eventually, rate all of the tweeted sunsets, use that as training data.

class SunsetDetector
  attr_accessor :how_often_to_take_a_picture, :interface, :previous_sunset

  def initialize(how_often_to_take_a_picture=5, interface = "video0")
    authdetails = open("authdetails.txt", 'r').read.split("\n")
    Twitter.configure do |config|
      config.consumer_key = authdetails[0]
      config.consumer_secret = authdetails[1]
      config.oauth_token = authdetails[2]
      config.oauth_token_secret = authdetails[3]
    end

    self.interface = interface
    self.how_often_to_take_a_picture = how_often_to_take_a_picture #minutes
    self.previous_sunset = nil
  end

  def perform
    #self.detect_sunset(Photograph.new("propublicasunsetfromlena.jpg", true)) #test
    loop do
      photo = self.take_a_picture(self.interface)
      self.detect_sunset(photo)
      sleep 60 * self.how_often_to_take_a_picture
    end
  end

  def delete_old_non_sunsets
      old_sunsets = Dir.glob("not_a_sunset*")
      old_sunsets.select{|filename| filename.gsub("not_a_sunset_", "").gsub(".jpg", "").to_i < (Time.now.to_i - 60*60*24)}.each{|f| FileUtils.rm(f) } unless old_sunsets.empty?
  end

  def detect_sunset(photo)
    #tweet only if this is a local maximum in sunsettiness.
    if self.previous_sunset && (!photo.is_a_sunset?  || self.previous_sunset > photo)
      self.previous_sunset.tweet(previous_sunset.test ? "here's a test sunset not from today" : "here's tonight's sunset: ")
      self.previous_sunset = nil
      self.delete_old_non_sunsets
    end
    if photo.is_a_sunset?
        puts "that was a sunset"
        self.previous_sunset = photo
    else
      puts "nope, no sunset"
      FileUtils.move(photo.filename, "not_a_#{photo.filename}")
    end
  end

  def take_a_picture(interface="video0")
    cmd = "mplayer -vo jpeg -frames 1 -tv driver=v4l2:width=640:height=480:device=/dev/#{interface} tv://"
    _i, _o, _e = Open3.popen3(cmd)
    _o.read
    _e.read
    _i.close
    _o.close
    _e.close
    time = Time.now.to_i.to_s
    FileUtils.move("00000001.jpg", "sunset_#{time}.jpg")
    Photograph.new("sunset_#{time}.jpg")
  end
end

class Photograph
  """Look at this photograph
  every time I do it makes me RT"""
  include Comparable
  attr_accessor :filename, :is_a_sunset, :test, :sunsettiness, :sunset_proportion_threshold

  def initialize(filename, test=false)
    self.filename = filename
    self.is_a_sunset = nil
    self.test = test
    self.sunsettiness = self.find_sunsettiness
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

  def is_a_sunset?(sunset_proportion_threshold=0.05)
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
  end

  def find_sunsettiness
    c = ColorCounter.count_sunsetty_colors(self.filename) #optionally, color_distance_threshold can be set here for distance from sunset color points.
    return c[true].to_f / c[false].to_f
  end

end


s = SunsetDetector.new(0.25)
s.perform
