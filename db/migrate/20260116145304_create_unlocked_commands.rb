class CreateUnlockedCommands < ActiveRecord::Migration[8.1]
  def change
    create_table :unlocked_commands do |t|
      t.belongs_to :user, null: false, foreign_key: true
      t.string :command, null: false

      t.timestamps
    end

    add_index :unlocked_commands, [ :user_id, :command ], unique: true
  end
end
