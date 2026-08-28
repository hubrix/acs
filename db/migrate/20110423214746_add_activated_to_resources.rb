class AddActivatedToResources < ActiveRecord::Migration[4.2]
  def self.up
    add_column :permissions, :activated, :boolean, :default => true
    Permission.reset_column_information
    Permission.all.each{|perm| perm.update_attribute(:activated, true)}
  end

  def self.down
    remove_column :permissions, :activated
  end
end
