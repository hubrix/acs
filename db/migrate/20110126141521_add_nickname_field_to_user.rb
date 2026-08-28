class AddNicknameFieldToUser < ActiveRecord::Migration[4.2]
  def self.up
    add_column :users, :nickname, :string
  end

  def self.down
    remove_column :users, :nickname
  end
end
