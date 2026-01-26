class User < ApplicationRecord
  has_secure_password

  has_many :donations, dependent: :destroy
  has_many :unlocked_commands, dependent: :destroy
  has_many :user_unlocks, dependent: :destroy
  has_many :unlockables, through: :user_unlocks
  has_many :word_definitions, dependent: :destroy
  has_many :game_sessions, dependent: :destroy

  validates :username, presence: true, uniqueness: true
end
