require "test_helper"

class AccountMailerTest < ActionMailer::TestCase
  test "subscription_expiry_warning" do
    account = accounts(:reliable_group)
    user = users(:john_owner)
    account.update!(
      subscription_status: "canceled",
      subscription_ends_at: 3.days.from_now
    )

    email = AccountMailer.with(account: account, user: user).subscription_expiry_warning

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ user.email ], email.to
    assert_equal "Your CoverText subscription expires in 3 days", email.subject
    assert_match account.name, email.html_part.body.to_s
    assert_match "3 days", email.html_part.body.to_s
  end
end
