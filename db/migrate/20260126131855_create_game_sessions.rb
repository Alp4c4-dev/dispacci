class CreateGameSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :game_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :game_key, null: false
      t.integer :score, null: false, default: 0
      t.datetime :started_at
      t.datetime :ended_at
      t.timestamps
    end

    add_index :game_sessions, [:user_id, :game_key]
    add_index :game_sessions, [:game_key, :score]
  end
end