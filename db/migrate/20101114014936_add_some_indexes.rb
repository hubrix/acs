class AddSomeIndexes < ActiveRecord::Migration[4.2]
  def self.up
    add_index :resources, :resource_group_id
    add_index :resources_users, [:resource_id, :user_id]
    add_index :permissions_users, [:permission_id, :user_id]
    add_index :permission_types, :resource_group_id
  end

  def self.down
  end
end
