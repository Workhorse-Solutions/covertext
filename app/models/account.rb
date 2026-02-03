class Account < ApplicationRecord
  GRACE_PERIOD_DAYS = 14

  enum :plan_tier, { starter: "starter", professional: "professional", enterprise: "enterprise" }, default: :starter

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
    (subscription_active? || in_grace_period?) && has_active_agency?
  end

  def owner
    users.find_by(role: "owner")
  end

  def in_grace_period?
    return false unless subscription_status == "canceled"
    return false if subscription_ends_at.nil?

    subscription_ends_at > Time.current && subscription_ends_at <= GRACE_PERIOD_DAYS.days.from_now
  end

  def read_only?
    in_grace_period?
  end

  def days_until_lockout
    return nil unless in_grace_period?

    ((subscription_ends_at - Time.current) / 1.day).ceil
  end
end
