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
#logitech: fswebcam doesn't require settings bullshit.

#TODO: use naive bayes


# SATURATION = ENV['SATURATION'] || 50
# BRIGHTNESS = ENV['BRIGHTNESS'] || 170
# CONTRAST = ENV['CONTRAST'] || 50
# GAIN = ENV['GAIN'] || 0
#CAPTURE_CMD = "uvccapture -S#{SATURATION} -B#{BRIGHTNESS} -C#{CONTRAST} -G#{GAIN} -x1280 -y960" || ENV["CAPTURE_CMD"]
CAPTURE_OUTPUT_FILENAME = "snap.jpg"
CAPTURE_CMD = "fswebcam -r 1280x720 -D 1 -S 3 --no-banner --save #{CAPTURE_OUTPUT_FILENAME}" || ENV["CAPTURE_CMD"]
DEBUG = ENV['DEBUG']

class SunsetDetector
  include ColorCounter
    attr_accessor :how_often_to_take_a_picture, :twitter_account, :previous_sunset, :debug, :db


  def initialize(how_often_to_take_a_picture=5) #, interface = "video0")

    self.db = Sequel.connect("mysql2://root@localhost/sunsetdetector") #DB = Sequel.connect('postgres://user:password@host:port/database_name')
    require './photograph' #TODO: gross, but the DB needs to exist before we initialize the Photogrpah object.
    require './vote'

    self.debug = DEBUG
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

    self.how_often_to_take_a_picture = self.debug ? 1: 5 #minutes
    self.previous_sunset = nil
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
      before_pic_time = Time.now
      photo = self.take_a_picture(CAPTURE_CMD)
      self.detect_sunset(photo)
      new_tweets = self.search_twitter
      if new_tweets
        puts new_tweets.inspect
      else
        puts "no new tweets :("
      end 
      processing_duration = Time.now - before_pic_time
      time_to_sleep = [(60 * self.how_often_to_take_a_picture) - processing_duration, 0].max
      sleep time_to_sleep
    end
  end

  def delete_old_non_sunsets
      #deletes unneeded old photo files (but not DB entries)
      old_sunsets = Dir.glob("not_a_sunset*")
      old_sunsets = Dir.glob("photos/not_a_sunset*")
      old_sunsets.select{|filename| filename.gsub("not_a_sunset_", "").gsub(".jpg", "").to_i < (Time.now.to_i - 60*60*24)}.each{|f| FileUtils.rm(f) } unless old_sunsets.empty?
  end

  def detect_sunset(photo)
    if !self.debug
    #tweet only if this is a local maximum in sunsettiness.
      if self.previous_sunset && (!photo.is_a_sunset?  || self.previous_sunset > photo)
        self.previous_sunset.tweet!("I think this is a sunset. Is it? If so, please respond \"Yes\", otherwise, \"No\".")
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
      photo.tweet!("sunsettiness: #{photo.sunsettiness.to_s[0..7]}")
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
    time = Time.now

    new_filename = "photos/sunset_#{time.to_i.to_s}.jpg"
    FileUtils.move(CAPTURE_OUTPUT_FILENAME, new_filename)
    p = Photograph.new(:filename => new_filename)
    p.taken = time
    p.sunsettiness = p.find_sunsettiness
    p.save
    p
  end

  def search_twitter   
    #TODO: deal with rate limit.
    Twitter.mentions_timeline.select do |tweet|
      if(Vote.where(:tweet_id => tweet.id).empty?)
        v = Vote.new
        v.text = tweet.text
        v.set_value
        v.username = tweet.from_user_name
        v.user_id = tweet.from_user_id
        v.tweet_id = tweet.id
        v.photograph = Photograph.find(:tweet_id => tweet.in_reply_to_status_id.to_s)
        v.save
        puts "\"#{tweet.text}\" is a #{v.value} vote for photo ##{v.photograph_id}, #{Photograph.find(:id => v.photograph_id)}"
        true
      else
        false
      end
    end
  end
end

if __FILE__ == $0
  s = SunsetDetector.new(0.25)
  s.perform
end
