class HintProgress < ApplicationRecord
  belongs_to :user

  validates :step_key, presence: true, uniqueness: { scope: :user_id }
end
