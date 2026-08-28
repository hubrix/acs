class CreateJobs < ActiveRecord::Migration[4.2]
  def self.up
    create_table :jobs do |t|
      t.integer :department_id, :null => false
      t.string :name, :null => false
      t.timestamps
    end
    add_index :jobs, [:department_id, :name]
    add_index :jobs, :name
  end

  def self.down
    drop_table :jobs
  end
end
