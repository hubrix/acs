class AddCompletedAtToAccessRequests < ActiveRecord::Migration[4.2]
  def self.up
    add_column :access_requests, :completed_at, :datetime
  end

  def self.down
    remove_column :access_requests, :completed_at
  end
end
