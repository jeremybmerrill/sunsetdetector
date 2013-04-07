Sequel.migration do
  up do
    create_table :photographs do
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

  down do
    drop_table(:photographs)
  end
end
