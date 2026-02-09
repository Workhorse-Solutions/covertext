ENV["RAILS_ENV"] ||= "test"

# Set test credentials before loading environment
ENV["STRIPE_SECRET_KEY"] ||= "sk_test_mock_key_for_testing"
ENV["STRIPE_PUBLISHABLE_KEY"] ||= "pk_test_mock_key_for_testing"
ENV["TELNYX_API_KEY"] ||= "test_telnyx_api_key"

require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "minitest/mock"

# Configure WebMock
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Disable parallel tests due to WebMock stub timing issues
    # parallelize(workers: :number_of_processors)
    parallelize(workers: 1)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup do
      # Ensure Telnyx API key is always available (guards against test pollution)
      ENV["TELNYX_API_KEY"] ||= "test_telnyx_api_key"
      # Stub Stripe API calls by default
      stub_stripe_api_calls
    end

    teardown do
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

      # Stub all Telnyx API calls (any endpoint)
      stub_request(:any, /api\.telnyx\.com/).to_return do |request|
        # Return a JSON body that matches the expected Telnyx SDK response structure
        body = {
          data: {
            id: "test_message_id_#{SecureRandom.hex(4)}",
            record_type: "message",
            direction: "outbound",
            type: "SMS",
            from: { phone_number: "+15551234567" },
            to: [ { phone_number: "+15559876543", status: "queued" } ],
            text: "Test message",
            cost: { amount: "0.0040", currency: "USD" }
          }
        }
        { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
      end
    end
  end
end
