ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Ensure Twilio is stubbed in tests
ENV["TWILIO_ACCOUNT_SID"] ||= "test_account_sid"
ENV["TWILIO_AUTH_TOKEN"] ||= "test_auth_token"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Reset Twilio client before each test to ensure clean stubbed state
    setup do
      TwilioClient.reset!
    end

    # Add more helper methods to be used by all tests here...
    def sign_in(user)
      post login_path, params: { email: user.email, password: "password123" }
    end

    def sign_out
      delete logout_path
    end
  end
end
