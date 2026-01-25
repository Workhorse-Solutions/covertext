class OutboundMessenger
  def self.send_sms!(agency:, to_phone:, body:)
    MessageLog.create!(
      agency: agency,
      direction: "outbound",
      from_phone: agency.sms_phone_number,
      to_phone: to_phone,
      body: body,
      provider_message_id: nil,
      media_count: 0
    )
  end

  def self.send_mms!(agency:, to_phone:, body:, media_url:, request: nil)
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

    # Create Delivery record
    Delivery.create!(
      request: request,
      method: "mms",
      status: "queued"
    )

    message_log
  end
end
