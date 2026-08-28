class ChangeRolesToHasAndBelongsToMany < ActiveRecord::Migration[4.2]
  def self.up
    
    create_table :roles_users, :id => false do |t|
      t.integer :role_id, :user_id, :null => false
    end
    add_index :roles_users, [:user_id, :role_id]
    User.reset_column_information
    Role.reset_column_information
    User.all.each do |user|
      role = Role.find(user.role_id)
      user.roles << role
    end
    remove_column :users, :role_id
  end

  def self.down
    add_column :users, :role_id, :integer, :null => false
    drop_table :roles_users
  end
end
