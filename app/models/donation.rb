class Donation < ApplicationRecord
  belongs_to :user
  belongs_to :user_session, optional: true

  validates :seconds, numericality: { only_integer: true, greater_than: 0 }
end
