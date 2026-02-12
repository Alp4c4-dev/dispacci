class User < ApplicationRecord
  has_secure_password

  has_many :donations, dependent: :destroy
  has_many :unlocked_commands, dependent: :destroy
  has_many :user_unlocks, dependent: :destroy
  has_many :unlockables, through: :user_unlocks
  has_many :word_definitions, dependent: :destroy
  has_many :game_sessions, dependent: :destroy

  validates :username, presence: true, uniqueness: true

  def stats
    {
      donation_time: format_donation_time,
      data_destroyed: (games.sessions.sum(score) / 1024.0).round(2), # Esempio: 1 punto = 1KB
      definitions_given: word_definitions.count,
      commands_unlocked: unlocked_commands.count
    }
  end

  private

  def format_donation_time
    total_seconds = donations.sum(:seconds) || 0
    minutes = total_seconds / 60
    seconds = total_seconds % 60
    "#{minutes} minut#{minutes == 1 ? "o" : "i"} e #{seconds} second#{seconds == 1 ? "o" : "i"}"
  end
end
