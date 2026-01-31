require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "signup page is publicly accessible" do
    get signup_path
    assert_response :success
  end

  test "signup form has required fields" do
    get signup_path
    assert_select "input[name=?]", "agency[name]"
    assert_select "input[name=?]", "agency[phone_sms]"
    assert_select "input[name=?]", "user_first_name"
    assert_select "input[name=?]", "user_last_name"
    assert_select "input[name=?]", "user_email"
    assert_select "input[name=?]", "user_password"
  end

  test "creates agency with Stripe checkout redirect" do
    # Mock Stripe Checkout Session creation
    stub_request(:post, "https://api.stripe.com/v1/checkout/sessions")
      .to_return(
        status: 200,
        body: {
          id: "cs_test_123",
          url: "https://checkout.stripe.com/test",
          customer: "cus_test_123",
          subscription: "sub_test_123"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_difference "Agency.count", 1 do
      assert_difference "User.count", 1 do
        post signup_path, params: {
          agency: {
            name: "New Agency",
            phone_sms: "+15551112222"
          },
          user_first_name: "John",
          user_last_name: "Doe",
          user_email: "john@newagency.com",
          user_password: "password123",
          plan: "pilot"
        }
      end
    end

    agency = Agency.last
    assert_equal "New Agency", agency.name
    assert_equal false, agency.live_enabled

    user = User.last
    assert_equal "John", user.first_name
    assert_equal "Doe", user.last_name
    assert_equal "john@newagency.com", user.email
    assert_equal agency, user.agency

    assert_redirected_to "https://checkout.stripe.com/test"
  end

  test "validation errors prevent agency creation" do
    assert_no_difference "Agency.count" do
      post signup_path, params: {
        agency: {
          name: "",
          phone_sms: ""
        },
        user_first_name: "Jane",
        user_last_name: "Doe",
        user_email: "jane@test.com",
        user_password: "password123"
      }
    end

    assert_response :unprocessable_entity
  end
end
