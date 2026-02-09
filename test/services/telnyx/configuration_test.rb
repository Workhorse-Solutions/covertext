require "test_helper"

class Telnyx::ConfigurationTest < ActiveSupport::TestCase
  setup do
    @test_class = Class.new do
      include Telnyx::Configuration
      public :telnyx_client, :telnyx_messaging_profile_id
    end.new
    @original_api_key = ENV["TELNYX_API_KEY"]
    @original_profile_id = ENV["TELNYX_MESSAGING_PROFILE_ID"]
  end

  teardown do
    ENV["TELNYX_API_KEY"] = @original_api_key
    ENV["TELNYX_MESSAGING_PROFILE_ID"] = @original_profile_id
  end

  test "telnyx_client returns a Telnyx::Client if API key is set" do
    ENV["TELNYX_API_KEY"] = "test_key_123"
    client = @test_class.telnyx_client
    assert_instance_of ::Telnyx::Client, client
  end

  test "telnyx_client raises if API key is not set" do
    ENV.delete("TELNYX_API_KEY")
    error = assert_raises(RuntimeError) { @test_class.telnyx_client }
    assert_includes error.message, "API key not configured"
  end

  test "telnyx_messaging_profile_id reads from ENV" do
    ENV["TELNYX_MESSAGING_PROFILE_ID"] = "profile_abc"
    assert_equal "profile_abc", @test_class.telnyx_messaging_profile_id
  end

  test "telnyx_messaging_profile_id raises if not configured" do
    ENV.delete("TELNYX_MESSAGING_PROFILE_ID")
    assert_raises(RuntimeError, /messaging profile ID not configured/) do
      @test_class.telnyx_messaging_profile_id
    end
  end
end
