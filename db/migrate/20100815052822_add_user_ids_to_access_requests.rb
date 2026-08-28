class AddUserIdsToAccessRequests < ActiveRecord::Migration[4.2]
  def self.up
    add_column :access_requests, :manager_id, :integer
    add_column :access_requests, :resource_owner_id, :integer
    add_column :access_requests, :help_desk_id, :integer
  end

  def self.down
    remove_column :access_requests, :manager_id
    remove_column :access_requests, :resource_owner_id
    remove_column :access_requests, :help_desk_id
  end
end
