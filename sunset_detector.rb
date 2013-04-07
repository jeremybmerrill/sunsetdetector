require './count_colors'
require 'fileutils'
require 'open3'
require 'twitter'
require 'sequel'

# TODO: 
# tweet pictures of sunsets; wait five minutes, if picture n is less sunsetty than picture n-1, tweet picture n-1
# eventually, rate all of the tweeted sunsets, use that as training data.

class SunsetDetector
  attr_accessor :how_often_to_take_a_picture, :interface, :previous_sunset
  DB = Sequel.connect("mysql2://root@localhost/sunsetdetector") #DB = Sequel.connect('postgres://user:password@host:port/database_name')

  def initialize(how_often_to_take_a_picture=5, interface = "video0")
    
    require './photograph' #TODO: gross, but the DB needs to exist before we initialize the Photogrpah object.

    authdetails = open("authdetails.txt", 'r').read.split("\n")
    FileUtils.mkdir_p("photos")
    #self.database_stuff()
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
      photo = self.take_a_picture(self.interface)
      self.detect_sunset(photo)
      sleep 60 * self.how_often_to_take_a_picture
    end
  end

  def delete_old_non_sunsets
      #deletes unneeded old photo files (but not DB entries)
      old_sunsets = Dir.glob("not_a_sunset*")
      old_sunsets.select{|filename| filename.gsub("not_a_sunset_", "").gsub(".jpg", "").to_i < (Time.now.to_i - 60*60*24)}.each{|f| FileUtils.rm(f) } unless old_sunsets.empty?
  end

  def detect_sunset(photo)
    #tweet only if this is a local maximum in sunsettiness.
    if self.previous_sunset && (!photo.is_a_sunset?  || self.previous_sunset > photo)
      self.previous_sunset.tweet("I think this is a sunset. Is it? If so, please respond \"Yes\", otherwise, \"No\".")
      self.previous_sunset = nil
      #self.delete_old_non_sunsets 
    end
    if photo.is_a_sunset?
        puts "that was a sunset"
        self.previous_sunset = photo
    else
      puts "nope, no sunset"
      FileUtils.move(photo.filename, "photos/not_a_#{photo.filename}")
    end
  end

  def take_a_picture(interface="video0")
    #TODO: record exif data
    cmd = "mplayer -vo jpeg -frames 1 -tv driver=v4l2:width=640:height=480:device=/dev/#{interface} tv://"
    _i, _o, _e = Open3.popen3(cmd)
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
    #get all tweets that mention @propubsunset
  end
end

s = SunsetDetector.new(0.25)
#s.perform
