class CreateRequests < ActiveRecord::Migration[4.2]
  def self.up
    create_table :requests do |t|
      t.integer :user_id, :created_by_id, :null => false
      t.string :reason, :null => false, :default => 'standard'
      t.string :current_state, :null => false, :default => 'pending'
      t.datetime :completed_at

      t.timestamps
    end
    add_index :requests, :user_id
    add_index :requests, :reason
    add_index :requests, :current_state
  end

  def self.down
    drop_table :requests
  end
end
