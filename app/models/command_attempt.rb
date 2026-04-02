class CommandAttempt < ApplicationRecord
  belongs_to :user
  belongs_to :user_session
end
