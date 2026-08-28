class AddForNewEmployeeToAccessRequests < ActiveRecord::Migration[4.2]
  def self.up
    add_column :access_requests, :for_new_user, :boolean, :default => false
  end

  def self.down
    remove_column :access_requests, :for_new_user
  end
end
