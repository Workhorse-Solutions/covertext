module OutboundMessenger
  class Telnyx
    class << self
      def send_sms!(agency:, to_phone:, body:, request: nil)
        # Send via Telnyx
        response = TelnyxClient.client.Message.create(
          from: agency.phone_sms,
          to: to_phone,
          text: body
        )

        # Log the outbound message
        MessageLog.create!(
          agency: agency,
          request: request,
          direction: "outbound",
          from_phone: agency.phone_sms,
          to_phone: to_phone,
          body: body,
          provider_message_id: response.id,
          media_count: 0
        )
      rescue => e
        # Log error but still create MessageLog record
        Rails.logger.error "[OutboundMessenger::Telnyx] SMS send failed: #{e.message}"

        MessageLog.create!(
          agency: agency,
          request: request,
          direction: "outbound",
          from_phone: agency.phone_sms,
          to_phone: to_phone,
          body: body,
          provider_message_id: nil,
          media_count: 0
        )

        raise e
      end

      def send_mms!(agency:, to_phone:, body:, media_url:, request: nil)
        # Send via Telnyx
        response = TelnyxClient.client.Message.create(
          from: agency.phone_sms,
          to: to_phone,
          text: body,
          media_urls: [ media_url ]
        )

        # Log the outbound message
        message_log = MessageLog.create!(
          agency: agency,
          request: request,
          direction: "outbound",
          from_phone: agency.phone_sms,
          to_phone: to_phone,
          body: body,
          provider_message_id: response.id,
          media_count: 1
        )

        # Create Delivery record
        Delivery.create!(
          request: request,
          method: "mms",
          status: "queued"
        )

        message_log
      rescue => e
        # Log error but still create MessageLog and Delivery records
        Rails.logger.error "[OutboundMessenger::Telnyx] MMS send failed: #{e.message}"

        message_log = MessageLog.create!(
          agency: agency,
          request: request,
          direction: "outbound",
          from_phone: agency.phone_sms,
          to_phone: to_phone,
          body: body,
          provider_message_id: nil,
          media_count: 1
        )

        Delivery.create!(
          request: request,
          method: "mms",
          status: "failed"
        )

        raise e
      end
    end
  end
end
