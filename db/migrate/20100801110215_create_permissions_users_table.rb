class CreatePermissionsUsersTable < ActiveRecord::Migration[4.2]
  def self.up
    create_table :permissions_users, :id => false do |t|
      t.integer :permission_id, :user_id, :null => false
    end
    add_index :permissions_users, [:user_id, :permission_id]
  end

  def self.down
    drop_table :permissions_users
  end
end
