class UserUnlock < ApplicationRecord
  belongs_to :user
  belongs_to :unlockable

  before_create :strip_time_from_created_at

  private

  def strip_time_from_created_at
    self.created_at = Time.current.beginning_of_day
  end
end
