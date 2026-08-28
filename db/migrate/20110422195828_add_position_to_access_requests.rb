class AddPositionToAccessRequests < ActiveRecord::Migration[4.2]
  def self.up
    add_column :access_requests, :position, :integer
    add_index :access_requests, [:request_id, :position]
    AccessRequest.reset_column_information
    Request.reset_column_information
    Request.all.each{|r| r.order_access_requests_by_resource_name! }
  end

  def self.down
    remove_column :access_requests, :position
    remove_index :access_requests, [:request_id, :position]
  end
end
