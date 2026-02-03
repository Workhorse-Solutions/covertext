# frozen_string_literal: true

require "test_helper"

class SignupFlowTest < ActionDispatch::IntegrationTest
  test "successful signup creates Account, Agency, and User with correct relationships" do
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .to_return(
        status: 200,
        body: {
          id: "cs_test_integration_123",
          url: "https://checkout.stripe.com/test"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_difference [ "Account.count", "Agency.count", "User.count" ], 1 do
      post signup_path, params: {
        agency: {
          name: "Integration Test Agency",
          phone_sms: "+15559998888"
        },
        user_first_name: "Integration",
        user_last_name: "Test",
        user_email: "integration@testagency.com",
        user_password: "securepassword123",
        plan: "pilot"
      }
    end

    account = Account.last
    agency = Agency.last
    user = User.last

    assert_equal "Integration Test Agency", account.name
    assert_equal account, agency.account
    assert_equal account, user.account
    assert_redirected_to "https://checkout.stripe.com/test"
  end

  test "user has owner role after signup" do
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .to_return(
        status: 200,
        body: {
          id: "cs_test_owner_123",
          url: "https://checkout.stripe.com/test"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    post signup_path, params: {
      agency: {
        name: "Owner Test Agency",
        phone_sms: "+15557776666"
      },
      user_first_name: "Owner",
      user_last_name: "User",
      user_email: "owner@testagency.com",
      user_password: "securepassword123",
      plan: "pilot"
    }

    user = User.find_by(email: "owner@testagency.com")

    assert_not_nil user
    assert_equal "owner", user.role
    assert user.owner?
  end

  test "agency is active after signup" do
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .to_return(
        status: 200,
        body: {
          id: "cs_test_active_123",
          url: "https://checkout.stripe.com/test"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    post signup_path, params: {
      agency: {
        name: "Active Test Agency",
        phone_sms: "+15554443333"
      },
      user_first_name: "Active",
      user_last_name: "User",
      user_email: "active@testagency.com",
      user_password: "securepassword123",
      plan: "pilot"
    }

    agency = Agency.find_by(name: "Active Test Agency")

    assert_not_nil agency
    assert agency.active?
    assert_equal false, agency.live_enabled
  end

  test "Stripe checkout success updates Account subscription and logs in user" do
    account = Account.create!(name: "Checkout Test Account")
    agency = account.agencies.create!(
      name: "Checkout Test Agency",
      phone_sms: "+15552221111",
      active: true,
      live_enabled: false
    )
    user = account.users.create!(
      first_name: "Checkout",
      last_name: "User",
      email: "checkout@testagency.com",
      password: "securepassword123",
      role: "owner"
    )

    stub_request(:get, %r{https://api\.stripe\.com/v1/checkout/sessions/.*})
      .to_return(
        status: 200,
        body: {
          id: "cs_test_checkout_456",
          customer: "cus_checkout_test",
          subscription: "sub_checkout_test",
          metadata: {
            account_id: account.id.to_s,
            agency_id: agency.id.to_s,
            user_id: user.id.to_s,
            plan_tier: "starter"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get signup_success_path(session_id: "cs_test_checkout_456", plan: "starter")

    account.reload

    assert_equal "cus_checkout_test", account.stripe_customer_id
    assert_equal "sub_checkout_test", account.stripe_subscription_id
    assert_equal "active", account.subscription_status
    assert account.starter?

    assert_equal user.id, session[:user_id]
    assert_redirected_to admin_requests_path
  end

  test "Stripe webhook updates Account subscription status" do
    account = Account.create!(
      name: "Webhook Test Account",
      stripe_subscription_id: "sub_webhook_test"
    )
    account.agencies.create!(
      name: "Webhook Test Agency",
      phone_sms: "+15551110000",
      active: true,
      live_enabled: false
    )
    account.users.create!(
      first_name: "Webhook",
      last_name: "User",
      email: "webhook@testagency.com",
      password: "securepassword123",
      role: "owner"
    )

    controller = Webhooks::StripeWebhooksController.new

    subscription = OpenStruct.new(
      id: "sub_webhook_test",
      status: "active",
      metadata: OpenStruct.new(account_id: account.id.to_s, plan_tier: "professional"),
      cancel_at_period_end: false,
      items: OpenStruct.new(
        data: [ OpenStruct.new(price: OpenStruct.new(id: "price_professional_test")) ]
      )
    )

    controller.send(:handle_subscription_update, subscription)

    account.reload

    assert_equal "active", account.subscription_status
    assert account.professional?
  end

  test "complete signup flow from form to active subscription" do
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .to_return(
        status: 200,
        body: {
          id: "cs_complete_flow_123",
          url: "https://checkout.stripe.com/complete"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get signup_path
    assert_response :success
    assert_select "form[action=?]", signup_path

    post signup_path, params: {
      agency: {
        name: "Complete Flow Agency",
        phone_sms: "+15550009999"
      },
      user_first_name: "Complete",
      user_last_name: "Flow",
      user_email: "complete@flowagency.com",
      user_password: "securepassword123",
      plan: "starter"
    }

    assert_redirected_to "https://checkout.stripe.com/complete"

    account = Account.last
    agency = Agency.last
    user = User.last

    stub_request(:get, %r{https://api\.stripe\.com/v1/checkout/sessions/.*})
      .to_return(
        status: 200,
        body: {
          id: "cs_complete_flow_123",
          customer: "cus_complete_flow",
          subscription: "sub_complete_flow",
          metadata: {
            account_id: account.id.to_s,
            agency_id: agency.id.to_s,
            user_id: user.id.to_s,
            plan_tier: "starter"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get signup_success_path(session_id: "cs_complete_flow_123", plan: "starter")

    account.reload

    assert_equal "Complete Flow Agency", account.name
    assert_equal "cus_complete_flow", account.stripe_customer_id
    assert_equal "sub_complete_flow", account.stripe_subscription_id
    assert_equal "active", account.subscription_status
    assert account.subscription_active?

    assert_equal account, agency.account
    assert agency.active?

    assert_equal account, user.account
    assert_equal "owner", user.role
    assert user.owner?

    assert_equal user.id, session[:user_id]
    assert_redirected_to admin_requests_path
  end
end
