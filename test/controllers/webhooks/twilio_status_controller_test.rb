require "test_helper"

class Webhooks::TwilioStatusControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:reliable)
    @client = clients(:alice)
    @coverage_request = Request.create!(
      agency: @agency,
      client: @client,
      request_type: "insurance_card",
      status: "pending"
    )
    @delivery = Delivery.create!(
      request: @coverage_request,
      method: "mms",
      status: "queued",
      provider_message_id: "SM#{SecureRandom.hex(16)}"
    )
  end

  test "updates Delivery status and creates AuditEvent" do
    message_sid = @delivery.provider_message_id
    message_status = "delivered"

    assert_difference "AuditEvent.count", 1 do
      post webhooks_twilio_status_url, params: {
        MessageSid: message_sid,
        MessageStatus: message_status
      }
    end

    assert_response :ok

    @delivery.reload
    assert_equal "delivered", @delivery.status
    assert_not_nil @delivery.last_status_at

    audit_event = AuditEvent.last
    assert_equal @agency.id, audit_event.agency_id
    assert_equal @coverage_request.id, audit_event.request_id
    assert_equal "twilio.delivery_status", audit_event.event_type
    assert_equal message_sid, audit_event.metadata["message_sid"]
    assert_equal message_status, audit_event.metadata["message_status"]
    assert audit_event.metadata["timestamp"].present?
  end

  test "handles various message statuses" do
    statuses = %w[sent delivered failed undelivered]

    statuses.each do |status|
      delivery = Delivery.create!(
        request: @coverage_request,
        method: "mms",
        status: "queued",
        provider_message_id: "SM#{SecureRandom.hex(16)}"
      )

      post webhooks_twilio_status_url, params: {
        MessageSid: delivery.provider_message_id,
        MessageStatus: status
      }

      assert_response :ok
      delivery.reload
      assert_equal status, delivery.status
    end
  end

  test "returns 200 for unknown MessageSid without raising error" do
    unknown_message_sid = "SM_UNKNOWN_#{SecureRandom.hex(16)}"

    assert_no_difference "AuditEvent.count" do
      post webhooks_twilio_status_url, params: {
        MessageSid: unknown_message_sid,
        MessageStatus: "delivered"
      }
    end

    assert_response :ok
  end

  test "updates last_status_at timestamp" do
    freeze_time do
      post webhooks_twilio_status_url, params: {
        MessageSid: @delivery.provider_message_id,
        MessageStatus: "sent"
      }

      @delivery.reload
      assert_in_delta Time.current, @delivery.last_status_at, 1.second
    end
  end
end
