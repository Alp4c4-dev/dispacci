class Unlockable < ApplicationRecord
  has_many :user_unlocks, dependent: :destroy
  has_many :users, through: :user_unlocks

  validates :key, presence: true, uniqueness: true
  validates :category, presence: true
  validates :kind, presence: true
end
