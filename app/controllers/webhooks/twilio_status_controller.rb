module Webhooks
  class TwilioStatusController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      # Parse Twilio status callback params
      message_sid = params[:MessageSid]
      message_status = params[:MessageStatus]

      # Find Delivery by provider_message_id
      delivery = Delivery.find_by(provider_message_id: message_sid)

      # If not found, return 200 (Twilio may send callbacks for unknown messages)
      unless delivery
        head :ok
        return
      end

      # Update Delivery status
      delivery.update!(
        status: message_status,
        last_status_at: Time.current
      )

      # Create AuditEvent
      AuditEvent.create!(
        agency_id: delivery.request.agency_id,
        request_id: delivery.request_id,
        event_type: "twilio.delivery_status",
        metadata: {
          message_sid: message_sid,
          message_status: message_status,
          timestamp: Time.current.iso8601
        }
      )

      head :ok
    end
  end
end
