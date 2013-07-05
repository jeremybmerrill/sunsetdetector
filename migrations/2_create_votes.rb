Sequel.migration do
  up do
    create_table :votes do
      primary_key :id
      Integer :photograph_id
      String :tweet_id
      unique(:tweet_id)
      Integer :value
      String :voter #twitter user.
      String :voter_id #twitter user's id (don't need a model for this, atm)
    end
  end
  down do
    drop_table(:votes)

  end
end
