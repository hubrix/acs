class ConvertStringBodyToText < ActiveRecord::Migration[4.2]
  def self.up
    #change_column :notes, :body, :text
  end

  def self.down
    #change_column :notes, :body, :string
  end
end
