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
end
