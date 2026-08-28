class AddHrColumnsToRequests < ActiveRecord::Migration[4.2]
  def self.up
    add_column :permission_requests, :approved_by_hr, :boolean
    add_column :permission_requests, :approved_by_hr_at, :datetime
    add_column :access_requests, :hr_id, :integer
    add_column :users, :terminated_by_id, :integer
  end

  def self.down
    remove_column :permission_requests, :approved_by_hr
    remove_column :permission_requests, :approved_by_hr_at
    remove_column :access_requests, :hr_id
    remove_column :users, :terminated_by_id
  end
end
