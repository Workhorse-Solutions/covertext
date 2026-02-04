require "test_helper"

class Forms::RegistrationTest < ActiveSupport::TestCase
  def mock_checkout_session(attributes = {})
    defaults = {
      id: "cs_test_123",
      customer: "cus_test_123",
      subscription: "sub_test_123",
      metadata: OpenStruct.new(
        account_name: "Test Account",
        agency_name: "Test Agency",
        plan_tier: "starter"
      ),
      custom_fields: [
        OpenStruct.new(key: "first_name", text: OpenStruct.new(value: "John")),
        OpenStruct.new(key: "last_name", text: OpenStruct.new(value: "Doe"))
      ]
    }
    OpenStruct.new(defaults.merge(attributes))
  end

  test "extracts data from Stripe checkout session" do
    stub_request(:get, "https://api.stripe.com/v1/customers/cus_test_123")
      .to_return(
        status: 200,
        body: { id: "cus_test_123", email: "test@example.com" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    checkout_session = mock_checkout_session

    form = Forms::Registration.new(
      checkout_session: checkout_session,
      password_params: { password: "password123", password_confirmation: "password123" }
    )

    assert_equal "Test Account", form.account_name
    assert_equal "Test Agency", form.agency_name
    assert_equal "John", form.first_name
    assert_equal "Doe", form.last_name
    assert_equal "test@example.com", form.email
    assert_equal "password123", form.password
  end

  test "validates email uniqueness" do
    # Stub with existing user's email
    stub_request(:get, "https://api.stripe.com/v1/customers/cus_test_456")
      .to_return(
        status: 200,
        body: { id: "cus_test_456", email: users(:john_owner).email }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    checkout_session = mock_checkout_session(customer: "cus_test_456")

    form = Forms::Registration.new(
      checkout_session: checkout_session,
      password_params: { password: "password123", password_confirmation: "password123" }
    )

    assert_not form.valid?
    assert_includes form.errors[:email], "has already been taken"
  end

  test "validates password minimum length" do
    stub_request(:get, "https://api.stripe.com/v1/customers/cus_test_123")
      .to_return(
        status: 200,
        body: { id: "cus_test_123", email: "test@example.com" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    checkout_session = mock_checkout_session

    form = Forms::Registration.new(
      checkout_session: checkout_session,
      password_params: { password: "short", password_confirmation: "short" }
    )

    assert_not form.valid?
    assert_includes form.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "validates password confirmation match" do
    stub_request(:get, "https://api.stripe.com/v1/customers/cus_test_123")
      .to_return(
        status: 200,
        body: { id: "cus_test_123", email: "test@example.com" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    checkout_session = mock_checkout_session

    form = Forms::Registration.new(
      checkout_session: checkout_session,
      password_params: { password: "password123", password_confirmation: "different" }
    )

    assert_not form.valid?
    assert_includes form.errors[:password_confirmation], "doesn't match password"
  end

  test "save creates Account, Agency, and User from Stripe data" do
    stub_request(:get, "https://api.stripe.com/v1/customers/cus_new_123")
      .to_return(
        status: 200,
        body: { id: "cus_new_123", email: "new@example.com" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    checkout_session = mock_checkout_session(
      customer: "cus_new_123",
      subscription: "sub_new_123",
      metadata: OpenStruct.new(
        account_name: "New Test Account",
        agency_name: "New Test Agency",
        plan_tier: "professional"
      )
    )

    form = Forms::Registration.new(
      checkout_session: checkout_session,
      password_params: { password: "securepass123", password_confirmation: "securepass123" }
    )

    assert_difference [ "Account.count", "Agency.count", "User.count" ], 1 do
      assert form.save
    end

    # Verify Account
    assert form.account.persisted?
    assert_equal "New Test Account", form.account.name
    assert_equal "professional", form.account.plan_tier
    assert_equal "cus_new_123", form.account.stripe_customer_id
    assert_equal "sub_new_123", form.account.stripe_subscription_id
    assert_equal "active", form.account.subscription_status

    # Verify Agency
    assert form.agency.persisted?
    assert_equal "New Test Agency", form.agency.name
    assert_nil form.agency.phone_sms
    assert form.agency.active?
    assert_equal false, form.agency.live_enabled
    assert_equal form.account, form.agency.account

    # Verify User
    assert form.user.persisted?
    assert_equal "John", form.user.first_name
    assert_equal "Doe", form.user.last_name
    assert_equal "new@example.com", form.user.email
    assert_equal "owner", form.user.role
    assert_equal form.account, form.user.account
  end

  test "save returns false when validation fails" do
    stub_request(:get, "https://api.stripe.com/v1/customers/cus_test_123")
      .to_return(
        status: 200,
        body: { id: "cus_test_123", email: "test@example.com" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    checkout_session = mock_checkout_session

    form = Forms::Registration.new(
      checkout_session: checkout_session,
      password_params: { password: "short", password_confirmation: "short" }
    )

    assert_not form.save
    assert form.errors.any?
  end

  test "password validation is skipped when created for display only" do
    # Create form without checkout_session for display purposes (success view)
    form = Forms::Registration.new(
      account_name: "Display Account",
      agency_name: "Display Agency",
      first_name: "Jane",
      last_name: "Smith",
      email: "display@example.com"
    )

    # Should be valid even without password since password_required? returns false
    assert form.valid?
  end
end
