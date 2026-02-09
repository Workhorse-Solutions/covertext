module Telnyx
  # Shared configuration concern for all Telnyx service objects.
  # Provides a configured Telnyx::Client instance and messaging
  # profile ID resolution from Rails credentials or ENV variables.
  #
  # Usage:
  #   class MyService
  #     include Telnyx::Configuration
  #
  #     def call
  #       client = telnyx_client
  #       client.messages.send_(from: ..., to: ..., text: ...)
  #     end
  #   end
  #
  # For class-level (singleton) usage:
  #   class MyService
  #     class << self
  #       include Telnyx::Configuration
  #     end
  #   end
  module Configuration
    private

    # Returns a Telnyx::Client instance configured with the API key.
    def telnyx_client
      api_key = Rails.application.credentials.dig(:telnyx, :api_key) || ENV["TELNYX_API_KEY"]
      raise "Telnyx API key not configured. Please set it in Rails credentials or ENV." unless api_key
      ::Telnyx::Client.new(api_key: api_key)
    end

    def telnyx_messaging_profile_id
      id = Rails.application.credentials.dig(:telnyx, :messaging_profile_id) || ENV["TELNYX_MESSAGING_PROFILE_ID"]
      raise "Telnyx messaging profile ID not configured. Please set it in Rails credentials or ENV." unless id
      id
    end
  end
end
