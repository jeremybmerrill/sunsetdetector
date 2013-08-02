require 'fileutils'
require 'sequel'

class Photograph < Sequel::Model
  #Look at this photograph
  #every time I do it makes me RT
  include Comparable
  set_primary_key :id
  one_to_many :votes
  attr_accessor :filename, :is_a_sunset, :test, :sunsettiness, :sunset_proportion_threshold, :tweet_id, :taken

  # def initialize(filename, is_a_test=false)
  #   self.filename = filename
  #   self.is_a_sunset = nil
  #   self.test = is_a_test
  #   self.sunsettiness = self.find_sunsettiness
  # end

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

  def is_a_sunset?(sunset_proportion_threshold)
    return self.is_a_sunset if (!self.is_a_sunset.nil? && sunset_proportion_threshold == self.sunset_proportion_threshold)
    self.sunsettiness = self.find_sunsettiness
    self.is_a_sunset = self.sunsettiness > sunset_proportion_threshold
    puts "#{Time.now}: #{self.filename}: #{self.sunsettiness}"
    self.sunset_proportion_threshold = sunset_proportion_threshold
    return self.is_a_sunset
  end

  def tweet(status, fake=false)
    info = {}
    info["lat"] = 40.706996
    info["long"] = -74.013283
    begin
      this_tweet = Twitter.update_with_media(status, open(self.filename, 'rb').read, info)
    rescue Timeout::Error => te
      puts "TWITER: Heckit! sendin youm messiges failt."
      retry
    rescue Twitter::Error::ServiceUnavailable
      puts "TWITER: Heckit! sendin youm messiges failt."
      retry
    end
    self.tweet_id = this_tweet.id.to_s
    self.save unless fake
    puts "Tweeted: #{status} #{self.filename}; id ##{this_tweet.id}"
  end

  def find_sunsettiness
    c = ColorCounter::count_sunsetty_colors(self.filename) #optionally, color_distance_threshold can be set here for distance from sunset color points.
    self.sunsettiness = c[true].to_f / c[false].to_f
    self.save
    puts self.sunsettiness
    return self.sunsettiness
  end
end
