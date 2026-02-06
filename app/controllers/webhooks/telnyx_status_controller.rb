module Webhooks
  class TelnyxStatusController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :require_authentication

    def create
      # Verify Telnyx signature in non-test environments
      unless Rails.env.test? && ENV["TELNYX_SKIP_SIGNATURE"] == "true"
        verify_telnyx_signature!
      end

      # Parse Telnyx webhook payload (nested structure)
      event_type = params[:data][:event_type]

      # Log all events for debugging
      Rails.logger.info "[TelnyxStatus] Received event: #{event_type}"

      # Only process message.finalized events
      if event_type == "message.finalized"
        payload = params[:data][:payload]
        message_id = payload[:id]
        status = payload[:to]&.first&.dig(:status) || "unknown"

        # Find the MessageLog by provider_message_id
        message_log = MessageLog.find_by(provider_message_id: message_id)

        if message_log
          # Update delivery status if we add that field in the future
          Rails.logger.info "[TelnyxStatus] Message #{message_id} status: #{status}"
          # TODO: Update message_log.delivery_status = status when field exists
        else
          Rails.logger.warn "[TelnyxStatus] Message not found: #{message_id}"
        end
      end

      head :ok
    rescue JSON::ParserError, KeyError => e
      Rails.logger.error "[TelnyxStatus] Invalid payload: #{e.message}"
      head :ok  # Still return 200 to avoid retries
    end

    private

    def verify_telnyx_signature!
      signature = request.headers["Telnyx-Signature-Ed25519"]
      timestamp = request.headers["Telnyx-Timestamp-Seconds"]
      public_key = Rails.application.credentials.dig(:telnyx, :public_key) || ENV["TELNYX_PUBLIC_KEY"]

      unless public_key
        Rails.logger.error "[TelnyxStatus] No public key configured"
        head :unauthorized
        return
      end

      begin
        Telnyx::Webhook.construct_event(
          request.body.read,
          signature,
          public_key
        )
      rescue Telnyx::SignatureVerificationError => e
        Rails.logger.error "[TelnyxStatus] Signature verification failed: #{e.message}"
        head :unauthorized
        nil
      ensure
        request.body.rewind
      end
    end
  end
end
