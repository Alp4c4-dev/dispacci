class UnlockedCommand < ApplicationRecord
  belongs_to :user

  validates :command, presence: true, uniqueness: { scope: :user_id }
end
