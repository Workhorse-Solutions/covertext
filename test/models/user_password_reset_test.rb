require "test_helper"

class UserPasswordResetTest < ActiveSupport::TestCase
  test "generates and validates password reset tokens" do
    user = users(:john_admin)

    token = user.generate_password_reset_token!
    assert user.password_reset_token_valid?(token)
  end

  test "rejects expired reset token" do
    user = users(:john_admin)
    token = user.generate_password_reset_token!

    user.update!(reset_password_sent_at: 3.hours.ago)
    assert_not user.password_reset_token_valid?(token)
  end
end
