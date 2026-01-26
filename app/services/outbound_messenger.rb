class OutboundMessenger
  def self.send_sms!(agency:, to_phone:, body:, request: nil)
    # Send via Twilio
    response = TwilioClient.client.messages.create(
      from: agency.sms_phone_number,
      to: to_phone,
      body: body
    )

    # Log the outbound message
    MessageLog.create!(
      agency: agency,
      request: request,
      direction: "outbound",
      from_phone: agency.sms_phone_number,
      to_phone: to_phone,
      body: body,
      provider_message_id: response.sid,
      media_count: 0
    )
  rescue => e
    # Log error but still create MessageLog record
    Rails.logger.error "[OutboundMessenger] SMS send failed: #{e.message}"

    MessageLog.create!(
      agency: agency,
      request: request,
      direction: "outbound",
      from_phone: agency.sms_phone_number,
      to_phone: to_phone,
      body: body,
      provider_message_id: nil,
      media_count: 0
    )

    raise e
  end

  def self.send_mms!(agency:, to_phone:, body:, media_url:, request: nil)
    # Send via Twilio
    response = TwilioClient.client.messages.create(
      from: agency.sms_phone_number,
      to: to_phone,
      body: body,
      media_url: [ media_url ]
    )

    # Log the outbound message
    message_log = MessageLog.create!(
      agency: agency,
      request: request,
      direction: "outbound",
      from_phone: agency.sms_phone_number,
      to_phone: to_phone,
      body: body,
      provider_message_id: response.sid,
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
    Rails.logger.error "[OutboundMessenger] MMS send failed: #{e.message}"

    message_log = MessageLog.create!(
      agency: agency,
      request: request,
      direction: "outbound",
      from_phone: agency.sms_phone_number,
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
