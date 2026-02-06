# Configure Telnyx client
#
# In test environment, we stub the client to avoid making real API calls
# In development/production, we use real Telnyx credentials

require "telnyx"
require "ostruct"

module TelnyxClient
  class << self
    def client
      @client ||= begin
        if Rails.env.test? || ENV["TELNYX_STUB"] == "true"
          # Use a stubbed client for testing
          create_stub_client
        else
          # Use real Telnyx client
          # Try Rails credentials first, fall back to ENV
          api_key = Rails.application.credentials.dig(:telnyx, :api_key) || ENV["TELNYX_API_KEY"]

          unless api_key
            raise "Telnyx credentials not configured. Add to credentials.yml.enc or set TELNYX_API_KEY env var."
          end

          Telnyx.api_key = api_key
          Telnyx
        end
      end
    end

    def webhook_secret
      # Try Rails credentials first, fall back to ENV
      Rails.application.credentials.dig(:telnyx, :webhook_secret) || ENV["TELNYX_WEBHOOK_SECRET"]
    end

    def reset!
      @client = nil
    end

    private

    def create_stub_client
      # Create a stub that looks like the Telnyx module
      stub_client = Object.new

      # Create stub Message class
      stub_message_class = Class.new do
        def self.create(params)
          # Return a fake Telnyx message response
          OpenStruct.new(
            id: "msg_#{SecureRandom.hex(16)}",
            from: params[:from],
            to: params[:to],
            text: params[:text],
            status: "queued",
            direction: "outbound",
            media_urls: params[:media_urls] || []
          ).tap do |response|
            Rails.logger.info "[TelnyxStub] Outbound message: #{params[:to]} - #{params[:text]}"
          end
        end
      end

      # Attach Message class to stub client
      stub_client.define_singleton_method(:Message) { stub_message_class }

      stub_client
    end
  end
end
