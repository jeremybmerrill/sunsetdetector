require './count_colors'
require 'fileutils'
require 'open3'
require 'twitter'
require 'yaml'

# TODO: 
# tweet pictures of sunsets; wait five minutes, if picture n is less sunsetty than picture n-1, tweet picture n-1
# eventually, rate all of the tweeted sunsets, use that as training data.

#TODO: fix memory leaks http://stackoverflow.com/questions/958681/how-to-deal-with-memory-leaks-in-rmagick-in-ruby

#TODO: include processing time in sleep amount 

#TODO: gif all of a day's photos, (compress) and tweet.

#good settings: 
  #gain: 20; brightness: 90, contrast: 30, saturation: 50, sunsettiness: 0.135144, threshold: pic.twitter.com/2xfniujNUN
  #gain: 80; brightness: 0, contrast: 20, saturation: 30, sunsettiness: 0.027367, threshold: pic.twitter.com/of1P9LYfVN

#creative: "mplayer -vo jpeg -frames 1 -tv driver=v4l2:width=640:height=480:device=/dev/#{interface} tv://"
#logitech: uvccapture -S80 -B80 -C80 -G80 -x800 -y600 # has 1280x960, is UVC
SATURATION = ENV['SATURATION'] || 50
BRIGHTNESS = ENV['BRIGHTNESS'] || 170
CONTRAST = ENV['CONTRAST'] || 50
GAIN = ENV['GAIN'] || 0
#CAPTURE_CMD = "uvccapture -S#{SATURATION} -B#{BRIGHTNESS} -C#{CONTRAST} -G#{GAIN} -x1280 -y960" || ENV["CAPTURE_CMD"]
CAPTURE_OUTPUT_FILENAME = "snap.jpg"
CAPTURE_CMD = "fswebcam --set contrast=20% -r 1280x720 -D 1 -S 3 --no-banner --save #{CAPTURE_OUTPUT_FILENAME}" || ENV["CAPTURE_CMD"]


class SunsetDetector
  include ColorCounter
  attr_accessor :how_often_to_take_a_picture, :twitter_account, :previous_sunset, :debug, :gain, :contrast, :brightness, :saturation

  def initialize(debug=false)
    self.debug = debug
    puts "I'm in debug mode!" if self.debug
    auth_details = YAML.load(open("authdetails.yml", 'r').read)
    acct_auth_details = auth_details[self.debug ? "debug" : "default"]
    self.twitter_account = acct_auth_details["handle"]

    Twitter.configure do |config|
      config.consumer_key = acct_auth_details["consumerKey"]
      config.consumer_secret = acct_auth_details["consumerSecret"]
      config.oauth_token = acct_auth_details["accessToken"]
      config.oauth_token_secret = acct_auth_details["accessSecret"]
    end

    self.how_often_to_take_a_picture = self.debug ? 0 : 5 #minutes
    self.previous_sunset = nil
  end

  def perform
    #self.detect_sunset(Photograph.new("propublicasunsetfromlena.jpg", true)) #test
    loop do
      # if self.debug
      #   self.gain = 0 #((0...10).to_a.sample * 10)
      #   self.saturation = 50 #((3...6).to_a.sample * 10)
      #   self.contrast = 50 #((3...6).to_a.sample * 10)
      #   self.brightness = ((5...10).to_a.sample * 10) + 100
      #   capture_cmd = "uvccapture -S#{self.saturation} -B#{self.brightness} -C#{self.contrast} -G#{self.gain} -x1280 -y960"
      # end
      before_pic_time = Time.now
      photo = self.take_a_picture(CAPTURE_CMD)
      self.detect_sunset(photo) unless photo.nil?
      processing_duration = Time.now - before_pic_time
      time_to_sleep = [(60 * self.how_often_to_take_a_picture) - processing_duration, 0].max
      sleep time_to_sleep
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
        #self.delete_old_non_sunsets #heh, there's hella memory on this memory card.
      end
      if photo.is_a_sunset?
          puts "that was a sunset"
          self.previous_sunset = photo
      else
        puts "nope, no sunset"
        photo.move("photos/not_a_#{File.basename(photo.filename)}")
      end
    else
      if photo.is_a_sunset?
        photo.tweet("sunsettiness: #{photo.sunsettiness.to_s[0..7]}, threshold: #{photo.sunset_proportion_threshold.to_s[0..7]}")
        highlighted_photo = ColorCounter.highlight_sunsety_colors(photo.filename)
        Twitter.update_with_media("highlighted, sunsettiness: #{photo.sunsettiness.to_s[0..7]}", highlighted_photo)
        photo.move("photos/not_a_#{File.basename(photo.filename)}") unless photo.is_a_sunset?
      end
    end

  end

  def take_a_picture(capture_cmd = CAPTURE_CMD)
    _i, _o, _e = Open3.popen3(capture_cmd)
    _o.read
    _e.read
    _i.close
    _o.close
    _e.close
    time = Time.now.to_i.to_s
    if(File.exists?(CAPTURE_OUTPUT_FILENAME))
      FileUtils.move(CAPTURE_OUTPUT_FILENAME, "photos/sunset_#{time}.jpg")
      Photograph.new("photos/sunset_#{time}.jpg")
    else
      puts "Whoops, couldn't find the photo. Skipping."
      nil
    end
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

  def is_a_sunset?(sunset_proportion_threshold=0.07)
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


s = SunsetDetector.new(ENV['DEBUG'] || false)
s.perform
