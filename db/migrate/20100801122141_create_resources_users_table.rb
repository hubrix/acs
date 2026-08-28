class CreateResourcesUsersTable < ActiveRecord::Migration[4.2]
  def self.up
    create_table :resources_users, :id => false do |t|
      t.integer :resource_id, :user_id, :null => false
    end
    add_index :resources_users, [:user_id, :resource_id]
  end

  def self.down
    drop_table :permissions_users
  end
end
