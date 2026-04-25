class UserSession < ApplicationRecord
  belongs_to :user
  has_many :command_attempts
  has_many :donations
  has_many :game_sessions
  has_many :word_definitions

  before_create :strip_time_from_created_at

  private

  def strip_time_from_created_at
    self.created_at = Time.current.beginning_of_day
  end
end
