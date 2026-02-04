# frozen_string_literal: true

require "test_helper"

class SignupFlowTest < ActionDispatch::IntegrationTest
  test "create action redirects to Stripe checkout" do
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .to_return(
        status: 200,
        body: {
          id: "cs_test_integration_123",
          url: "https://checkout.stripe.com/test"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    post signup_path, params: {
      account_name: "Integration Test Group",
      agency_name: "Integration Test Agency",
      plan: "pilot",
      interval: "monthly"
    }

    assert_redirected_to "https://checkout.stripe.com/test"
  end

  test "success action displays checkout session data" do
    stub_request(:get, "https://api.stripe.com/v1/checkout/sessions/cs_test_success_123")
      .to_return(
        status: 200,
        body: {
          id: "cs_test_success_123",
          customer: "cus_test_success",
          subscription: "sub_test_success",
          metadata: {
            account_name: "Success Test Group",
            agency_name: "Success Test Agency",
            plan_tier: "starter"
          },
          custom_fields: [
            { key: "first_name", text: { value: "Success" } },
            { key: "last_name", text: { value: "Test" } }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.stripe.com/v1/customers/cus_test_success")
      .to_return(
        status: 200,
        body: { id: "cus_test_success", email: "success@testagency.com" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get signup_success_path(session_id: "cs_test_success_123")

    assert_response :success
    assert_select "h2", "Welcome to CoverText!"
    assert_select "form[action=?]", signup_complete_path
  end

  test "complete action creates Account, Agency, and User with correct relationships" do
    stub_request(:get, "https://api.stripe.com/v1/checkout/sessions/cs_test_complete_123")
      .to_return(
        status: 200,
        body: {
          id: "cs_test_complete_123",
          customer: "cus_test_complete",
          subscription: "sub_test_complete",
          metadata: {
            account_name: "Complete Test Group",
            agency_name: "Complete Test Agency",
            plan_tier: "professional"
          },
          custom_fields: [
            { key: "first_name", text: { value: "Complete" } },
            { key: "last_name", text: { value: "Test" } }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.stripe.com/v1/customers/cus_test_complete")
      .to_return(
        status: 200,
        body: { id: "cus_test_complete", email: "complete@testagency.com" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_difference [ "Account.count", "Agency.count", "User.count" ], 1 do
      post signup_complete_path, params: {
        session_id: "cs_test_complete_123",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
    end

    account = Account.last
    agency = Agency.last
    user = User.last

    # Verify Account
    assert_equal "Complete Test Group", account.name
    assert_equal "cus_test_complete", account.stripe_customer_id
    assert_equal "sub_test_complete", account.stripe_subscription_id
    assert_equal "active", account.subscription_status
    assert_equal "professional", account.plan_tier

    # Verify Agency
    assert_equal "Complete Test Agency", agency.name
    assert_equal account, agency.account
    assert agency.active?
    assert_equal false, agency.live_enabled

    # Verify User
    assert_equal "Complete", user.first_name
    assert_equal "Test", user.last_name
    assert_equal "complete@testagency.com", user.email
    assert_equal "owner", user.role
    assert_equal account, user.account
    assert user.owner?

    # Verify user is logged in and redirected
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
    # Step 1: Fill out signup form and get redirected to Stripe
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
      account_name: "Complete Flow Group",
      agency_name: "Complete Flow Agency",
      plan: "starter",
      interval: "monthly"
    }

    assert_redirected_to "https://checkout.stripe.com/complete"

    # Step 2: Return from Stripe and see password form
    stub_request(:get, "https://api.stripe.com/v1/checkout/sessions/cs_complete_flow_123")
      .to_return(
        status: 200,
        body: {
          id: "cs_complete_flow_123",
          customer: "cus_complete_flow",
          subscription: "sub_complete_flow",
          metadata: {
            account_name: "Complete Flow Group",
            agency_name: "Complete Flow Agency",
            plan_tier: "starter"
          },
          custom_fields: [
            { key: "first_name", text: { value: "Complete" } },
            { key: "last_name", text: { value: "Flow" } }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.stripe.com/v1/customers/cus_complete_flow")
      .to_return(
        status: 200,
        body: { id: "cus_complete_flow", email: "complete@flowagency.com" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get signup_success_path(session_id: "cs_complete_flow_123")
    assert_response :success

    # Step 3: Submit password and complete registration
    assert_difference [ "Account.count", "Agency.count", "User.count" ], 1 do
      post signup_complete_path, params: {
        session_id: "cs_complete_flow_123",
        password: "securepassword123",
        password_confirmation: "securepassword123"
      }
    end

    account = Account.last
    agency = Agency.last
    user = User.last

    # Verify Account
    assert_equal "Complete Flow Group", account.name
    assert_equal "cus_complete_flow", account.stripe_customer_id
    assert_equal "sub_complete_flow", account.stripe_subscription_id
    assert_equal "active", account.subscription_status
    assert_equal "starter", account.plan_tier
    assert account.subscription_active?

    # Verify Agency
    assert_equal "Complete Flow Agency", agency.name
    assert_equal account, agency.account
    assert agency.active?
    assert_equal false, agency.live_enabled

    # Verify User
    assert_equal "Complete", user.first_name
    assert_equal "Flow", user.last_name
    assert_equal "complete@flowagency.com", user.email
    assert_equal account, user.account
    assert_equal "owner", user.role
    assert user.owner?

    # Verify logged in and redirected
    assert_equal user.id, session[:user_id]
    assert_redirected_to admin_requests_path
  end
end
