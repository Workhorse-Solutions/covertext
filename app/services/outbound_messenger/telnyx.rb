module OutboundMessenger
  class Telnyx
    class << self
      include ::Telnyx::Configuration

      def send_sms!(agency:, to_phone:, body:, request: nil)
        client = telnyx_client
        response = client.messages.send_(from: agency.phone_sms, to: to_phone, text: body)
        log_message(agency: agency, request: request, to_phone: to_phone, body: body,
                    provider_message_id: response.data&.id, media_count: 0)
      rescue => e
        Rails.logger.error "[OutboundMessenger::Telnyx] SMS send failed: #{e.message}"
        log_message(agency: agency, request: request, to_phone: to_phone, body: body,
                    provider_message_id: nil, media_count: 0)
        raise e
      end

      def send_mms!(agency:, to_phone:, body:, media_url:, request: nil)
        client = telnyx_client
        response = client.messages.send_(from: agency.phone_sms, to: to_phone, text: body, media_urls: [ media_url ])
        message_log = log_message(agency: agency, request: request, to_phone: to_phone, body: body,
                                  provider_message_id: response.data&.id, media_count: 1)
        Delivery.create!(request: request, method: "mms", status: "queued")
        message_log
      rescue => e
        Rails.logger.error "[OutboundMessenger::Telnyx] MMS send failed: #{e.message}"
        log_message(agency: agency, request: request, to_phone: to_phone, body: body,
                    provider_message_id: nil, media_count: 1)
        Delivery.create!(request: request, method: "mms", status: "failed")
        raise e
      end

      private

      def log_message(agency:, request:, to_phone:, body:, provider_message_id:, media_count:)
        MessageLog.create!(
          agency: agency,
          request: request,
          direction: "outbound",
          from_phone: agency.phone_sms,
          to_phone: to_phone,
          body: body,
          provider_message_id: provider_message_id,
          media_count: media_count
        )
      end
    end
  end
end
