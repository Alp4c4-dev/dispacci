class User < ApplicationRecord
  has_secure_password

  has_many :donations, dependent: :destroy

  validates :username, presence: true, uniqueness: true
end
