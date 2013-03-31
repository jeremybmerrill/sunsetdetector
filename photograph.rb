require 'sequel'

class Photograph  < Sequel::Model
  """Look at this photograph
  every time I do it makes me RT"""
  include Comparable
  set_primary_key :id

  def Photograph.bootstrap(db)
    # create an items table

    #TODO: create separate objects for twitter votes.
    db.create_table :photographs do
      primary_key :id
      DateTime :taken
      unique(:taken)
      Float :sunsettiness
      String :tweet_id
      unique(:tweet_id)
      Boolean :ground_truth_manual_sunsettiness
      String :filename
      unique(:filename)
    end
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

class Photograph  < Sequel::Model

end