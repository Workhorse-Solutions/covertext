module Webhooks
  class TwilioInboundController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :require_authentication

    def create
      # Verify Twilio signature in non-test environments
      unless Rails.env.test? && ENV["TWILIO_SKIP_SIGNATURE"] == "true"
        verify_twilio_signature!
      end

      # Parse Twilio params
      from_phone = params[:From]
      to_phone = params[:To]
      body = params[:Body]
      message_sid = params[:MessageSid]
      num_media = params[:NumMedia]&.to_i || 0

      # Resolve Agency by To phone number
      agency = Agency.find_by(sms_phone_number: to_phone)
      unless agency
        head :not_found
        return
      end

      # Idempotency check
      existing_log = MessageLog.find_by(provider_message_id: message_sid)
      if existing_log
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
        provider_message_id: message_sid,
        media_count: num_media
      )

      # Enqueue background job for processing
      ProcessInboundMessageJob.perform_later(message_log.id)

      head :ok
    end

    private

    def verify_twilio_signature!
      # TODO: Phase 1 - Implement Twilio signature verification
      # For now, accept all requests in development/production
      # In real implementation, verify X-Twilio-Signature header
      true
    end
  end
end
