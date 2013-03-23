class CreateAuths < ActiveRecord::Migration
  def change
    create_table :auths do |t|
      t.integer :user_id
      t.string :email
      t.string :access_key
      t.string :secret_key

      t.timestamps
    end
  end
end
