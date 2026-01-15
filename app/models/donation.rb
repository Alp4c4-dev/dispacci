class Donation < ApplicationRecord
  belongs_to :user

  validates :seconds, numericality: { only_integer: true, greater_than: 0 }
end
