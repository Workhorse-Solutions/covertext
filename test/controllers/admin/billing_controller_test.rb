require "test_helper"

module Admin
  class BillingControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:john_owner)
      @agency = agencies(:reliable)
      @account = @user.account
      sign_in(@user)
    end

    test "requires authentication" do
      sign_out
      get admin_billing_path
      assert_redirected_to login_path
    end

    test "shows billing page for authenticated user" do
      get admin_billing_path
      assert_response :success
    end

    test "displays subscription status" do
      @account.update!(
        subscription_status: "active",
        plan_name: "pilot"
      )

      get admin_billing_path
      assert_select ".badge", text: /Active/
      assert_select "p", text: /Pilot/
    end

    test "shows warning when no subscription exists" do
      @account.update!(stripe_customer_id: nil)

      get admin_billing_path
      assert_match /No active subscription/, response.body
    end

    test "shows live status banner" do
      @account.update!(subscription_status: "active")

      get admin_billing_path
      assert_match /not yet live/, response.body
    end

    test "creates Stripe portal session when customer exists" do
      @account.update!(stripe_customer_id: "cus_test_123")

      # Mock Stripe Billing Portal Session creation
      stub_request(:post, "https://api.stripe.com/v1/billing_portal/sessions")
        .to_return(
          status: 200,
          body: {
            id: "bps_test_123",
            url: "https://billing.stripe.com/session/test"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      get admin_billing_path
      assert_response :success
      assert_match /billing.stripe.com/, response.body
    end
  end
end
