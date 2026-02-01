require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john_owner)
    @account = accounts(:reliable_group)
    @agency = agencies(:reliable)
  end

  test "current_account returns user's account when logged in" do
    sign_in(@user)
    get admin_billing_path
    assert_response :success
  end

  test "require_active_subscription allows access when subscription active and agency active" do
    @account.update!(subscription_status: "active")
    @agency.update!(active: true)
    sign_in(@user)

    get admin_requests_path
    assert_response :success
  end

  test "require_active_subscription redirects to billing when subscription inactive" do
    @account.update!(subscription_status: "canceled")
    sign_in(@user)

    get admin_requests_path
    assert_redirected_to admin_billing_path
    assert_match /subscription is inactive/, flash[:alert]
  end

  test "require_active_subscription redirects when no active agencies" do
    @account.update!(subscription_status: "active")
    @account.agencies.update_all(active: false)
    sign_in(@user)

    get admin_requests_path
    assert_redirected_to admin_billing_path
    assert_match /No active agencies/, flash[:alert]
  end

  test "grace period banner appears when account is in grace period" do
    @account.update!(subscription_status: "canceled", subscription_ends_at: 7.days.from_now)
    sign_in(@user)

    get admin_billing_path
    assert_response :success
    assert_select "#grace-period-banner"
    assert_select "#grace-period-banner", /Subscription Expiring/
    assert_select "#grace-period-banner", /7 days/
  end

  test "grace period banner does not appear when subscription is active" do
    @account.update!(subscription_status: "active")
    sign_in(@user)

    get admin_billing_path
    assert_response :success
    assert_select "#grace-period-banner", false
  end

  test "grace period banner does not appear after dismissed" do
    @account.update!(subscription_status: "canceled", subscription_ends_at: 7.days.from_now)
    sign_in(@user)

    # First, banner should appear
    get admin_billing_path
    assert_select "#grace-period-banner"

    # Dismiss the banner
    post admin_dismiss_grace_period_banner_path
    assert_response :ok

    # Banner should not appear
    get admin_billing_path
    assert_select "#grace-period-banner", false
  end
end
