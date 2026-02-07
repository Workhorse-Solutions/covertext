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
  end

  test "submit! successfully creates verification request" do
    stub_request(:post, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests")
      .with(
        headers: {
          "Authorization" => "Bearer #{ENV['TELNYX_API_KEY']}",
          "Content-Type" => "application/json"
        },
        body: @verification.payload.to_json
      )
      .to_return(
        status: 200,
        body: {
          data: {
            id: "test-request-id-123",
            verificationStatus: "In Progress"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Telnyx::TollFreeVerification.submit!(@verification)

    assert_equal "submitted", result.status
    assert_equal "test-request-id-123", result.telnyx_request_id
    assert_not_nil result.submitted_at
  end

  test "submit! handles HTTP error response" do
    stub_request(:post, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests")
      .to_return(
        status: 422,
        body: { errors: [ { detail: "Invalid phone number" } ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Telnyx::TollFreeVerification.submit!(@verification)

    assert_equal "draft", result.status # Status should not change on error
    assert_includes result.last_error, "422"
    assert_includes result.last_error, "Invalid phone number"
    assert_nil result.telnyx_request_id
  end

  test "submit! handles network errors" do
    stub_request(:post, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests")
      .to_timeout

    result = Telnyx::TollFreeVerification.submit!(@verification)

    assert_equal "draft", result.status
    assert_not_nil result.last_error
    assert_match /timeout|execution expired/i, result.last_error
  end

  test "submit! raises error if API key not configured" do
    original_key = ENV["TELNYX_API_KEY"]
    ENV["TELNYX_API_KEY"] = nil

    result = Telnyx::TollFreeVerification.submit!(@verification)

    assert_not_nil result.last_error
    assert_includes result.last_error, "API key not configured"
  ensure
    ENV["TELNYX_API_KEY"] = original_key
  end

  test "fetch_status! maps 'In Progress' to in_review" do
    @verification.update!(telnyx_request_id: "test-request-id")

    stub_request(:get, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests/test-request-id")
      .to_return(
        status: 200,
        body: {
          data: {
            id: "test-request-id",
            verificationStatus: "In Progress"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "in_review", result.status
    assert_not_nil result.last_status_at
  end

  test "fetch_status! maps 'Waiting For Telnyx' to in_review" do
    @verification.update!(telnyx_request_id: "test-request-id")

    stub_request(:get, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests/test-request-id")
      .to_return(
        status: 200,
        body: {
          data: {
            verificationStatus: "Waiting For Telnyx"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "in_review", result.status
  end

  test "fetch_status! maps 'Waiting For Vendor' to in_review" do
    @verification.update!(telnyx_request_id: "test-request-id")

    stub_request(:get, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests/test-request-id")
      .to_return(
        status: 200,
        body: {
          data: {
            verificationStatus: "Waiting For Vendor"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "in_review", result.status
  end

  test "fetch_status! maps 'Waiting For Customer' to waiting_for_customer" do
    @verification.update!(telnyx_request_id: "test-request-id")

    stub_request(:get, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests/test-request-id")
      .to_return(
        status: 200,
        body: {
          data: {
            verificationStatus: "Waiting For Customer"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "waiting_for_customer", result.status
  end

  test "fetch_status! maps 'Verified' to approved" do
    @verification.update!(telnyx_request_id: "test-request-id")

    stub_request(:get, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests/test-request-id")
      .to_return(
        status: 200,
        body: {
          data: {
            verificationStatus: "Verified"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "approved", result.status
  end

  test "fetch_status! maps 'Rejected' to rejected" do
    @verification.update!(telnyx_request_id: "test-request-id")

    stub_request(:get, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests/test-request-id")
      .to_return(
        status: 200,
        body: {
          data: {
            verificationStatus: "Rejected",
            reason: "Invalid business information"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "rejected", result.status
    assert_equal "Invalid business information", result.last_error
  end

  test "fetch_status! stores reason in last_error when present" do
    @verification.update!(telnyx_request_id: "test-request-id")

    stub_request(:get, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests/test-request-id")
      .to_return(
        status: 200,
        body: {
          data: {
            verificationStatus: "Waiting For Customer",
            reason: "Additional documentation required"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_equal "waiting_for_customer", result.status
    assert_equal "Additional documentation required", result.last_error
  end

  test "fetch_status! handles HTTP error response" do
    @verification.update!(telnyx_request_id: "test-request-id")

    stub_request(:get, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests/test-request-id")
      .to_return(
        status: 404,
        body: { errors: [ { detail: "Verification not found" } ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_includes result.last_error, "404"
  end

  test "fetch_status! handles network errors" do
    @verification.update!(telnyx_request_id: "test-request-id")

    stub_request(:get, "https://api.telnyx.com/v2/messaging_tollfree/verification/requests/test-request-id")
      .to_timeout

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_not_nil result.last_error
    assert_match /timeout|execution expired/i, result.last_error
  end

  test "fetch_status! handles missing telnyx_request_id" do
    @verification.update!(telnyx_request_id: nil)

    result = Telnyx::TollFreeVerification.fetch_status!(@verification)

    assert_not_nil result.last_error
    assert_includes result.last_error, "telnyx_request_id is missing"
  end
end
