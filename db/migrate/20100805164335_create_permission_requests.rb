class CreatePermissionRequests < ActiveRecord::Migration[4.2]
  def self.up
    create_table :permission_requests do |t|
      t.integer :access_request_id, :permission_id, :null => false
      t.boolean :permission_granted
      t.timestamps
    end
    add_index :permission_requests, :access_request_id
  end

  def self.down
    drop_table :permission_requests
  end
end
