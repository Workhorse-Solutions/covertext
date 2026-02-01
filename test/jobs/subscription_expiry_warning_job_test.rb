require "test_helper"

class SubscriptionExpiryWarningJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    @account = accounts(:reliable_group)
    @owner = users(:john_owner)
  end

  test "sends warning when account has 7 days remaining" do
    set_account_in_grace_period(days_remaining: 7)

    assert_enqueued_emails 1 do
      SubscriptionExpiryWarningJob.perform_now
    end

    assert_not_nil @account.reload.last_expiry_warning_sent_at
  end

  test "sends warning when account has 3 days remaining" do
    set_account_in_grace_period(days_remaining: 3)

    assert_enqueued_emails 1 do
      SubscriptionExpiryWarningJob.perform_now
    end
  end

  test "sends warning when account has 1 day remaining" do
    set_account_in_grace_period(days_remaining: 1)

    assert_enqueued_emails 1 do
      SubscriptionExpiryWarningJob.perform_now
    end
  end

  test "does not send warning on non-warning days" do
    set_account_in_grace_period(days_remaining: 5)

    assert_no_enqueued_emails do
      SubscriptionExpiryWarningJob.perform_now
    end
  end

  test "does not send warning for active subscription" do
    @account.update!(subscription_status: "active", subscription_ends_at: nil)

    assert_no_enqueued_emails do
      SubscriptionExpiryWarningJob.perform_now
    end
  end

  test "does not send duplicate warning on same day" do
    set_account_in_grace_period(days_remaining: 7)
    @account.update!(last_expiry_warning_sent_at: 1.hour.ago)

    assert_no_enqueued_emails do
      SubscriptionExpiryWarningJob.perform_now
    end
  end

  test "sends warning if last warning was more than a day ago" do
    set_account_in_grace_period(days_remaining: 3)
    @account.update!(last_expiry_warning_sent_at: 2.days.ago)

    assert_enqueued_emails 1 do
      SubscriptionExpiryWarningJob.perform_now
    end
  end

  test "does not send warning if no owner" do
    set_account_in_grace_period(days_remaining: 7)
    @owner.update!(role: "admin")

    assert_no_enqueued_emails do
      SubscriptionExpiryWarningJob.perform_now
    end
  end

  test "does not send warning after subscription_ends_at has passed" do
    @account.update!(
      subscription_status: "canceled",
      subscription_ends_at: 1.day.ago
    )

    assert_no_enqueued_emails do
      SubscriptionExpiryWarningJob.perform_now
    end
  end

  private

  def set_account_in_grace_period(days_remaining:)
    @account.update!(
      subscription_status: "canceled",
      subscription_ends_at: days_remaining.days.from_now,
      last_expiry_warning_sent_at: nil
    )
  end
end
