class CreateUserUnlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :user_unlocks do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.belongs_to :unlockable, null: false, foreign_key: true

      t.timestamps
    end

    add_index :user_unlocks, [:user_id, :unlockable_id], unique: true
  end
end
