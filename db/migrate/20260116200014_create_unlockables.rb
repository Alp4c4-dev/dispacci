class CreateUnlockables < ActiveRecord::Migration[8.1]
  def change
    create_table :unlockables do |t|
      t.string :key, null: false
      t.string :category, null: false
      t.string :kind, null: false
      t.text :payload

      t.timestamps
    end

    add_index :unlockables, :key, unique: true
  end
end
