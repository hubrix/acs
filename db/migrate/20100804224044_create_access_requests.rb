class CreateAccessRequests < ActiveRecord::Migration[4.2]
  def self.up
    create_table :access_requests do |t|
      t.integer :user_id, :created_by_id, :resource_id, :null => false
      t.integer :current_worker_id
      t.string :request_action, :null => false
      t.string :current_state, :default => 'pending', :null => false
      t.timestamps
    end
    add_index :access_requests, :user_id
    add_index :access_requests, :created_by_id
    add_index :access_requests, :current_worker_id
  end

  def self.down
    drop_table :access_requests
  end
end
