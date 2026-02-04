ENV["RAILS_ENV"] ||= "test"

# Set test credentials before loading environment
ENV["TWILIO_ACCOUNT_SID"] ||= "test_account_sid"
ENV["TWILIO_AUTH_TOKEN"] ||= "test_auth_token"
ENV["STRIPE_SECRET_KEY"] ||= "sk_test_mock_key_for_testing"
ENV["STRIPE_PUBLISHABLE_KEY"] ||= "pk_test_mock_key_for_testing"

require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# Configure WebMock
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Disable parallel tests due to WebMock stub timing issues
    # parallelize(workers: :number_of_processors)
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Reset Twilio client before each test to ensure clean stubbed state
    setup do
      TwilioClient.reset!
      # Stub Stripe API calls by default
      stub_stripe_api_calls
    end

    # Add more helper methods to be used by all tests here...
    def sign_in(user)
      post login_path, params: { email: user.email, password: "password123" }
    end

    def sign_out
      delete logout_path
    end

    private

    def stub_stripe_api_calls
      # Stub Stripe Customer retrieval (most common call in tests)
      stub_request(:get, %r{https://api\.stripe\.com/v1/customers/.*})
        .to_return(
          status: 200,
          body: { id: "cus_default", email: "default@example.com" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub all other Stripe API endpoints as fallback
      stub_request(:any, /api\.stripe\.com/).to_return(
        status: 200,
        body: { id: "stub_response" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
    end
  end
end
