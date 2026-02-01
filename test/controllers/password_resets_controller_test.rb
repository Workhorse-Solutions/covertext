require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "renders password reset request form" do
    get new_password_reset_path
    assert_response :success
  end

  test "creates reset token and sends email for existing user" do
    user = users(:john_owner)

    assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
      post password_resets_path, params: { email: user.email }
    end

    user.reload
    assert_not_nil user.reset_password_token_digest
    assert_not_nil user.reset_password_sent_at
  end

  test "does not leak whether user exists" do
    assert_no_enqueued_jobs do
      post password_resets_path, params: { email: "missing@example.com" }
    end

    assert_redirected_to login_path
    follow_redirect!
    assert_select ".alert-success"
  end
end
