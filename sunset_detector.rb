require './count_colors'
require 'fileutils'
require 'open3'
require 'twitter'

# TODO: 
# tweet pictures of sunsets; wait five minutes, if picture n is less sunsetty than picture n-1, tweet picture n-1
# eventually, rate all of the tweeted sunsets, use that as training data.


class SunsetDetector
  attr_accessor :how_often_to_take_a_picture, :sunsettiness_threshold, :interface

  def initialize(interface = "video0", &blk)
    authdetails = open("authdetails.txt", 'r').read.split("\n")
    Twitter.configure do |config|
      config.consumer_key = authdetails[0]
      config.consumer_secret = authdetails[1]
      config.oauth_token = authdetails[2]
      config.oauth_token_secret = authdetails[3]
    end

    self.how_often_to_take_a_picture = 0.25 #minutes
    self.sunsettiness_threshold = 0.1

    c = ColorCounter.new
    # Dir.glob("*.jpg").each do |pic_filename| 
    #   blk.call(self.detect_sunset(pic_filename), nil) #don't delete these.
    # end
    loop do
      pic_filename = self.take_a_picture(interface)
      blk.call(self.detect_sunset(pic_filename), pic_filename)
      sleep 60 * self.how_often_to_take_a_picture
    end
  end

  def detect_sunset(filename)
    c = ColorCounter.count_colors(filename)
    puts filename + ": " + c.inspect
    return (c[true].to_f / c[false]) > self.sunsettiness_threshold
  end

  def take_a_picture(interface="video0")
    cmd = "mplayer -vo jpeg -frames 1 -tv driver=v4l2:width=640:height=480:device=/dev/#{interface} tv://"
    #`#{cmd}` #TODO: suppress stderr crap.
    _i, _o, _e = Open3.popen3(cmd)
    _o.read
    _e.read
    _i.close
    _o.close
    _e.close
    time = Time.now.to_i.to_s
    FileUtils.move("00000001.jpg", "sunset_#{time}.jpg")
    "sunset_#{time}.jpg"
  end
end

def tweet(status, photo_filename)
  info = {}
  info["lat"] = 40.706996
  info["long"] = -74.013283
  Twitter.update_with_media(status, open(photo_filename, 'rb').read, info)
end

s = SunsetDetector.new do |bool, filename=nil| 
  if bool
    puts "that was a sunset"
    #delete day-old (or older) non-sunset pics.    
    old_sunsets = Dir.glob("not_a_sunset*")
    old_sunsets.filter{|filename| filename.gsub("not_a_sunset_", "").gsub(".jpg", "").to_i < (Time.now.to_i - 60*60*24)}.each{|f| FileUtils.rm(f) }
    tweet("here's tonight's sunset: ", )
  else
    puts "nope, no sunset"
    FileUtils.move(filename, "not_a_#{filename}") unless filename.nil?
  end
end
