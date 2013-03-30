require './count_colors'
require 'fileutils'
require 'open3'
require 'twitter'

# TODO: 
# tweet pictures of sunsets; wait five minutes, if picture n is less sunsetty than picture n-1, tweet picture n-1
# eventually, rate all of the tweeted sunsets, use that as training data.

class SunsetDetector
  attr_accessor :how_often_to_take_a_picture, :sunsettiness_threshold, :interface

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
    self.sunsettiness_threshold = 0.05
  end

  def perform
    # Dir.glob("*.jpg").each do |pic_filename| 
    #   blk.call(self.detect_sunset(pic_filename), nil) #don't delete these.
    # end
    self.detect_sunset("propublicasunsetfromlena.jpg", true)
    loop do
      pic_filename = self.take_a_picture(self.interface)
      self.detect_sunset(pic_filename)
    end
  end

  def detect_sunset(pic_filename, test=false)
    if self.is_a_sunset?(pic_filename)
      puts "that was a sunset"
      #delete day-old (or older) non-sunset pics.    
      old_sunsets = Dir.glob("not_a_sunset*")
      old_sunsets.filter{|filename| filename.gsub("not_a_sunset_", "").gsub(".jpg", "").to_i < (Time.now.to_i - 60*60*24)}.each{|f| FileUtils.rm(f) } unless old_sunsets.empty?
      
      # previous_sunset_filename = previous_sunset(filename)
      # tweetpic("here's tonight's sunset: ", previous_sunset_filename) if sunsettiness(previous_sunset_filename) > sunsettiness(filename)
      tweetpic(test ? "here's a test sunset not from today" : "here's tonight's sunset: ", pic_filename)
    else
      puts "nope, no sunset"
      #TODO: tweet that there's no sunset at 10pm if there hasn't been a good sunset.
      FileUtils.move(pic_filename, "not_a_#{pic_filename}") unless pic_filename.nil?
    end
    sleep 60 * self.how_often_to_take_a_picture
  end

  def sunsettiness(filename)
    c = ColorCounter.count_colors(filename)
    puts filename + ": " + c.inspect
    return (c[true].to_f / c[false]) 
  end

  def is_a_sunset?(filename)
    return self.sunsettiness(filename) > self.sunsettiness_threshold
  end

  def previous_sunset(filename)
    sorted_files = Dir.glob("sunset*").sort
    sorted_files[sorted_files.index(filename) - 1 ]
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
    "sunset_#{time}.jpg"
  end


  def tweetpic(status, photo_filename)
    info = {}
    info["lat"] = 40.706996
    info["long"] = -74.013283
    Twitter.update_with_media(status, open(photo_filename, 'rb').read, info)
  end

end
s = SunsetDetector.new
s.perform
