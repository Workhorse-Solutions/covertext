class Agency < ApplicationRecord
  belongs_to :account

  has_many :clients, dependent: :destroy
  has_many :conversation_sessions, dependent: :destroy
  has_many :requests, dependent: :destroy
  has_many :message_logs, dependent: :destroy
  has_many :audit_events, dependent: :destroy
  has_many :sms_opt_outs, dependent: :destroy

  validates :name, presence: true
  validates :phone_sms, uniqueness: true, allow_nil: true

  def can_go_live?
    active? && account.subscription_active? && live_enabled?
  end

  def activate!
    update!(active: true)
  end

  def deactivate!
    update!(active: false)
  end
end
