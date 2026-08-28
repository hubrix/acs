class AddCompletedByToAccessRequests < ActiveRecord::Migration[4.2]
  def self.up
    add_column :access_requests, :completed_by_id, :integer
  end

  def self.down
    remove_column :access_requests, :completed_by_id
  end
end
