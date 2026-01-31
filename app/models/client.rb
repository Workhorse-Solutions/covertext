class Client < ApplicationRecord
  belongs_to :agency
  has_many :policies, dependent: :destroy
  has_many :requests

  validates :phone_mobile, presence: true, uniqueness: { scope: :agency_id }
end
