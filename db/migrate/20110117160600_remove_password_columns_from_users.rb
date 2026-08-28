class RemovePasswordColumnsFromUsers < ActiveRecord::Migration[4.2]
  def self.up
    if Rails.env.production? || Rails.env.staging?
      remove_column :users, :crypted_password
      remove_column :users, :password_salt
    end
  end

  def self.down
    if Rails.env.production? || Rails.env.staging?
      add_column :users, :crypted_password, :string
      add_column :users, :password_salt, :string
    end
  end
end
