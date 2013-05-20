require './count_colors'
require './photograph'
require 'fileutils'
require 'open3'
require 'twitter'
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
SATURATION = ENV['SATURATION'] || 50
BRIGHTNESS = ENV['BRIGHTNESS'] || 170
CONTRAST = ENV['CONTRAST'] || 50
GAIN = ENV['GAIN'] || 0
#CAPTURE_CMD = "uvccapture -S#{SATURATION} -B#{BRIGHTNESS} -C#{CONTRAST} -G#{GAIN} -x1280 -y960" || ENV["CAPTURE_CMD"]
CAPTURE_OUTPUT_FILENAME = "snap.jpg"
CAPTURE_CMD = "fswebcam --set contrast=20% --set brightness=30% -r 1280x720 -D 1 -S 3 --no-banner --save #{CAPTURE_OUTPUT_FILENAME}" || ENV["CAPTURE_CMD"]
#for the spreadsheeted data, contrast and birghtness were both 20.

class SunsetDetector
  include ColorCounter
  attr_accessor :how_often_to_take_a_picture, :twitter_account, :previous_sunsets, :debug, :gain, :contrast, :brightness, :saturation, :gif_temp_dir, :acct_auth_details

  SUNSET_THRESHOLD = 0.04

  def initialize(debug=false)
    self.debug = debug
    puts "I'm in debug mode!" if self.debug
    auth_details = YAML.load(open("authdetails.yml", 'r').read)
    self.acct_auth_details = auth_details[self.debug ? "debug" : "default"]
    self.twitter_account = self.acct_auth_details["handle"]

    self.gif_temp_dir = "gif_temp"

    self.configure_twitter!

    self.how_often_to_take_a_picture = self.debug ? 1 : 1 #minutes
    self.previous_sunsets = []
  end

  def configure_twitter!
    Twitter.configure do |config|
      config.consumer_key = self.acct_auth_details["consumerKey"]
      config.consumer_secret = self.acct_auth_details["consumerSecret"]
      config.oauth_token = self.acct_auth_details["accessToken"]
      config.oauth_token_secret = self.acct_auth_details["accessSecret"]
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
    self.previous_sunsets && self.previous_sunsets[-15..-1].count{|photo| photo > most_recent_photo} > 10 && most_recent_photo.is_a_sunset?
  end

  def detect_sunset(photo)
    #tweet only if this is a local maximum in sunsettiness.
    #unless self.debug
      if should_tweet_now?(photo)

        begin
          self.previous_sunsets.last.tweet(self.previous_sunsets.last.test ? "here's a test sunset" : "Here's tonight's sunset: ")
        rescue Twitter::Error::ClientError
          puts "Heckit! Reconfiguring Twitter."
          self.configure_twitter!
          retry
        end

        #self.delete_old_non_sunsets #heh, there's hella memory on this memory card.
      end
      if photo.is_a_sunset?(SUNSET_THRESHOLD)
          puts "that was a sunset"
          self.previous_sunsets << photo
      else
        puts "nope, no sunset"
        photo.move("photos/not_a_#{File.basename(photo.filename)}")
      end
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
    time = Time.now.to_i.to_s
    if(File.exists?(CAPTURE_OUTPUT_FILENAME))
      FileUtils.move(CAPTURE_OUTPUT_FILENAME, "photos/sunset_#{time}.jpg")
      Photograph.new("photos/sunset_#{time}.jpg")
    else
      puts "Whoops, couldn't find the photo. Skipping."
      nil
    end
  end

  def fourier_transform

  end
end
if __FILE__ == $0
  s = SunsetDetector.new(ENV['DEBUG'] || false)
  s.perform
end
