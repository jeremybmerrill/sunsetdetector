require 'sequel'

class Photograph < Sequel::Model
  #Look at this photograph
  #every time I do it makes me RT
  include Comparable
  set_primary_key :id
  one_to_many :vote

  def <=>(another_photo)
    if self.sunsettiness < another_photo.sunsettiness
      -1
    elsif self.sunsettiness > another_photo.sunsettiness
      1
    else
      0
    end
  end

  def ground_truth_sunset_proportion
    self.votes.inject(0){|v, memo| memo += v.value ? 1 : 0} / self.votes.count
  end

  def is_a_sunset?(sunset_proportion_threshold=0.05)
    puts "#{self.filename}: #{self.sunsettiness}"
    return self.sunsettiness > sunset_proportion_threshold
  end

  def tweet(status)
    info = {}
    info["lat"] = 40.706996
    info["long"] = -74.013283
    this_tweet = Twitter.update_with_media(status, open(self.filename, 'rb').read, info)
    self.tweet_id = this_tweet.id
    self.save
  end

  def find_sunsettiness
    c = ColorCounter.count_sunsetty_colors(self.filename) #optionally, color_distance_threshold can be set here for distance from sunset color points.
    return c[true].to_f / c[false].to_f
  end
end

class Vote  < Sequel::Model
  many_to_one :photograph

end