require "test_helper"

class Telnyx::ConfigurationTest < ActiveSupport::TestCase
  setup do
    @test_class = Class.new do
      include Telnyx::Configuration
      # Expose private methods for testing
      public :telnyx_api_key, :telnyx_messaging_profile_id, :configure_telnyx_gem!
    end.new
  end

  test "telnyx_api_key returns existing gem key if present" do
    original = ::Telnyx.api_key
    ::Telnyx.api_key = "existing_key_123"

    assert_equal "existing_key_123", @test_class.telnyx_api_key
  ensure
    ::Telnyx.api_key = original
  end

  test "telnyx_api_key falls back to ENV variable" do
    original_gem = ::Telnyx.api_key
    ::Telnyx.api_key = nil
    original_env = ENV["TELNYX_API_KEY"]
    ENV["TELNYX_API_KEY"] = "env_key_456"

    assert_equal "env_key_456", @test_class.telnyx_api_key
  ensure
    ::Telnyx.api_key = original_gem
    ENV["TELNYX_API_KEY"] = original_env
  end

  test "telnyx_api_key raises if not configured" do
    original_gem = ::Telnyx.api_key
    ::Telnyx.api_key = nil
    original_env = ENV.delete("TELNYX_API_KEY")

    error = assert_raises(RuntimeError) do
      @test_class.telnyx_api_key
    end
    assert_includes error.message, "API key not configured"
  ensure
    ::Telnyx.api_key = original_gem
    ENV["TELNYX_API_KEY"] = original_env
  end

  test "telnyx_messaging_profile_id reads from ENV" do
    ENV["TELNYX_MESSAGING_PROFILE_ID"] = "profile_abc"

    assert_equal "profile_abc", @test_class.telnyx_messaging_profile_id
  ensure
    ENV["TELNYX_MESSAGING_PROFILE_ID"] = "test_profile_id"
  end

  test "telnyx_messaging_profile_id raises if not configured" do
    original = ENV.delete("TELNYX_MESSAGING_PROFILE_ID")

    assert_raises(RuntimeError, /messaging profile ID not configured/) do
      @test_class.telnyx_messaging_profile_id
    end
  ensure
    ENV["TELNYX_MESSAGING_PROFILE_ID"] = original if original
  end

  test "configure_telnyx_gem! sets the API key on the Telnyx module" do
    original = ::Telnyx.api_key
    ::Telnyx.api_key = nil

    @test_class.configure_telnyx_gem!

    assert_not_nil ::Telnyx.api_key
  ensure
    ::Telnyx.api_key = original
  end
end
