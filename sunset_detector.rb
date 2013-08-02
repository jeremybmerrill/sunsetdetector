# encoding: utf-8

require './count_colors'
#require './photograph'
require './fancypantsmath'
require 'fileutils'
require 'open3'
require 'twitter'
require 'sequel'
require 'yaml'

# TODO: 
# tweet pictures of sunsets; wait five minutes, if picture n is less sunsetty than picture n-1, tweet picture n-1
# eventually, rate all of the tweeted sunsets, use that as training data.

#TODO: fix memory leaks http://stackoverflow.com/questions/958681/how-to-deal-with-memory-leaks-in-rmagick-in-ruby

#TODO: tweet gif of the day's photos.
#TODO: figure out fast fourier transform thing.

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
CAPTURE_CMD = "fswebcam --set contrast=20% --set brightness=30% -r 1280x720 -D 1 -S 3 --no-banner --save #{CAPTURE_OUTPUT_FILENAME}" || ENV["CAPTURE_CMD"]
#for the spreadsheeted data, contrast and birghtness were both 20.

class SunsetDetector
  include ColorCounter
  attr_accessor :how_often_to_take_a_picture, :twitter_account, :previous_photos, :debug, :db, :gain, :contrast, :brightness, :saturation, :gif_temp_dir, :acct_auth_details, :fake, :most_recent_hundred_photos

  SUNSET_THRESHOLD = 0.04

  def initialize(debug=false) #, interface = "video0")

    self.db = Sequel.connect("mysql2://root@localhost/sunsetdetector") #DB = Sequel.connect('postgres://user:password@host:port/database_name')
    require './photograph' #TODO: gross, but the DB needs to exist before we initialize the Photogrpah object.
    require './vote'
    FileUtils.mkdir_p("photos")

    self.debug = debug
    $fake = self.fake = ENV['FAKE'] || false
    puts "I'm in debug mode!" if self.debug
    puts "I'm in fake mode!" if self.fake

    auth_details = YAML.load(open("authdetails.yml", 'r').read)
    self.acct_auth_details = auth_details[self.debug ? "debug" : "default"]
    self.twitter_account = self.acct_auth_details["handle"]

    if self.fake
      self.most_recent_hundred_photos = []
      self.most_recent_hundred_photos = Dir["testphotos/*"].sort_by{ |photo_filename| photo_filename.gsub("testphotos/not_a_sunset_", "").gsub(".jpg", "").gsub("testphotos/sunset_","").to_i }
      puts "done queuing"
    end

    self.gif_temp_dir = "gif_temp"

    self.configure_twitter!

    self.how_often_to_take_a_picture = self.fake ? 0.0 : 1 #minutes
    self.previous_photos = []
  end

  def create_test_set
    Dir["photos/*"].sort_by{ |photo_filename| photo_filename.gsub("photos/not_a_sunset_", "").gsub(".jpg", "").gsub("photos/sunset_","").to_i }[-1000..-801].each do |fn|
      FileUtils.mkdir("testphotos") unless Dir.exists?("testphotos")
      FileUtils.cp(fn, fn.gsub("photos", "testphotos"))
    end
  end

  def configure_twitter!
    Twitter.configure do |config|
      config.consumer_key = self.acct_auth_details["consumerKey"]
      config.consumer_secret = self.acct_auth_details["consumerSecret"]
      config.oauth_token = self.acct_auth_details["accessToken"]
      config.oauth_token_secret = self.acct_auth_details["accessSecret"]
    end
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
      if self.fake
        photo_fn = self.most_recent_hundred_photos.shift
        break unless photo_fn
        photo = Photograph.new
        photo.filename = photo_fn
        photo.test = true
        puts "took a photo from the q, sunsettiness: #{photo.sunsettiness}"
      else
        photo = self.take_a_picture(CAPTURE_CMD)
      end
      unless photo.nil?
        self.detect_sunset(photo)
      else
        puts "photo is nil"
      end
      puts [ photo.test ? "test" : "", photo.filename, photo.sunsettiness, photo.taken.to_s].inspect
      #TODO: set up.
      # new_tweets = self.search_twitter
      # if new_tweets
      #   puts "New tweets: " + new_tweets.inspect
      # else
      #   #puts "no new tweets :("
      # end 
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

  def gifify_today
  end
  def gifify_todays_sunset
    #find the latest sunset
    #gif everything in the previous hour
    
    raise NeedsToBeFixedToWorkWithArrayOfPreviousSunsetsError
    if self.previous_sunset
      most_recent_sunset_time = self.previous_sunset.gsub("photos/sunset_", "").gsub(".jpg", "")
    else
      most_recent_sunset_time = Dir["photos/sunset_*"].sort.last.gsub("photos/sunset_", "").gsub(".jpg", "")
    end
    puts "most recent sunset: #{most_recent_sunset_time}"
    gifify(most_recent_sunset_time.to_i + (20 * 60), 1.5, 1) #start 20 minutes after sunset.
  end

  def gifify(start_time, hours_back, skip_interval)
   #TODO: allow diff days to be selected?
    #find all photos in the last 24 hours
    require 'fileutils'
    FileUtils.rm_r(self.gif_temp_dir) if File.exists?(self.gif_temp_dir)
    todays_photos = Dir["photos/*"].select do |photo_filename|
      photo_time = photo_filename.gsub("photos/not_a_sunset_", "").gsub(".jpg", "").gsub("photos/sunset_","").to_i
      photo_time > ( start_time - hours_back * 60 * 60) && photo_time < start_time
    end
    todays_photos_smaller = []
    todays_photos.each_with_index{|p, i| todays_photos_smaller << p if i % skip_interval == 0}
    FileUtils.mkdir(self.gif_temp_dir)
    todays_photos_smaller.each{|filename| FileUtils.cp(filename, filename.gsub("photos", self.gif_temp_dir).gsub("not_a_", ""))}
    puts "gifin' #{todays_photos_smaller.size} photos, be done in a giffy!"
    `convert -delay 100 -resize 300x300 -loop 0 #{self.gif_temp_dir}/* todayssunset.gif`
    puts "done"
    FileUtils.rm_r(self.gif_temp_dir)
  end

  def should_tweet_now?(most_recent_photo)
    return false unless self.previous_photos.size % 5 == 0

    amount_of_sunsets = 50

    num_sunsets = [self.previous_photos.size, amount_of_sunsets].min
    #puts "fancypants math says this is " + (FancyPantsMath::do_some_calculus(self.previous_photos[-num_sunsets..-1].map(&:sunsettiness).compact) ? "" : "not ") + "a sunset"
    #self.previous_photos[-15..-1] && self.previous_photos[-15..-1].count{|photo| photo.sunsettiness > SUNSET_THRESHOLD * 0.75} > 10 && most_recent_photo.is_a_sunset?(SUNSET_THRESHOLD)
    FancyPantsMath::do_some_calculus(self.previous_photos[-num_sunsets..-1].map(&:find_sunsettiness).compact)
  end

  # def does_math_say_I_should_tweet_now?(most_recent_photo)
  #   FancyPantsMath.do_some_calculus(self.previous_photos[-100, -1].map(&:sunsettiness))
  # end

  def detect_sunset(photo)
    #tweet only if this is a local maximum in sunsettiness.
    #unless self.debug
    if (sunset_index = should_tweet_now?(photo))
      puts "I should tweet now ##{sunset_index}."
      begin
        #TODO: votes: "I think this is a sunset. Is it? If so, please respond \"Yes\", otherwise, \"No\"."
        self.previous_photos[-FancyPantsMath::IMAGES_TO_CONSIDER + sunset_index].tweet(self.previous_photos.last.test ? "here's a test sunset" : "Here's tonight's sunset: ", self.debug)
        puts "tweeted!"
      rescue Twitter::Error::ClientError
        puts "Heckit! Reconftigyurin Twiter."
        self.configure_twitter!
        retry
      end
      #self.delete_old_non_sunsets #heh, there's hella memory on this memory card.
    end
    puts "#{Time.now}: #{photo.filename}"
    self.previous_photos << photo
    # if photo.is_a_sunset?(SUNSET_THRESHOLD)
    #   puts "that was sunsetty"
    #   self.previous_photos << photo
    # else
    #   puts "nope, not sunsetty"
    #   photo.move("photos/not_a_#{File.basename(photo.filename)}") unless self.fake
    #   self.previous_photos << photo
    # end
    # else
    #   if photo.is_a_sunset?(SUNSET_THRESHOLD)
    #     photo.tweet("sunsettiness: #{photo.sunsettiness.to_s[0..7]}, threshold: #{photo.sunset_proportion_threshold.to_s[0..7]}")
    #     highlighted_photo = ColorCounter.highlight_sunsety_colors(photo.filename)
    #     Twitter.update_with_media("highlighted, sunsettiness: #{photo.sunsettiness.to_s[0..7]}", open(highlighted_photo).read )
    #     photo.move("photos/not_a_#{File.basename(photo.filename)}") unless photo.is_a_sunset?(SUNSET_THRESHOLD)
    #   end
    # end
  end

  def take_a_picture(capture_cmd = CAPTURE_CMD)
    _i, _o, _e = Open3.popen3(capture_cmd)
    _o.read
    _e.read
    _i.close
    _o.close
    _e.close
    if(File.exists?(CAPTURE_OUTPUT_FILENAME))
      time = Time.now
      FileUtils.move(CAPTURE_OUTPUT_FILENAME, "photos/sunset_#{time.to_i}.jpg")
      p = Photograph.new #("photos/sunset_#{time.to_i}.jpg")
      p.filename = "photos/sunset_#{time.to_i}.jpg"
      p.taken = time
      p.sunsettiness = p.find_sunsettiness
      p.save
      p
    else
      puts "Whoops, couldn't find the photo. Skipping."
      nil
    end
  end

  def search_twitter   
    #TODO: deal with rate limit.
    return false if self.fake
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
  s = SunsetDetector.new(ENV['DEBUG'] || false)
  s.perform
end
