class RemoveKpiColumnsFromTables < ActiveRecord::Migration[8.1]
  def change
    # Tabella Users: non registrare ultimo login; ultima attività
    remove_column :users, :last_login_at, :datetime
    remove_column :users, :last_activity_at, :datetime

    # Tabella sessions (user_sessions): non registrare session start; session end
    remove_column :user_sessions, :started_at, :datetime
    remove_column :user_sessions, :ended_at, :datetime

    # Tabella tentatives (command_attempts): non registriamo timestamp
    remove_column :command_attempts, :created_at, :datetime
    remove_column :command_attempts, :updated_at, :datetime

    # Tabella timer (donations): non registriamo inizio fine
    remove_column :donations, :started_at, :datetime
    remove_column :donations, :ended_at, :datetime

    # Tabella breakout (game_sessions): non registriamo inizio fine
    remove_column :game_sessions, :started_at, :datetime
    remove_column :game_sessions, :ended_at, :datetime

    # Tabella unlocks (user_unlocks): non registriamo timestamp
    remove_column :user_unlocks, :created_at, :datetime
    remove_column :user_unlocks, :updated_at, :datetime
  end
end
