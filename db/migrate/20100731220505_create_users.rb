class CreateUsers < ActiveRecord::Migration[4.2]
  def self.up
    create_table :users do |t|
      t.string :first_name, :last_name, :limit => 40
      t.string :login, :limit => 40, :default => '', :null => true
      t.string :email, :limit => 100, :null => false
      t.string :crypted_password, :password_salt
      t.string :perishable_token, :limit => 64
      t.datetime :activated_at
      t.string :persistence_token
      t.string :current_state, :null => false, :default => 'pending'
      t.datetime :deleted_at
      t.integer :login_count, :null => false, :default => 0
      t.integer :failed_login_count, :null => false, :default => 0
      t.string :current_login_ip
      t.string :last_login_ip
      t.datetime :last_request_at, :current_login_at, :last_login_at
      t.integer :role_id, :null => false
      t.timestamps
    end
    add_index :users, :email, :unique => true
  end

  def self.down
    drop_table :users
  end
end
