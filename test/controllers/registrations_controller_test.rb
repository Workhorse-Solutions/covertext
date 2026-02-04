require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signup page is publicly accessible" do
    get signup_path
    assert_response :success
  end

  test "signup form has required fields" do
    get signup_path
    assert_select "input[name=?]", "account_name"
    assert_select "input[name=?]", "agency_name"
    assert_select "input[name=?]", "plan"
    assert_select "input[name=?]", "interval"
  end

  test "create redirects to Stripe checkout" do
    # Mock Stripe Checkout Session creation
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .to_return(
        status: 200,
        body: {
          id: "cs_test_123",
          url: "https://checkout.stripe.com/c/pay/cs_test_123"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # No records created yet - just redirect to Stripe
    assert_no_difference [ "Account.count", "Agency.count", "User.count" ] do
      post signup_path, params: {
        account_name: "New Insurance Group",
        agency_name: "New Agency",
        plan: "starter",
        interval: "yearly"
      }
    end

    assert_redirected_to "https://checkout.stripe.com/c/pay/cs_test_123"
  end

  test "create validates required fields" do
    assert_no_difference "Agency.count" do
      post signup_path, params: {
        account_name: "",
        agency_name: "",
        plan: "starter"
      }
    end

    assert_response :unprocessable_entity
    assert_select ".alert-error", text: /Account and Agency names are required/
  end

  test "success displays data from Stripe checkout session" do
    # Mock Stripe API calls
    stub_request(:get, "https://api.stripe.com/v1/checkout/sessions/cs_test_123")
      .to_return(
        status: 200,
        body: {
          id: "cs_test_123",
          customer: "cus_test_123",
          subscription: "sub_test_123",
          metadata: {
            account_name: "Test Insurance Group",
            agency_name: "Test Agency",
            plan_tier: "starter"
          },
          custom_fields: [
            { key: "first_name", text: { value: "John" } },
            { key: "last_name", text: { value: "Doe" } }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.stripe.com/v1/customers/cus_test_123")
      .to_return(
        status: 200,
        body: {
          id: "cus_test_123",
          email: "john@test.com"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get signup_success_path(session_id: "cs_test_123")

    assert_response :success
    assert_select "span", text: "Test Insurance Group"
    assert_select "span", text: "Test Agency"
    assert_select "input[value=?]", "John Doe"
    assert_select "input[value=?]", "john@test.com"
    assert_select "input[name=?]", "password"
    assert_select "input[name=?]", "password_confirmation"
  end

  test "complete creates account from Stripe checkout session" do
    # Mock Stripe API calls
    stub_request(:get, "https://api.stripe.com/v1/checkout/sessions/cs_test_456")
      .to_return(
        status: 200,
        body: {
          id: "cs_test_456",
          customer: "cus_test_456",
          subscription: "sub_test_456",
          metadata: {
            account_name: "Complete Test Group",
            agency_name: "Complete Agency",
            plan_tier: "professional"
          },
          custom_fields: [
            { key: "first_name", text: { value: "Jane" } },
            { key: "last_name", text: { value: "Smith" } }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.stripe.com/v1/customers/cus_test_456")
      .to_return(
        status: 200,
        body: {
          id: "cus_test_456",
          email: "jane@complete.com"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Records are created in complete action
    assert_difference "Account.count", 1 do
      assert_difference "Agency.count", 1 do
        assert_difference "User.count", 1 do
          post signup_complete_path, params: {
            session_id: "cs_test_456",
            password: "password123",
            password_confirmation: "password123"
          }
        end
      end
    end

    # Verify Account
    account = Account.last
    assert_equal "Complete Test Group", account.name
    assert_equal "professional", account.plan_tier
    assert_equal "cus_test_456", account.stripe_customer_id
    assert_equal "sub_test_456", account.stripe_subscription_id
    assert_equal "active", account.subscription_status

    # Verify Agency
    agency = Agency.last
    assert_equal "Complete Agency", agency.name
    assert_equal account, agency.account
    assert_equal true, agency.active
    assert_equal false, agency.live_enabled

    # Verify User
    user = User.last
    assert_equal "Jane", user.first_name
    assert_equal "Smith", user.last_name
    assert_equal "jane@complete.com", user.email
    assert_equal account, user.account
    assert_equal "owner", user.role

    # User is logged in
    assert_equal user.id, session[:user_id]

    assert_redirected_to admin_requests_path
  end

  test "complete validates password" do
    # Mock Stripe API
    stub_request(:get, "https://api.stripe.com/v1/checkout/sessions/cs_test_789")
      .to_return(
        status: 200,
        body: {
          id: "cs_test_789",
          customer: "cus_test_789",
          subscription: "sub_test_789",
          metadata: {
            account_name: "Test Group",
            agency_name: "Test Agency",
            plan_tier: "starter"
          },
          custom_fields: [
            { key: "first_name", text: { value: "Bob" } },
            { key: "last_name", text: { value: "Jones" } }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, "https://api.stripe.com/v1/customers/cus_test_789")
      .to_return(
        status: 200,
        body: {
          id: "cus_test_789",
          email: "bob@test.com"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_no_difference [ "Account.count", "User.count" ] do
      post signup_complete_path, params: {
        session_id: "cs_test_789",
        password: "short",
        password_confirmation: "short"
      }
    end

    assert_response :unprocessable_entity
  end
end
