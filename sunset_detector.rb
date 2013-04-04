require './count_colors'
require 'fileutils'
require 'open3'
require 'twitter'
require 'yaml'

# TODO: 
# tweet pictures of sunsets; wait five minutes, if picture n is less sunsetty than picture n-1, tweet picture n-1
# eventually, rate all of the tweeted sunsets, use that as training data.

# new camera has 1280x960, is UVC

#TODO: debug mode that takes pictures often, tweets all of them to a debug twitter account.
#fix memory leaks http://stackoverflow.com/questions/958681/how-to-deal-with-memory-leaks-in-rmagick-in-ruby

#creative: "mplayer -vo jpeg -frames 1 -tv driver=v4l2:width=640:height=480:device=/dev/#{interface} tv://"
#logitech: uvccapture -S80 -B80 -C80 -G80 -x800 -y600
CAPTURE_CMD = "uvccapture -S80 -B80 -C80 -G80 -x1280 -y960"
CAPTURE_OUTPUT_FILENAME = "snap.jpg"

class SunsetDetector
  include ColorCounter
  attr_accessor :how_often_to_take_a_picture, :twitter_account, :previous_sunset, :debug

  def initialize(how_often_to_take_a_picture=5, debug=false)
    self.debug = debug
    puts "I'm in debug mode!" if self.debug
    auth_details = YAML.load(open("authdetails.yml", 'r').read)
    acct_auth_details = auth_details[debug ? "debug" : "default"]
    self.twitter_account = acct_auth_details[:handle]

    Twitter.configure do |config|
      config.consumer_key = acct_auth_details[:consumerKey]
      config.consumer_secret = acct_auth_details[:consumerSecret]
      config.oauth_token = acct_auth_details[:accessToken]
      config.oauth_token_secret = acct_auth_details[:accessSecret]
    end

    self.how_often_to_take_a_picture = how_often_to_take_a_picture #minutes
    self.previous_sunset = nil
  end

  def perform
    #self.detect_sunset(Photograph.new("propublicasunsetfromlena.jpg", true)) #test
    loop do
      photo = self.take_a_picture()
      self.detect_sunset(photo)
      sleep 60 * self.how_often_to_take_a_picture
    end
  end

  def delete_old_non_sunsets
      old_sunsets = Dir.glob("photos/not_a_sunset*")
      old_sunsets.select{|filename| filename.gsub("not_a_sunset_", "").gsub(".jpg", "").to_i < (Time.now.to_i - 60*60*24)}.each{|f| FileUtils.rm(f) } unless old_sunsets.empty?
  end

  def detect_sunset(photo)
    #tweet only if this is a local maximum in sunsettiness.
    unless self.debug
      if self.previous_sunset && (!photo.is_a_sunset?  || self.previous_sunset > photo)
        self.previous_sunset.tweet(previous_sunset.test ? "here's a test sunset" : "Here's tonight's sunset: ")
        self.previous_sunset = nil
        self.delete_old_non_sunsets
      end
      if photo.is_a_sunset?
          puts "that was a sunset"
          self.previous_sunset = photo
      else
        puts "nope, no sunset"
        photo.move("photos/not_a_#{File.basename(photo.filename)}")
      end
    else
      photo.tweet("debug. sunsettiness: #{photo.sunsettiness}, threshold: #{photo.sunset_proportion_threshold}")
      photo.move("photos/not_a_#{File.basename(photo.filename)}") unless photo.is_a_sunset?
    end

  end

  def take_a_picture()
    _i, _o, _e = Open3.popen3(CAPTURE_CMD)
    _o.read
    _e.read
    _i.close
    _o.close
    _e.close
    time = Time.now.to_i.to_s
    FileUtils.move(CAPTURE_OUTPUT_FILENAME, "photos/sunset_#{time}.jpg")
    Photograph.new("photos/sunset_#{time}.jpg")
  end
end

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
    puts "Tweeted: #{status} #{self.filename}"
  end

  def find_sunsettiness
    c = ColorCounter::count_sunsetty_colors(self.filename) #optionally, color_distance_threshold can be set here for distance from sunset color points.
    return c[true].to_f / c[false].to_f
  end

end


s = SunsetDetector.new(0.25, true)
s.perform
