class User < ApplicationRecord
  has_secure_password

  has_many :donations, dependent: :destroy
  has_many :unlocked_commands, dependent: :destroy

  validates :username, presence: true, uniqueness: true
end
