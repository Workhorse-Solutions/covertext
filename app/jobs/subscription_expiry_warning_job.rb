class SubscriptionExpiryWarningJob < ApplicationJob
  queue_as :default

  WARNING_DAYS = [ 7, 3, 1 ].freeze

  def perform
    accounts_in_grace_period.find_each do |account|
      next unless should_send_warning?(account)

      send_warning(account)
    end
  end

  private

  def accounts_in_grace_period
    Account.where(subscription_status: "canceled")
           .where.not(subscription_ends_at: nil)
           .where("subscription_ends_at > ?", Time.current)
           .where("subscription_ends_at <= ?", Account::GRACE_PERIOD_DAYS.days.from_now)
  end

  def should_send_warning?(account)
    days_remaining = account.days_until_lockout
    return false unless WARNING_DAYS.include?(days_remaining)

    last_warning = account.last_expiry_warning_sent_at
    return true if last_warning.nil?

    last_warning < 1.day.ago
  end

  def send_warning(account)
    owner = account.owner
    return unless owner

    AccountMailer.with(account: account, user: owner).subscription_expiry_warning.deliver_later
    account.update!(last_expiry_warning_sent_at: Time.current)
  end
end
