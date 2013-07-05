class Vote  < Sequel::Model
  many_to_one :photograph

  #attr_accessor :text, :user, :user_id, :tweet_id, :photograph_id, :value

  def set_value
    #set the value of this vote.

    yes = self.text.match(/YES/i)
    no = self.text.match(/NO/i)
    if yes && no
      if yes.begin(0) < no.begin(0)
        no = nil
      else
        yes = nil
      end
    end
    if yes
      self.value = 1
    elsif no
      self.value = 0
    else
      self.value = nil
    end
  end
end