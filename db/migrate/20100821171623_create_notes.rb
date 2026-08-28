class CreateNotes < ActiveRecord::Migration[4.2]
  def self.up
    create_table :notes do |t|
      t.string :body
      t.references :notable, :polymorphic => true 
      t.timestamps
    end
    add_index :notes, [:notable_type, :notable_id]
  end

  def self.down
    drop_table :notes
  end
end
