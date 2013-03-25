require './count_colors'
require 'fileutils'
require 'open3'

class SunsetDetector
  attr_accessor :how_often_to_take_a_picture, :sunsettiness_threshold, :interface

  def initialize(interface = "video0", &blk)
    self.how_often_to_take_a_picture = 0.25 #minutes
    self.sunsettiness_threshold = 0.1

    c = ColorCounter.new
    # Dir.glob("*.jpg").each do |pic_filename| 
    #   blk.call(self.detect_sunset(pic_filename))
    # end
    loop do
      pic_filename = self.take_a_picture(interface)
      blk.call(self.detect_sunset(pic_filename))
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

s = SunsetDetector.new do |bool| 
  if bool
    puts "that was a sunset"
  else
    puts "nope, no sunset"
  end
end
