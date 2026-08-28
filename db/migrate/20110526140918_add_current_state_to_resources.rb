class AddCurrentStateToResources < ActiveRecord::Migration[4.2]
  def self.up
    add_column :resources, :current_state, :string, :default => 'active', :null => false
  end

  def self.down
    remove_column :resources, :current_state
  end
end
