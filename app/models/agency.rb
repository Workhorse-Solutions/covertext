class Agency < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :clients, dependent: :destroy
  has_many :conversation_sessions, dependent: :destroy
  has_many :requests, dependent: :destroy
  has_many :message_logs, dependent: :destroy
  has_many :audit_events, dependent: :destroy
  has_many :sms_opt_outs, dependent: :destroy

  validates :name, presence: true
  validates :phone_sms, presence: true, uniqueness: true
  validates :stripe_customer_id, uniqueness: true, allow_nil: true
  validates :stripe_subscription_id, uniqueness: true, allow_nil: true
  validates :subscription_status, inclusion: { in: %w[active canceled incomplete incomplete_expired past_due trialing unpaid paused] }, allow_nil: true

  # Subscription status checks
  def subscription_active?
    subscription_status == "active"
  end

  def can_go_live?
    subscription_active? && live_enabled?
  end
end
