class Account < ApplicationRecord
  has_many :agencies, dependent: :destroy
  has_many :users, dependent: :destroy

  validates :name, presence: true
  validates :stripe_customer_id, uniqueness: true, allow_nil: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true
  validates :subscription_status, inclusion: { in: %w[active canceled incomplete incomplete_expired past_due trialing unpaid paused] }, allow_nil: true

  def subscription_active?
    subscription_status == "active"
  end

  def has_active_agency?
    agencies.exists?(active: true)
  end

  def can_access_system?
    subscription_active? && has_active_agency?
  end

  def owner
    users.find_by(role: "owner")
  end
end
