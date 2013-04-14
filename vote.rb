class Vote  < Sequel::Model
  many_to_one :photograph

  def new(text)
    #set the value of this vote.
    self.text = text

    yes = text.match(/YES/i)
    no = text.match(/NO/i)
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