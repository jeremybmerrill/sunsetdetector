require 'sequel'
require 'fileutils'

class Photograph < Sequel::Model
  #Look at this photograph
  #every time I do it makes me RT
  include Comparable
  set_primary_key :id
  one_to_many :votes

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

  def ground_truth_sunset_proportion #TODO: account for nils
    self.votes.inject(0.0){|memo, v| memo += v.value ? 1.0 : 0.0} / self.votes.count
  end

  def is_a_sunset?(sunset_proportion_threshold=0.05)
    puts "#{self.filename}: #{self.sunsettiness}"
    return self.sunsettiness > sunset_proportion_threshold
  end

  def tweet!(status)
    info = {}
    info["lat"] = 40.706996
    info["long"] = -74.013283
    this_tweet = Twitter.update_with_media(status, open(self.filename, 'rb').read, info)
    puts this_tweet.inspect
    self.tweet_id = this_tweet.id.to_s
    self.save
    puts "set this photo's tweet_id to " + tweet_id.to_s
  end

  def find_sunsettiness
    c = ColorCounter.count_sunsetty_colors(self.filename) #optionally, color_distance_threshold can be set here for distance from sunset color points.
    return c[true].to_f / c[false].to_f
  end
end