class AddTimestampsToCommandAttempts < ActiveRecord::Migration[8.1]
  def change
    add_timestamps :command_attempts, null: true
  end
end
