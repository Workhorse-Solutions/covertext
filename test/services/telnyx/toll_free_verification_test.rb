require "ostruct"
require "test_helper"
require "minitest/mock"

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

    # Save original method to restore in teardown
    @original_client = Telnyx::TollFreeVerification.method(:telnyx_client)
  end

  teardown do
    # Restore original telnyx_client method
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client, @original_client)
  end

  # --- submit! ---

  test "submit! successfully creates verification request" do
    fake_requests = Minitest::Mock.new
    fake_requests.expect(:create, OpenStruct.new(id: "test-request-id-123", verification_status: "In Progress")) { true }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

    result = Telnyx::TollFreeVerification.submit!(@verification)

    assert_equal "submitted", result.status
    assert_equal "test-request-id-123", result.telnyx_request_id
    assert_not_nil result.submitted_at
    fake_requests.verify
  end

  test "submit! handles API errors" do
    fake_requests = Object.new
    fake_requests.define_singleton_method(:create) { |*| raise StandardError, "Invalid phone number" }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

    result = Telnyx::TollFreeVerification.submit!(@verification)

    assert_equal "draft", result.status
    assert_not_nil result.last_error
    assert_includes result.last_error, "Invalid phone number"
    assert_nil result.telnyx_request_id
  end

  test "submit! handles network errors" do
    fake_requests = Object.new
    fake_requests.define_singleton_method(:create) { |*| raise Faraday::TimeoutError, "execution expired" }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

    result = Telnyx::TollFreeVerification.submit!(@verification)

    assert_equal "draft", result.status
    assert_not_nil result.last_error
    assert_match(/timeout|execution expired/i, result.last_error)
  end

  test "submit! records error if API key not configured" do
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { raise "Telnyx API key not configured. Please set it in Rails credentials or ENV." }
    result = Telnyx::TollFreeVerification.submit!(@verification)
    assert_not_nil result.last_error
    assert_includes result.last_error, "API key not configured"
  end

  # --- fetch_status! ---

  test "fetch_status! maps 'In Progress' to in_review" do
    @verification.update!(telnyx_request_id: "test-request-id")
    fake_requests = Minitest::Mock.new
    fake_requests.expect(:retrieve, OpenStruct.new(verification_status: "In Progress", reason: nil)) { true }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "in_review", result.status
    assert_not_nil result.last_status_at
    fake_requests.verify
  end

  test "fetch_status! maps 'Waiting For Telnyx' to in_review" do
    @verification.update!(telnyx_request_id: "test-request-id")
    fake_requests = Minitest::Mock.new
    fake_requests.expect(:retrieve, OpenStruct.new(verification_status: "Waiting For Telnyx", reason: nil)) { true }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "in_review", result.status
  end

  test "fetch_status! maps 'Waiting For Vendor' to in_review" do
    @verification.update!(telnyx_request_id: "test-request-id")
    fake_requests = Minitest::Mock.new
    fake_requests.expect(:retrieve, OpenStruct.new(verification_status: "Waiting For Vendor", reason: nil)) { true }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "in_review", result.status
  end

  test "fetch_status! maps 'Waiting For Customer' to waiting_for_customer" do
    @verification.update!(telnyx_request_id: "test-request-id")
    fake_requests = Minitest::Mock.new
    fake_requests.expect(:retrieve, OpenStruct.new(verification_status: "Waiting For Customer", reason: nil)) { true }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "waiting_for_customer", result.status
  end

  test "fetch_status! maps 'Verified' to approved" do
    @verification.update!(telnyx_request_id: "test-request-id")
    fake_requests = Minitest::Mock.new
    fake_requests.expect(:retrieve, OpenStruct.new(verification_status: "Verified", reason: nil)) { true }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "approved", result.status
  end

  test "fetch_status! maps 'Rejected' to rejected" do
    @verification.update!(telnyx_request_id: "test-request-id")
    fake_requests = Minitest::Mock.new
    fake_requests.expect(:retrieve, OpenStruct.new(verification_status: "Rejected", reason: "Invalid business information")) { true }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "rejected", result.status
    assert_equal "Invalid business information", result.last_error
  end

  test "fetch_status! stores reason in last_error when present" do
    @verification.update!(telnyx_request_id: "test-request-id")
    fake_requests = Minitest::Mock.new
    fake_requests.expect(:retrieve, OpenStruct.new(verification_status: "Waiting For Customer", reason: "Additional documentation required")) { true }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "waiting_for_customer", result.status
    assert_equal "Additional documentation required", result.last_error
  end

  test "fetch_status! handles API errors" do
    @verification.update!(telnyx_request_id: "test-request-id")
    fake_requests = Object.new
    fake_requests.define_singleton_method(:retrieve) { |*| raise StandardError, "Verification not found" }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_not_nil result.last_error
    assert_includes result.last_error, "Verification not found"
  end

  test "fetch_status! handles network errors" do
    @verification.update!(telnyx_request_id: "test-request-id")
    fake_requests = Object.new
    fake_requests.define_singleton_method(:retrieve) { |*| raise Faraday::TimeoutError, "execution expired" }
    fake_client = build_fake_client(fake_requests)
    Telnyx::TollFreeVerification.define_singleton_method(:telnyx_client) { fake_client }

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

  private

  # Builds a fake client with the 3-level chain:
  # client.messaging_tollfree.verification.requests
  def build_fake_client(fake_requests)
    fake_verification = OpenStruct.new(requests: fake_requests)
    fake_messaging_tollfree = OpenStruct.new(verification: fake_verification)
    OpenStruct.new(messaging_tollfree: fake_messaging_tollfree)
  end
end
