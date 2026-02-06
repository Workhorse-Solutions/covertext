module Webhooks
  class TelnyxInboundController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :require_authentication

    def create
      # Verify Telnyx signature in non-test environments
      unless Rails.env.test? && ENV["TELNYX_SKIP_SIGNATURE"] == "true"
        verify_telnyx_signature!
      end

      # Parse Telnyx webhook payload (nested structure)
      event_type = params[:data][:event_type]

      # Only process message.received events
      unless event_type == "message.received"
        Rails.logger.info "[TelnyxInbound] Ignoring event type: #{event_type}"
        head :ok
        return
      end

      payload = params[:data][:payload]

      # Extract message details from nested payload
      from_phone = payload[:from][:phone_number]
      to_phone = payload[:to]&.first&.dig(:phone_number)
      body = payload[:text]
      message_id = payload[:id]
      num_media = payload[:media]&.count || 0

      # Resolve Agency by To phone number
      agency = Agency.find_by(phone_sms: to_phone)
      unless agency
        Rails.logger.warn "[TelnyxInbound] No agency found for number: #{to_phone}"
        head :not_found
        return
      end

      # Idempotency check
      existing_log = MessageLog.find_by(provider_message_id: message_id)
      if existing_log
        Rails.logger.info "[TelnyxInbound] Duplicate message ID: #{message_id}"
        head :ok
        return
      end

      # Create inbound MessageLog
      message_log = MessageLog.create!(
        agency: agency,
        direction: "inbound",
        from_phone: from_phone,
        to_phone: to_phone,
        body: body,
        provider_message_id: message_id,
        media_count: num_media
      )

      # Enqueue background job for processing
      ProcessInboundMessageJob.perform_later(message_log.id)

      head :ok
    rescue JSON::ParserError, KeyError => e
      Rails.logger.error "[TelnyxInbound] Invalid payload: #{e.message}"
      head :bad_request
    end

    private

    def verify_telnyx_signature!
      signature = request.headers["Telnyx-Signature-Ed25519"]
      timestamp = request.headers["Telnyx-Timestamp-Seconds"]
      webhook_secret = TelnyxClient.webhook_secret

      unless webhook_secret
        Rails.logger.error "[TelnyxInbound] No webhook secret configured"
        head :unauthorized
        return
      end

      begin
        Telnyx::Webhook::Signature.verify(
          request.body.read,
          signature,
          timestamp,
          webhook_secret
        )
      rescue Telnyx::SignatureVerificationError => e
        Rails.logger.error "[TelnyxInbound] Signature verification failed: #{e.message}"
        head :unauthorized
      ensure
        request.body.rewind
      end
    end
  end
end
