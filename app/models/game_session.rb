class GameSession < ApplicationRecord
  belongs_to :user
  belongs_to :user_session, optional: true
end
