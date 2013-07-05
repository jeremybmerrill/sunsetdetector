Sequel.migration do
  up do
    add_column :votes, :text, :text
    add_column :votes, :username, String
    add_column :votes, :user_id, String
  end
  down do
    drop_column :votes, :text
    drop_column :votes, :username
    drop_column :votes, :user_id
  end
end
