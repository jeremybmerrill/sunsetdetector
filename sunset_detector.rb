require './count_colors'
require 'fileutils'
require 'open3'
require 'twitter'
require 'sequel'
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
CAPTURE_CMD = "fswebcam -r 1280x720 -D 1 -S 3 --no-banner --save #{CAPTURE_OUTPUT_FILENAME}" || ENV["CAPTURE_CMD"]


class SunsetDetector

  def initialize(how_often_to_take_a_picture=5, interface = "video0")
    include ColorCounter
    attr_accessor :how_often_to_take_a_picture, :twitter_account, :previous_sunset, :debug, :gain, :contrast, :brightness, :saturation

    DB = Sequel.connect("mysql2://root@localhost/sunsetdetector") #DB = Sequel.connect('postgres://user:password@host:port/database_name')
    require './photograph' #TODO: gross, but the DB needs to exist before we initialize the Photogrpah object.
    
    self.debug = debug
    FileUtils.mkdir_p("photos")
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

  def bootstrap_photographs
    Photograph.bootstrap(DB)
    self.rescan_photographs
  end

  def rescan_photographs
    # populate the table
    (Dir.glob("photos/sunset_*") + Dir.glob("photos/not_a_sunset_*")).each do |filename|
      unless Photograph.find(:filename => filename)
        p = Photograph.find_or_create :filename => filename
        puts filename.gsub("not_a_sunset_", "").gsub("sunset_", "").gsub(".jpg", "")
        p.taken = DateTime.strptime(filename.gsub("photos/not_a_sunset_", "").gsub("photos/sunset_", "").gsub(".jpg", ""), "%s")
        p.sunsettiness = p.find_sunsettiness
        p.save
      end
    end
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
      photo = self.take_a_picture(CAPTURE_CMD)
      self.detect_sunset(photo)
      sleep 60 * self.how_often_to_take_a_picture
    end
  end

  def delete_old_non_sunsets
      #deletes unneeded old photo files (but not DB entries)
      old_sunsets = Dir.glob("not_a_sunset*")
      old_sunsets = Dir.glob("photos/not_a_sunset*")
      old_sunsets.select{|filename| filename.gsub("not_a_sunset_", "").gsub(".jpg", "").to_i < (Time.now.to_i - 60*60*24)}.each{|f| FileUtils.rm(f) } unless old_sunsets.empty?
  end

  def detect_sunset(photo)
    #tweet only if this is a local maximum in sunsettiness.
    unless self.debug
      if self.previous_sunset && (!photo.is_a_sunset?  || self.previous_sunset > photo)
        self.previous_sunset.tweet("I think this is a sunset. Is it? If so, please respond \"Yes\", otherwise, \"No\".")
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
      photo.tweet("gain: #{self.gain.to_s[0..7]}; brightness: #{self.brightness.to_s[0..7]}, contrast: #{self.contrast.to_s[0..7]}, saturation: #{self.saturation.to_s[0..7]}, sunsettiness: #{photo.sunsettiness.to_s[0..7]}, threshold: #{photo.sunset_proportion_threshold.to_s[0..7]}")
      photo.move("photos/not_a_#{File.basename(photo.filename)}") unless photo.is_a_sunset?
    end

  end

  def take_a_picture(capture_cmd = CAPTURE_CMD)
    _i, _o, _e = Open3.popen3(capture_cmd)
    _o.read
    _e.read
    _i.close
    _o.close
    _e.close
    time = Time.now.to_i

    FileUtils.move("00000001.jpg", "photos/sunset_#{time.to_s}.jpg")
    p = Photograph.new :filename => "sunset_#{time}.jpg"
    p.taken = time
    p.save
    p
  end

  def search_twitter   
    Twitter.mentions_timeline.each do |tweet|
      tweet.in_reply_to_status_id
      v = Vote.new(tweet.text)
      v.user = tweet.from_user_name
      v.user_id = tweet.from_user_id
      v.tweet_id = tweet.id
      v.photograph_id = Photograph.find_by_tweet_id(tweet.in_reply_to_status_id)
      v.save
      puts "\"#{tweet}\" is a #{v.value} vote for #{v.photograph_id}"
    end
  end
end

s = SunsetDetector.new(0.25)
s.perform
