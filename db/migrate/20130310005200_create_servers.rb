class CreateServers < ActiveRecord::Migration
  def change
    create_table :servers do |t|
      t.integer :user_id
      t.string :name
      t.string :description
      t.string :schedule
      t.integer :generation
      t.string :region

      t.timestamps
    end
  end
end
