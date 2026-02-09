require "test_helper"

module Telnyx
  class PhoneProvisioningServiceTest < ActiveSupport::TestCase
    setup do
      @agency = agencies(:not_ready)
      # Store original ENV values
      @original_api_key = ENV["TELNYX_API_KEY"]
      @original_profile_id = ENV["TELNYX_MESSAGING_PROFILE_ID"]
      # Set test-specific ENV vars
      ENV["TELNYX_API_KEY"] = "test_key_123"
      ENV["TELNYX_MESSAGING_PROFILE_ID"] = "test_profile_123"
      # Configure Telnyx gem with test credentials
      ::Telnyx.api_key = ENV["TELNYX_API_KEY"]
      # Reset Telnyx client's thread-local connection cache to prevent stale state
      Thread.current[:telnyx_client] = nil
      Thread.current[:telnyx_client_default_client] = nil
      Thread.current[:telnyx_client_default_conn] = nil
    end

    teardown do
      # Restore original ENV values to prevent pollution
      ENV["TELNYX_API_KEY"] = @original_api_key
      ENV["TELNYX_MESSAGING_PROFILE_ID"] = @original_profile_id
      # Reset Telnyx gem configuration
      ::Telnyx.api_key = @original_api_key
    end

    # --- search_available_numbers ---

    test "search_available_numbers returns list of phone numbers" do
      stub_request(:get, "https://api.telnyx.com/v2/available_phone_numbers")
        .with(query: hash_including({}))
        .to_return(
          status: 200,
          body: {
            data: [
              { phone_number: "+18005551234", record_type: "available_phone_number" },
              { phone_number: "+18775559876", record_type: "available_phone_number" }
            ]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service = PhoneProvisioningService.new(@agency)
      $stderr.puts "[DEBUG-TEST] service.class=#{service.class}"
      $stderr.puts "[DEBUG-TEST] service.class.instance_method(:search_available_numbers).source_location=#{service.class.instance_method(:search_available_numbers).source_location.inspect}"
      result = service.search_available_numbers

      unless result.success?
        $stderr.puts "[DEBUG] result.success?=#{result.success?} message=#{result.message}"
        # Call list directly and inspect response structure
        begin
          raw = ::Telnyx::AvailablePhoneNumber.list(filter: { phone_number_type: "toll_free", country_code: "US", features: "sms", limit: 2 })
          $stderr.puts "[DEBUG] raw.data.size=#{raw.data.size}"
          if raw.data.size > 0
            n = raw.data[0]
            $stderr.puts "[DEBUG] n.class=#{n.class}"
            $stderr.puts "[DEBUG] n['phone_number']=#{n['phone_number'].inspect}"
            $stderr.puts "[DEBUG] n[:phone_number]=#{n[:phone_number].inspect}"
            $stderr.puts "[DEBUG] n.phone_number=#{n.phone_number.inspect rescue 'N/A'}"
            $stderr.puts "[DEBUG] n.values=#{n.instance_variable_get(:@values).inspect}"
          end
        rescue => e
          $stderr.puts "[DEBUG] error: #{e.class}: #{e.message}"
        end
      end
      assert result.success?
      assert_equal [ "+18005551234", "+18775559876" ], result.data[:phone_numbers]
    end

    test "search_available_numbers returns failure when no numbers available" do
      stub_request(:get, "https://api.telnyx.com/v2/available_phone_numbers")
        .with(query: hash_including({}))
        .to_return(
          status: 200,
          body: { data: [] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      service = PhoneProvisioningService.new(@agency)
      result = service.search_available_numbers

      assert_not result.success?
      assert_includes result.message, "No toll-free numbers"
    end



    # --- error-handling tests ---
    # TODO: These tests use method manipulation that causes test pollution.
    # Skipping for now until we can implement proper mocking strategy.

    test "search_available_numbers handles API errors" do
      skip "Test causes pollution - needs refactoring"
      # Save the original method using alias
      klass = Telnyx::AvailablePhoneNumber.singleton_class
      klass.alias_method :__original_list_backup, :list if klass.method_defined?(:list)

      begin
        Telnyx::AvailablePhoneNumber.define_singleton_method(:list) do |*_args|
          raise StandardError, "API connection failed"
        end

        service = PhoneProvisioningService.new(@agency)
        result = service.search_available_numbers

        assert_not result.success?
        assert_includes result.message, "contact support"
      ensure
        # Restore the original method using alias
        if klass.method_defined?(:__original_list_backup)
          klass.alias_method :list, :__original_list_backup
          klass.remove_method :__original_list_backup
        end
      end
    end

    test "search_available_numbers checks for required credentials" do
      skip "Test causes pollution - needs refactoring"
      original_key = ENV.delete("TELNYX_API_KEY")
      original_gem_key = ::Telnyx.api_key
      ::Telnyx.api_key = nil

      # Save the original method using alias
      klass = Telnyx::AvailablePhoneNumber.singleton_class
      klass.alias_method :__original_list_backup, :list if klass.method_defined?(:list)

      begin
        Telnyx::AvailablePhoneNumber.define_singleton_method(:list) do |*_args|
          raise StandardError, "API key is missing"
        end

        service = PhoneProvisioningService.new(@agency)
        result = service.search_available_numbers

        assert_not result.success?
        assert_includes result.message, "contact support"
      ensure
        ENV["TELNYX_API_KEY"] = original_key if original_key
        ::Telnyx.api_key = original_gem_key
        # Restore the original method using alias
        if klass.method_defined?(:__original_list_backup)
          klass.alias_method :list, :__original_list_backup
          klass.remove_method :__original_list_backup
        end
      end
    end

    # --- provision ---

    test "provision returns success if phone already provisioned" do
      @agency.update!(phone_sms: "+18001234567")
      service = PhoneProvisioningService.new(@agency)

      result = service.provision("+18005559999")

      assert result.success?
      assert_equal "Phone number already provisioned", result.message
      assert_equal "+18001234567", result.phone_number
    end

    test "provision purchases and assigns selected number" do
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
      result = service.provision("+18005551234")

      assert result.success?
      assert_equal "Phone number provisioned successfully", result.message
      assert_equal "+18005551234", result.phone_number

      @agency.reload
      assert_equal "+18005551234", @agency.phone_sms
      assert @agency.live_enabled?
    end

    test "provision handles purchase failure" do
      stub_request(:post, "https://api.telnyx.com/v2/number_orders")
        .to_return(status: 422, body: { errors: [ { detail: "Purchase failed" } ] }.to_json)

      service = PhoneProvisioningService.new(@agency)
      result = service.provision("+18005551234")

      assert_not result.success?
      assert_includes result.message, "contact support"

      @agency.reload
      assert_nil @agency.phone_sms
      assert_not @agency.live_enabled?
    end

    test "provision checks for required credentials" do
      original_key = ENV.delete("TELNYX_API_KEY")
      original_profile = ENV.delete("TELNYX_MESSAGING_PROFILE_ID")
      original_gem_key = ::Telnyx.api_key
      ::Telnyx.api_key = nil

      begin
        service = PhoneProvisioningService.new(@agency)
        result = service.provision("+18005551234")

        assert_not result.success?
        assert_includes result.message, "contact support"
        assert_not_includes result.message, "ENV"
      ensure
        ENV["TELNYX_API_KEY"] = original_key if original_key
        ENV["TELNYX_MESSAGING_PROFILE_ID"] = original_profile if original_profile
        ::Telnyx.api_key = original_gem_key
      end
    end
  end
end
