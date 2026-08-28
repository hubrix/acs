class NeedMoarIndex < ActiveRecord::Migration[4.2]
  def self.up
    add_index :departments, :name
    add_index :permission_types, [:resource_group_id, :name]
    add_index :resources, [:resource_group_id, :name]
    add_index :users, :login
  end

  def self.down
  end
end
