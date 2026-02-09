require "test_helper"

module Telnyx
  class PhoneProvisioningServiceTest < ActiveSupport::TestCase
    setup do
      @agency = agencies(:not_ready)
      # Ensure ENV vars are set for tests
      ENV["TELNYX_API_KEY"] = "test_key_123"
      ENV["TELNYX_MESSAGING_PROFILE_ID"] = "test_profile_123"
    end

    test "returns success if phone already provisioned" do
      @agency.update!(phone_sms: "+18001234567")
      service = PhoneProvisioningService.new(@agency)

      result = service.call

      assert result.success?
      assert_equal "Phone number already provisioned", result.message
      assert_equal "+18001234567", result.phone_number
    end

    test "checks for required credentials" do
      # Remove ENV vars and gem key temporarily
      original_key = ENV.delete("TELNYX_API_KEY")
      original_profile = ENV.delete("TELNYX_MESSAGING_PROFILE_ID")
      original_gem_key = ::Telnyx.api_key
      ::Telnyx.api_key = nil

      begin
        service = PhoneProvisioningService.new(@agency)
        result = service.call

        assert_not result.success?
        # Should get user-friendly message, not technical error
        assert_includes result.message, "contact support"
        assert_not_includes result.message, "ENV" # Should not expose technical details
      ensure
        ENV["TELNYX_API_KEY"] = original_key if original_key
        ENV["TELNYX_MESSAGING_PROFILE_ID"] = original_profile if original_profile
        ::Telnyx.api_key = original_gem_key
      end
    end

    test "successfully provisions toll-free number" do
      # Stub Telnyx API search endpoint
      stub_request(:get, "https://api.telnyx.com/v2/available_phone_numbers")
        .with(query: hash_including({}))
        .to_return(
          status: 200,
          body: {
            data: [
              { phone_number: "+18005551234", record_type: "available_phone_number" }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub Telnyx API number order endpoint
      stub_request(:post, "https://api.telnyx.com/v2/number_orders")
        .with(body: hash_including({ messaging_profile_id: "test_profile_123" }))
        .to_return(
          status: 200,
          body: {
            data: {
              id: "order_123",
              phone_numbers: [
                { phone_number: "+18005551234", status: "success" }
              ]
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service = PhoneProvisioningService.new(@agency)
      result = service.call

      assert result.success?
      assert_equal "Phone number provisioned successfully", result.message
      assert_equal "+18005551234", result.phone_number

      # Verify agency was updated
      @agency.reload
      assert_equal "+18005551234", @agency.phone_sms
      assert @agency.live_enabled?
    end

    test "handles no available toll-free numbers" do
      # Stub Telnyx API to return empty results
      stub_request(:get, "https://api.telnyx.com/v2/available_phone_numbers")
        .with(query: hash_including({}))
        .to_return(
          status: 200,
          body: { data: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service = PhoneProvisioningService.new(@agency)
      result = service.call

      assert_not result.success?
      # Should get user-friendly message
      assert_includes result.message, "contact support"
    end

    test "handles API errors gracefully" do
      # Stub Telnyx API to return error
      stub_request(:get, "https://api.telnyx.com/v2/available_phone_numbers")
        .with(query: hash_including({}))
        .to_return(status: 500, body: "Internal Server Error")

      service = PhoneProvisioningService.new(@agency)
      result = service.call

      assert_not result.success?
      # Should get user-friendly message
      assert_includes result.message, "contact support"
      assert_not_includes result.message, "Internal Server Error" # Should not expose API errors
    end

    test "rolls back transaction on configuration failure" do
      # Stub search to succeed
      stub_request(:get, "https://api.telnyx.com/v2/available_phone_numbers")
        .with(query: hash_including({}))
        .to_return(
          status: 200,
          body: {
            data: [
              { phone_number: "+18005551234", record_type: "available_phone_number" }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      # Stub order to fail
      stub_request(:post, "https://api.telnyx.com/v2/number_orders")
        .to_return(status: 422, body: { errors: [ { detail: "Purchase failed" } ] }.to_json)

      service = PhoneProvisioningService.new(@agency)
      result = service.call

      assert_not result.success?
      # Should get user-friendly message
      assert_includes result.message, "contact support"

      # Verify agency was NOT updated due to transaction rollback
      @agency.reload
      assert_nil @agency.phone_sms
      assert_not @agency.live_enabled?
    end
  end
end
