class CreateDonations < ActiveRecord::Migration[8.1]
  def change
    create_table :donations do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :seconds
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end
end
