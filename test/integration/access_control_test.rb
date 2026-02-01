require "test_helper"

class AccessControlTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john_owner)
    @account = accounts(:reliable_group)
    @agency = agencies(:reliable)
  end

  test "active subscription and active agency grants access" do
    @account.update!(subscription_status: "active")
    @agency.update!(active: true)
    sign_in(@user)

    get admin_requests_path
    assert_response :success, "Expected access to admin pages with active subscription and active agency"
  end

  test "canceled subscription with expired grace period denies access" do
    @account.update!(
      subscription_status: "canceled",
      subscription_ends_at: 1.day.ago
    )
    @agency.update!(active: true)
    sign_in(@user)

    get admin_requests_path
    assert_redirected_to admin_billing_path
    assert_match /subscription is inactive/, flash[:alert]
  end

  test "active subscription with no active agencies redirects to billing" do
    @account.update!(subscription_status: "active")
    @account.agencies.update_all(active: false)
    sign_in(@user)

    get admin_requests_path
    assert_redirected_to admin_billing_path
    assert_match /No active agencies/, flash[:alert]
  end

  test "grace period allows access with warning banner" do
    @account.update!(
      subscription_status: "canceled",
      subscription_ends_at: 7.days.from_now
    )
    @agency.update!(active: true)
    sign_in(@user)

    get admin_requests_path
    assert_response :success, "Expected access during grace period"

    # Check warning banner is displayed
    assert_select "#grace-period-banner"
    assert_select "#grace-period-banner", /Subscription Expiring/
    assert_select "#grace-period-banner", /7 days/
  end

  test "grace period at 1 day remaining shows correct message" do
    @account.update!(
      subscription_status: "canceled",
      subscription_ends_at: 1.day.from_now
    )
    @agency.update!(active: true)
    sign_in(@user)

    get admin_requests_path
    assert_response :success

    assert_select "#grace-period-banner", /1 day/
  end

  test "access denied when subscription canceled with nil subscription_ends_at" do
    @account.update!(
      subscription_status: "canceled",
      subscription_ends_at: nil
    )
    @agency.update!(active: true)
    sign_in(@user)

    get admin_requests_path
    assert_redirected_to admin_billing_path
    assert_match /subscription is inactive/, flash[:alert]
  end

  test "billing page always accessible even when subscription inactive" do
    @account.update!(subscription_status: "canceled", subscription_ends_at: nil)
    sign_in(@user)

    get admin_billing_path
    assert_response :success, "Billing page should always be accessible"
  end

  test "past_due subscription denies access" do
    @account.update!(subscription_status: "past_due")
    @agency.update!(active: true)
    sign_in(@user)

    get admin_requests_path
    assert_redirected_to admin_billing_path
    assert_match /subscription is inactive/, flash[:alert]
  end
end
