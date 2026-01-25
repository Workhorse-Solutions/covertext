require "test_helper"

class Webhooks::TwilioInboundControllerTest < ActionDispatch::IntegrationTest
  setup do
    ENV["TWILIO_SKIP_SIGNATURE"] = "true"
    @agency = agencies(:reliable)
  end

  teardown do
    ENV["TWILIO_SKIP_SIGNATURE"] = "true"
  end

  test "creates MessageLog and enqueues job for valid inbound message" do
    assert_difference "MessageLog.count", 1 do
      assert_enqueued_with(job: ProcessInboundMessageJob) do
        post webhooks_twilio_inbound_url, params: {
          From: "+15559876543",
          To: @agency.sms_phone_number,
          Body: "I need my insurance card",
          MessageSid: "SM#{SecureRandom.hex(16)}",
          NumMedia: "0"
        }
      end
    end

    assert_response :ok

    message_log = MessageLog.last
    assert_equal @agency.id, message_log.agency_id
    assert_equal "inbound", message_log.direction
    assert_equal "+15559876543", message_log.from_phone
    assert_equal @agency.sms_phone_number, message_log.to_phone
    assert_equal "I need my insurance card", message_log.body
    assert_equal 0, message_log.media_count
    assert message_log.provider_message_id.present?
  end

  test "handles NumMedia parameter correctly" do
    post webhooks_twilio_inbound_url, params: {
      From: "+15559876543",
      To: @agency.sms_phone_number,
      Body: "Check out this pic",
      MessageSid: "SM#{SecureRandom.hex(16)}",
      NumMedia: "2"
    }

    assert_response :ok
    assert_equal 2, MessageLog.last.media_count
  end

  test "idempotency: duplicate MessageSid does not create duplicate MessageLog" do
    message_sid = "SM#{SecureRandom.hex(16)}"

    # First request
    post webhooks_twilio_inbound_url, params: {
      From: "+15559876543",
      To: @agency.sms_phone_number,
      Body: "First message",
      MessageSid: message_sid,
      NumMedia: "0"
    }

    assert_response :ok
    first_count = MessageLog.count

    # Second request with same MessageSid
    assert_no_difference "MessageLog.count" do
      assert_no_enqueued_jobs do
        post webhooks_twilio_inbound_url, params: {
          From: "+15559876543",
          To: @agency.sms_phone_number,
          Body: "Duplicate message",
          MessageSid: message_sid,
          NumMedia: "0"
        }
      end
    end

    assert_response :ok
    assert_equal first_count, MessageLog.count
  end

  test "returns 404 for unknown To phone number" do
    assert_no_difference "MessageLog.count" do
      assert_no_enqueued_jobs do
        post webhooks_twilio_inbound_url, params: {
          From: "+15559876543",
          To: "+15559999999", # Unknown agency phone
          Body: "Hello",
          MessageSid: "SM#{SecureRandom.hex(16)}",
          NumMedia: "0"
        }
      end
    end

    assert_response :not_found
  end

  test "handles missing NumMedia parameter gracefully" do
    post webhooks_twilio_inbound_url, params: {
      From: "+15559876543",
      To: @agency.sms_phone_number,
      Body: "Message without NumMedia",
      MessageSid: "SM#{SecureRandom.hex(16)}"
    }

    assert_response :ok
    assert_equal 0, MessageLog.last.media_count
  end
end
