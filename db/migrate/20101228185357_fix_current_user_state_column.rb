class FixCurrentUserStateColumn < ActiveRecord::Migration[4.2]
  def self.up
    change_column :users, :current_state, :string, :default => 'passive'
  end

  def self.down
  end
end
