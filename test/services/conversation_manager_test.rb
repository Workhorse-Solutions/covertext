require "test_helper"

class ConversationManagerTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:reliable)
    @from_phone = "+15559876543"
  end

  test "creates ConversationSession on first inbound message" do
    inbound_log = create_inbound_message(@from_phone, "Hello")

    assert_difference "ConversationSession.count", 1 do
      ConversationManager.process_inbound!(message_log_id: inbound_log.id)
    end

    session = ConversationSession.last
    assert_equal @agency.id, session.agency_id
    assert_equal @from_phone, session.from_phone_e164
    assert_equal "awaiting_intent_selection", session.state
    assert_not_nil session.last_activity_at
    assert_not_nil session.expires_at
  end

  test "creates outbound MessageLog with menu text" do
    inbound_log = create_inbound_message(@from_phone, "Hi")

    assert_difference "MessageLog.where(direction: 'outbound').count", 1 do
      ConversationManager.process_inbound!(message_log_id: inbound_log.id)
    end

    outbound = MessageLog.where(direction: "outbound").last
    assert_equal @agency.id, outbound.agency_id
    assert_equal @agency.sms_phone_number, outbound.from_phone
    assert_equal @from_phone, outbound.to_phone
    assert_includes outbound.body, "Welcome to CoverText"
    assert_includes outbound.body, "CARD"
    assert_includes outbound.body, "EXPIRING"
  end

  test "updates existing session on subsequent messages" do
    inbound_log1 = create_inbound_message(@from_phone, "First")
    ConversationManager.process_inbound!(message_log_id: inbound_log1.id)

    session = ConversationSession.last
    original_id = session.id
    first_activity = session.last_activity_at

    travel 5.minutes do
      inbound_log2 = create_inbound_message(@from_phone, "Second")

      assert_no_difference "ConversationSession.count" do
        ConversationManager.process_inbound!(message_log_id: inbound_log2.id)
      end

      session.reload
      assert_equal original_id, session.id
      assert session.last_activity_at > first_activity
    end
  end

  test "resets expired session context and state" do
    # Create session that expires in the past
    session = ConversationSession.create!(
      agency: @agency,
      from_phone_e164: @from_phone,
      state: "some_other_state",
      context: { "old_data" => "should_be_cleared" },
      last_activity_at: 20.minutes.ago,
      expires_at: 5.minutes.ago
    )

    inbound_log = create_inbound_message(@from_phone, "New message")
    ConversationManager.process_inbound!(message_log_id: inbound_log.id)

    session.reload
    assert_equal "awaiting_intent_selection", session.state
    assert session.context.present? # Has last_menu_sent_at now
    assert_not_equal "should_be_cleared", session.context["old_data"]
  end

  test "sends short menu when menu was sent recently" do
    inbound_log1 = create_inbound_message(@from_phone, "First")
    ConversationManager.process_inbound!(message_log_id: inbound_log1.id)

    first_outbound = MessageLog.where(direction: "outbound").last
    assert_includes first_outbound.body, "Welcome to CoverText"

    # Send another message within 60 seconds
    travel 30.seconds do
      inbound_log2 = create_inbound_message(@from_phone, "Second")
      ConversationManager.process_inbound!(message_log_id: inbound_log2.id)

      second_outbound = MessageLog.where(direction: "outbound").last
      assert_equal "Reply: CARD, EXPIRING, or HELP", second_outbound.body
      assert_not_includes second_outbound.body, "Welcome"
    end
  end

  test "sends full menu when menu was sent more than 60 seconds ago" do
    inbound_log1 = create_inbound_message(@from_phone, "First")
    ConversationManager.process_inbound!(message_log_id: inbound_log1.id)

    # Send another message after 61 seconds
    travel 61.seconds do
      inbound_log2 = create_inbound_message(@from_phone, "Second")
      ConversationManager.process_inbound!(message_log_id: inbound_log2.id)

      second_outbound = MessageLog.where(direction: "outbound").last
      assert_includes second_outbound.body, "Welcome to CoverText"
    end
  end

  test "creates AuditEvent for menu sent" do
    inbound_log = create_inbound_message(@from_phone, "Test")

    assert_difference "AuditEvent.count", 1 do
      ConversationManager.process_inbound!(message_log_id: inbound_log.id)
    end

    audit = AuditEvent.last
    assert_equal @agency.id, audit.agency_id
    assert_equal "conversation.menu_sent", audit.event_type
    assert_equal inbound_log.id, audit.metadata["message_log_id"]
    assert_equal "global.menu", audit.metadata["template"]
  end

  test "AuditEvent shows short menu template when applicable" do
    inbound_log1 = create_inbound_message(@from_phone, "First")
    ConversationManager.process_inbound!(message_log_id: inbound_log1.id)

    travel 30.seconds do
      inbound_log2 = create_inbound_message(@from_phone, "Second")
      ConversationManager.process_inbound!(message_log_id: inbound_log2.id)

      audit = AuditEvent.last
      assert_equal "global.menu_short", audit.metadata["template"]
    end
  end

  test "session expires_at is 15 minutes from now" do
    freeze_time do
      inbound_log = create_inbound_message(@from_phone, "Test")
      ConversationManager.process_inbound!(message_log_id: inbound_log.id)

      session = ConversationSession.last
      expected_expiry = Time.current + 15.minutes

      assert_in_delta expected_expiry, session.expires_at, 1.second
    end
  end

  private

  def create_inbound_message(from_phone, body)
    MessageLog.create!(
      agency: @agency,
      direction: "inbound",
      from_phone: from_phone,
      to_phone: @agency.sms_phone_number,
      body: body,
      provider_message_id: "SM#{SecureRandom.hex(16)}",
      media_count: 0
    )
  end
end
