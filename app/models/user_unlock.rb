class UserUnlock < ApplicationRecord
  belongs_to :user
  belongs_to :unlockable
end
