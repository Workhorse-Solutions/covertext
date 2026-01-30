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
      # Get the signature from the header
      signature = request.headers["X-Twilio-Signature"]
      url = request.original_url

      # Build params hash for validation (Twilio expects form params)
      post_params = request.POST

      # Get auth token from Rails credentials or ENV (same as initializer)
      auth_token = Rails.application.credentials.dig(:twilio, :auth_token) || ENV["TWILIO_AUTH_TOKEN"]

      unless auth_token
        Rails.logger.error "[TwilioInbound] TWILIO_AUTH_TOKEN not configured"
        head :internal_server_error
        return false
      end

      # Verify the signature
      validator = Twilio::Security::RequestValidator.new(auth_token)

      unless validator.validate(url, post_params, signature)
        Rails.logger.warn "[TwilioInbound] Invalid signature from #{request.remote_ip}"
        head :forbidden
        return false
      end

      true
    end
  end
end
