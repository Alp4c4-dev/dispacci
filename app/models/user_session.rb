class UserSession < ApplicationRecord
  belongs_to :user
  has_many :command_attempts
  has_many :donations
  has_many :game_sessions
  has_many :word_definitions


end
