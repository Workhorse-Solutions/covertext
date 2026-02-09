module Telnyx
  # Shared configuration concern for all Telnyx service objects.
  # Centralizes API key and messaging profile ID resolution from
  # Rails credentials or ENV variables.
  #
  # Usage:
  #   class MyService
  #     include Telnyx::Configuration
  #
  #     def call
  #       configure_telnyx_gem!
  #       # Now Telnyx gem is ready to use
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

    def configure_telnyx_gem!
      ::Telnyx.api_key = telnyx_api_key
    end

    def telnyx_api_key
      return ::Telnyx.api_key if ::Telnyx.api_key.present?

      key = Rails.application.credentials.dig(:telnyx, :api_key) || ENV["TELNYX_API_KEY"]
      raise "Telnyx API key not configured. Please set it in Rails credentials or ENV." unless key

      key
    end

    def telnyx_messaging_profile_id
      id = Rails.application.credentials.dig(:telnyx, :messaging_profile_id) || ENV["TELNYX_MESSAGING_PROFILE_ID"]
      raise "Telnyx messaging profile ID not configured. Please set it in Rails credentials or ENV." unless id

      id
    end
  end
end
