class AddResourceGroupIdToResources < ActiveRecord::Migration[4.2]
  def self.up
    add_column :resources, :resource_group_id, :integer #, :null => false
  end

  def self.down
    remove_column :resources, :resource_group_id
  end
end
