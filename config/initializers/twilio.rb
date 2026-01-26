# Configure Twilio client
#
# In test environment, we stub the client to avoid making real API calls
# In development/production, we use real Twilio credentials

require "twilio-ruby"
require "ostruct"

module TwilioClient
  class << self
    def client
      @client ||= begin
        if Rails.env.test? || ENV["TWILIO_STUB"] == "true"
          # Use a stubbed client for testing
          create_stub_client
        else
          # Use real Twilio client
          Twilio::REST::Client.new(
            ENV.fetch("TWILIO_ACCOUNT_SID"),
            ENV.fetch("TWILIO_AUTH_TOKEN")
          )
        end
      end
    end

    def reset!
      @client = nil
    end

    private

    def create_stub_client
      # Create a stub that looks like a Twilio client
      stub_client = Object.new

      # Create stub messages interface
      stub_messages = Object.new
      stub_messages.define_singleton_method(:create) do |params|
        # Return a fake Twilio message response
        OpenStruct.new(
          sid: "SM#{SecureRandom.hex(16)}",
          from: params[:from],
          to: params[:to],
          body: params[:body],
          status: "queued",
          direction: "outbound-api",
          num_media: params[:media_url] ? "1" : "0",
          error_code: nil,
          error_message: nil
        ).tap do |response|
          Rails.logger.info "[TwilioStub] Outbound message: #{params[:to]} - #{params[:body]}"
        end
      end

      # Attach messages to client stub
      stub_client.define_singleton_method(:messages) { stub_messages }

      stub_client
    end
  end
end
