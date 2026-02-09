require "test_helper"

class Telnyx::TollFreeVerificationTest < ActiveSupport::TestCase
  setup do
    @verification = TelnyxTollFreeVerification.create!(
      agency: agencies(:reliable),
      telnyx_number: "+18885551234",
      status: "draft",
      payload: {
        phoneNumbers: [ { phoneNumber: "+18885551234" } ],
        businessName: "Test Agency"
      }
    )

    # Save original methods to restore in teardown
    @original_create = ::Telnyx::MessagingTollfreeVerification.method(:create)
    @original_retrieve = ::Telnyx::MessagingTollfreeVerification.method(:retrieve)
  end

  teardown do
    # Restore original methods (which are the test_helper stubs)
    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:create, @original_create)
    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:retrieve, @original_retrieve)
  end

  # --- submit! ---

  test "submit! successfully creates verification request" do
    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:create) do |payload = {}|
      OpenStruct.new(id: "test-request-id-123", verification_status: "In Progress")
    end

    result = Telnyx::TollFreeVerification.submit!(@verification)

    assert_equal "submitted", result.status
    assert_equal "test-request-id-123", result.telnyx_request_id
    assert_not_nil result.submitted_at
  end

  test "submit! handles API errors" do
    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:create) do |payload = {}|
      raise ::Telnyx::APIError.new("Invalid phone number", http_status: 422)
    end

    result = Telnyx::TollFreeVerification.submit!(@verification)

    assert_equal "draft", result.status
    assert_not_nil result.last_error
    assert_includes result.last_error, "Invalid phone number"
    assert_nil result.telnyx_request_id
  end

  test "submit! handles network errors" do
    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:create) do |payload = {}|
      raise Faraday::TimeoutError, "execution expired"
    end

    result = Telnyx::TollFreeVerification.submit!(@verification)

    assert_equal "draft", result.status
    assert_not_nil result.last_error
    assert_match(/timeout|execution expired/i, result.last_error)
  end

  test "submit! records error if API key not configured" do
    original_key = ENV["TELNYX_API_KEY"]
    original_gem_key = ::Telnyx.api_key
    ENV["TELNYX_API_KEY"] = nil
    ::Telnyx.api_key = nil

    # Temporarily override Configuration to not use test fallback
    Telnyx::TollFreeVerification.singleton_class.send(:define_method, :telnyx_api_key) do
      key = Rails.application.credentials.dig(:telnyx, :api_key) || ENV["TELNYX_API_KEY"]
      raise "Telnyx API key not configured. Please set it in Rails credentials or ENV." unless key
      key
    end

    result = Telnyx::TollFreeVerification.submit!(@verification)

    assert_not_nil result.last_error
    assert_includes result.last_error, "API key not configured"
  ensure
    ENV["TELNYX_API_KEY"] = original_key
    ::Telnyx.api_key = original_gem_key
    # Restore the module method
    Telnyx::TollFreeVerification.singleton_class.send(:remove_method, :telnyx_api_key)
  end

  # --- fetch_status! ---

  test "fetch_status! maps 'In Progress' to in_review" do
    @verification.update!(telnyx_request_id: "test-request-id")

    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:retrieve) do |id|
      OpenStruct.new(verification_status: "In Progress", reason: nil)
    end

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "in_review", result.status
    assert_not_nil result.last_status_at
  end

  test "fetch_status! maps 'Waiting For Telnyx' to in_review" do
    @verification.update!(telnyx_request_id: "test-request-id")

    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:retrieve) do |id|
      OpenStruct.new(verification_status: "Waiting For Telnyx", reason: nil)
    end

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "in_review", result.status
  end

  test "fetch_status! maps 'Waiting For Vendor' to in_review" do
    @verification.update!(telnyx_request_id: "test-request-id")

    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:retrieve) do |id|
      OpenStruct.new(verification_status: "Waiting For Vendor", reason: nil)
    end

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "in_review", result.status
  end

  test "fetch_status! maps 'Waiting For Customer' to waiting_for_customer" do
    @verification.update!(telnyx_request_id: "test-request-id")

    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:retrieve) do |id|
      OpenStruct.new(verification_status: "Waiting For Customer", reason: nil)
    end

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "waiting_for_customer", result.status
  end

  test "fetch_status! maps 'Verified' to approved" do
    @verification.update!(telnyx_request_id: "test-request-id")

    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:retrieve) do |id|
      OpenStruct.new(verification_status: "Verified", reason: nil)
    end

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "approved", result.status
  end

  test "fetch_status! maps 'Rejected' to rejected" do
    @verification.update!(telnyx_request_id: "test-request-id")

    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:retrieve) do |id|
      OpenStruct.new(verification_status: "Rejected", reason: "Invalid business information")
    end

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "rejected", result.status
    assert_equal "Invalid business information", result.last_error
  end

  test "fetch_status! stores reason in last_error when present" do
    @verification.update!(telnyx_request_id: "test-request-id")

    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:retrieve) do |id|
      OpenStruct.new(verification_status: "Waiting For Customer", reason: "Additional documentation required")
    end

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "waiting_for_customer", result.status
    assert_equal "Additional documentation required", result.last_error
  end

  test "fetch_status! handles API errors" do
    @verification.update!(telnyx_request_id: "test-request-id")

    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:retrieve) do |id|
      raise ::Telnyx::APIError.new("Verification not found", http_status: 404)
    end

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_not_nil result.last_error
    assert_includes result.last_error, "Verification not found"
  end

  test "fetch_status! handles network errors" do
    @verification.update!(telnyx_request_id: "test-request-id")

    ::Telnyx::MessagingTollfreeVerification.define_singleton_method(:retrieve) do |id|
      raise Faraday::TimeoutError, "execution expired"
    end

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_not_nil result.last_error
    assert_match(/timeout|execution expired/i, result.last_error)
  end

  test "fetch_status! handles missing telnyx_request_id" do
    @verification.update!(telnyx_request_id: nil)

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_not_nil result.last_error
    assert_includes result.last_error, "telnyx_request_id is missing"
  end
end
