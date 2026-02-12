class DropUnlockedCommandsTable < ActiveRecord::Migration[8.1] 
  def change
    drop_table :unlocked_commands do |t|
      # Questo blocco serve solo se un giorno volessi annullare la cancellazione (rollback)
      t.string :command, null: false
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
  end
end