require "test_helper"
require "minitest/mock"

module OutboundMessenger
  class TelnyxTest < ActiveSupport::TestCase
    setup do
      @agency = agencies(:reliable)
      @client = clients(:alice)
      @original_client = OutboundMessenger::Telnyx.method(:telnyx_client)
    end

    teardown do
      OutboundMessenger::Telnyx.define_singleton_method(:telnyx_client, @original_client)
    end

    # --- send_sms! ---

    test "send_sms! sends message via Telnyx and creates MessageLog" do
      fake_client = Minitest::Mock.new
      fake_messages = Minitest::Mock.new
      fake_messages.expect(:send_, OpenStruct.new(data: OpenStruct.new(id: "msg-123"))) { true }
      fake_client.expect :messages, fake_messages
      OutboundMessenger::Telnyx.define_singleton_method(:telnyx_client) { fake_client }

      assert_difference "MessageLog.count", 1 do
        OutboundMessenger::Telnyx.send_sms!(
          agency: @agency,
          to_phone: @client.phone_mobile,
          body: "Your insurance card is ready"
        )
      end

      log = MessageLog.last
      assert_equal "outbound", log.direction
      assert_equal @agency.phone_sms, log.from_phone
      assert_equal @client.phone_mobile, log.to_phone
      assert_equal "Your insurance card is ready", log.body
      assert_not_nil log.provider_message_id
      assert_equal 0, log.media_count
      assert_equal @agency, log.agency
      fake_messages.verify
      fake_client.verify
    end

    test "send_sms! associates MessageLog with request when provided" do
      request = Request.create!(
        agency: @agency,
        client: @client,
        request_type: "insurance_card",
        status: "pending"
      )
      fake_client = Minitest::Mock.new
      fake_messages = Minitest::Mock.new
      fake_messages.expect(:send_, OpenStruct.new(data: OpenStruct.new(id: "msg-456"))) { true }
      fake_client.expect :messages, fake_messages
      OutboundMessenger::Telnyx.define_singleton_method(:telnyx_client) { fake_client }

      OutboundMessenger::Telnyx.send_sms!(
        agency: @agency,
        to_phone: @client.phone_mobile,
        body: "Here is your card",
        request: request
      )

      log = MessageLog.last
      assert_equal request, log.request
      fake_messages.verify
      fake_client.verify
    end

    test "send_sms! creates MessageLog even on send failure" do
      fake_client = Minitest::Mock.new
      fake_messages = Object.new
      fake_messages.define_singleton_method(:send_) { |*| raise "API connection failed" }
      fake_client.expect :messages, fake_messages
      OutboundMessenger::Telnyx.define_singleton_method(:telnyx_client) { fake_client }

      assert_difference "MessageLog.count", 1 do
        assert_raises(RuntimeError, "API connection failed") do
          OutboundMessenger::Telnyx.send_sms!(
            agency: @agency,
            to_phone: @client.phone_mobile,
            body: "Test message"
          )
        end
      end

      log = MessageLog.last
      assert_nil log.provider_message_id
      assert_equal "outbound", log.direction
    end

    # --- send_mms! ---

    test "send_mms! sends message with media and creates MessageLog and Delivery" do
      request = Request.create!(
        agency: @agency,
        client: @client,
        request_type: "insurance_card",
        status: "pending"
      )
      fake_client = Minitest::Mock.new
      fake_messages = Minitest::Mock.new
      fake_messages.expect(:send_, OpenStruct.new(data: OpenStruct.new(id: "msg-mms-123"))) { true }
      fake_client.expect :messages, fake_messages
      OutboundMessenger::Telnyx.define_singleton_method(:telnyx_client) { fake_client }

      assert_difference [ "MessageLog.count", "Delivery.count" ], 1 do
        OutboundMessenger::Telnyx.send_mms!(
          agency: @agency,
          to_phone: @client.phone_mobile,
          body: "Here is your insurance card",
          media_url: "https://example.com/card.pdf",
          request: request
        )
      end

      log = MessageLog.last
      assert_equal 1, log.media_count
      assert_not_nil log.provider_message_id
      assert_equal request, log.request

      delivery = Delivery.last
      assert_equal "mms", delivery.method
      assert_equal "queued", delivery.status
      assert_equal request, delivery.request
      fake_messages.verify
      fake_client.verify
    end

    test "send_mms! creates failed Delivery on send failure" do
      request = Request.create!(
        agency: @agency,
        client: @client,
        request_type: "insurance_card",
        status: "pending"
      )
      fake_client = Minitest::Mock.new
      fake_messages = Object.new
      fake_messages.define_singleton_method(:send_) { |*| raise "MMS send failed" }
      fake_client.expect :messages, fake_messages
      OutboundMessenger::Telnyx.define_singleton_method(:telnyx_client) { fake_client }

      assert_difference [ "MessageLog.count", "Delivery.count" ], 1 do
        assert_raises(RuntimeError, "MMS send failed") do
          OutboundMessenger::Telnyx.send_mms!(
            agency: @agency,
            to_phone: @client.phone_mobile,
            body: "Your card",
            media_url: "https://example.com/card.pdf",
            request: request
          )
        end
      end

      log = MessageLog.last
      assert_nil log.provider_message_id

      delivery = Delivery.last
      assert_equal "failed", delivery.status
    end

    test "send_mms! returns the MessageLog record" do
      request = Request.create!(
        agency: @agency,
        client: @client,
        request_type: "insurance_card",
        status: "pending"
      )
      fake_client = Minitest::Mock.new
      fake_messages = Minitest::Mock.new
      fake_messages.expect(:send_, OpenStruct.new(data: OpenStruct.new(id: "msg-mms-789"))) { true }
      fake_client.expect :messages, fake_messages
      OutboundMessenger::Telnyx.define_singleton_method(:telnyx_client) { fake_client }

      result = OutboundMessenger::Telnyx.send_mms!(
        agency: @agency,
        to_phone: @client.phone_mobile,
        body: "Your card",
        media_url: "https://example.com/card.pdf",
        request: request
      )

      assert_instance_of MessageLog, result
      assert_equal @client.phone_mobile, result.to_phone
      fake_messages.verify
      fake_client.verify
    end
  end
end
