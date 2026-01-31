require "test_helper"

class ConversationManagerHardeningTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:reliable)
    @alice = clients(:alice)

    # Clean up any existing sessions and opt-outs for this test
    ConversationSession.where(from_phone_e164: @alice.phone_mobile).destroy_all
    SmsOptOut.where(phone_e164: @alice.phone_mobile).destroy_all
  end

  # ============================================================================
  # STOP Command Tests
  # ============================================================================

  test "STOP command creates opt-out record and sends confirmation" do
    message_log = create_inbound_message(@alice.phone_mobile, "STOP")

    assert_difference -> { SmsOptOut.count }, 1 do
      ConversationManager.process_inbound!(message_log_id: message_log.id)
    end

    opt_out = SmsOptOut.find_by(agency: @agency, phone_e164: @alice.phone_mobile)
    assert opt_out.present?
    assert opt_out.opted_out_at.present?

    # Verify confirmation SMS sent
    outbound = MessageLog.where(direction: "outbound", to_phone: @alice.phone_mobile).last
    assert_equal MessageTemplates::STOP_CONFIRM, outbound.body

    # Verify audit event
    audit = AuditEvent.where(event_type: "sms.opted_out").last
    assert audit.present?
    assert_equal @alice.phone_mobile, audit.metadata["phone_e164"]
  end

  test "STOP is case-insensitive" do
    [ "stop", "STOP", "Stop", "StOp" ].each do |text|
      SmsOptOut.destroy_all
      message_log = create_inbound_message(@alice.phone_mobile, text)

      assert_difference -> { SmsOptOut.count }, 1 do
        ConversationManager.process_inbound!(message_log_id: message_log.id)
      end
    end
  end

  test "after STOP, subsequent messages are blocked and send opt-out notice" do
    # First, opt out
    stop_message = create_inbound_message(@alice.phone_mobile, "STOP")
    ConversationManager.process_inbound!(message_log_id: stop_message.id)

    # Now try to request insurance card
    card_message = create_inbound_message(@alice.phone_mobile, "insurance card")

    assert_no_difference -> { Request.count } do
      ConversationManager.process_inbound!(message_log_id: card_message.id)
    end

    # Verify block notice sent
    outbound = MessageLog.where(direction: "outbound", to_phone: @alice.phone_mobile).last
    assert_equal MessageTemplates::OPTED_OUT_BLOCK_NOTICE, outbound.body

    # Verify audit event
    audit = AuditEvent.where(event_type: "sms.opted_out_blocked").last
    assert audit.present?
  end

  test "opt-out block notice is sent only once per day" do
    # Create opt-out record
    opt_out = SmsOptOut.create!(
      agency: @agency,
      phone_e164: @alice.phone_mobile,
      opted_out_at: Time.current
    )

    # First message after opt-out - should send notice
    msg1 = create_inbound_message(@alice.phone_mobile, "hello")
    ConversationManager.process_inbound!(message_log_id: msg1.id)

    outbound_count_after_first = MessageLog.where(
      direction: "outbound",
      to_phone: @alice.phone_mobile,
      body: MessageTemplates::OPTED_OUT_BLOCK_NOTICE
    ).count
    assert_equal 1, outbound_count_after_first

    # Second message immediately after - should NOT send another notice
    msg2 = create_inbound_message(@alice.phone_mobile, "hello again")
    ConversationManager.process_inbound!(message_log_id: msg2.id)

    outbound_count_after_second = MessageLog.where(
      direction: "outbound",
      to_phone: @alice.phone_mobile,
      body: MessageTemplates::OPTED_OUT_BLOCK_NOTICE
    ).count
    assert_equal 1, outbound_count_after_second

    # Simulate 25 hours passing
    opt_out.update!(last_block_notice_at: 25.hours.ago)

    # Third message after 25 hours - should send notice again
    msg3 = create_inbound_message(@alice.phone_mobile, "hello third time")
    ConversationManager.process_inbound!(message_log_id: msg3.id)

    outbound_count_after_third = MessageLog.where(
      direction: "outbound",
      to_phone: @alice.phone_mobile,
      body: MessageTemplates::OPTED_OUT_BLOCK_NOTICE
    ).count
    assert_equal 2, outbound_count_after_third
  end

  # ============================================================================
  # START Command Tests
  # ============================================================================

  test "START command removes opt-out and sends re-enabled confirmation" do
    # First opt out
    SmsOptOut.create!(
      agency: @agency,
      phone_e164: @alice.phone_mobile,
      opted_out_at: Time.current
    )

    message_log = create_inbound_message(@alice.phone_mobile, "START")

    assert_difference -> { SmsOptOut.count }, -1 do
      ConversationManager.process_inbound!(message_log_id: message_log.id)
    end

    # Verify confirmation SMS sent
    outbound = MessageLog.where(direction: "outbound", to_phone: @alice.phone_mobile).last
    assert_equal MessageTemplates::START_CONFIRM, outbound.body

    # Verify audit event
    audit = AuditEvent.where(event_type: "sms.opt_in").last
    assert audit.present?
  end

  test "START is case-insensitive" do
    [ "start", "START", "Start", "StArT" ].each do |text|
      SmsOptOut.create!(
        agency: @agency,
        phone_e164: @alice.phone_mobile,
        opted_out_at: Time.current
      )

      message_log = create_inbound_message(@alice.phone_mobile, text)

      assert_difference -> { SmsOptOut.count }, -1 do
        ConversationManager.process_inbound!(message_log_id: message_log.id)
      end
    end
  end

  test "after START, user can use flows again" do
    # Opt out first
    SmsOptOut.create!(
      agency: @agency,
      phone_e164: @alice.phone_mobile,
      opted_out_at: Time.current
    )

    # Opt back in
    start_message = create_inbound_message(@alice.phone_mobile, "START")
    ConversationManager.process_inbound!(message_log_id: start_message.id)

    # Now request insurance card - should work
    card_message = create_inbound_message(@alice.phone_mobile, "insurance card")

    assert_difference -> { ConversationSession.count }, 1 do
      ConversationManager.process_inbound!(message_log_id: card_message.id)
    end

    # Session should be created and in vehicle selection state
    session = ConversationSession.find_by(
      agency: @agency,
      from_phone_e164: @alice.phone_mobile
    )
    assert_equal "awaiting_vehicle_selection", session.state
  end

  # ============================================================================
  # HELP Command Tests
  # ============================================================================

  test "HELP command sends help message and logs audit event" do
    message_log = create_inbound_message(@alice.phone_mobile, "HELP")

    ConversationManager.process_inbound!(message_log_id: message_log.id)

    # Verify help message sent
    outbound = MessageLog.where(direction: "outbound", to_phone: @alice.phone_mobile).last
    assert_equal MessageTemplates::HELP, outbound.body

    # Verify audit event
    audit = AuditEvent.where(event_type: "sms.help_requested").last
    assert audit.present?
  end

  test "HELP is case-insensitive" do
    [ "help", "HELP", "Help", "HeLp" ].each do |text|
      message_log = create_inbound_message(@alice.phone_mobile, text)
      ConversationManager.process_inbound!(message_log_id: message_log.id)

      outbound = MessageLog.where(direction: "outbound", to_phone: @alice.phone_mobile).last
      assert_equal MessageTemplates::HELP, outbound.body
    end
  end

  test "HELP does not create or modify session state" do
    message_log = create_inbound_message(@alice.phone_mobile, "HELP")

    assert_no_difference -> { ConversationSession.count } do
      ConversationManager.process_inbound!(message_log_id: message_log.id)
    end
  end

  # ============================================================================
  # Rate Limiting Tests
  # ============================================================================

  test "11th inbound message within 1 hour triggers rate limit" do
    # Create 10 inbound messages in the last hour
    10.times do |i|
      create_inbound_message(@alice.phone_mobile, "message #{i}", created_at: (60 - i).minutes.ago)
    end

    # 11th message should trigger rate limit
    message_log = create_inbound_message(@alice.phone_mobile, "11th message")

    assert_no_difference -> { Request.count } do
      ConversationManager.process_inbound!(message_log_id: message_log.id)
    end

    # Verify rate limit message sent
    outbound = MessageLog.where(direction: "outbound", to_phone: @alice.phone_mobile).last
    assert_equal MessageTemplates::RATE_LIMITED, outbound.body

    # Verify audit event
    audit = AuditEvent.where(event_type: "sms.rate_limited").last
    assert audit.present?
    assert_equal 11, audit.metadata["recent_count"]
  end

  test "rate limit is per-phone per-agency" do
    bob = clients(:bob)

    # Alice sends 11 messages
    11.times do |i|
      msg = create_inbound_message(@alice.phone_mobile, "alice #{i}")
      ConversationManager.process_inbound!(message_log_id: msg.id) if i < 10
    end

    # Bob should not be rate limited
    bob_message = create_inbound_message(bob.phone_mobile, "MENU")
    ConversationManager.process_inbound!(message_log_id: bob_message.id)

    # Bob should get menu, not rate limit message
    bob_outbound = MessageLog.where(direction: "outbound", to_phone: bob.phone_mobile).last
    assert_not_equal MessageTemplates::RATE_LIMITED, bob_outbound.body
  end

  test "messages older than 1 hour do not count toward rate limit" do
    # Create 10 messages older than 1 hour
    10.times do |i|
      create_inbound_message(@alice.phone_mobile, "old message #{i}", created_at: (61 + i).minutes.ago)
    end

    # Current message should not be rate limited
    message_log = create_inbound_message(@alice.phone_mobile, "MENU")

    assert_difference -> { ConversationSession.count }, 1 do
      ConversationManager.process_inbound!(message_log_id: message_log.id)
    end

    # Should get menu, not rate limit message
    outbound = MessageLog.where(direction: "outbound", to_phone: @alice.phone_mobile).last
    assert_not_equal MessageTemplates::RATE_LIMITED, outbound.body
  end

  test "rate limit blocks session creation and requests" do
    # Create 10 inbound messages
    10.times do |i|
      create_inbound_message(@alice.phone_mobile, "message #{i}")
    end

    # 11th message requesting insurance card
    card_message = create_inbound_message(@alice.phone_mobile, "insurance card")

    assert_no_difference -> { Request.count } do
      assert_no_difference -> { ConversationSession.count } do
        ConversationManager.process_inbound!(message_log_id: card_message.id)
      end
    end
  end

  # ============================================================================
  # Regression Tests: Existing Flows Still Work
  # ============================================================================

  test "insurance card flow still works when not opted out and under rate limit" do
    # Send insurance card request
    message_log = create_inbound_message(@alice.phone_mobile, "insurance card")

    assert_difference -> { ConversationSession.count }, 1 do
      ConversationManager.process_inbound!(message_log_id: message_log.id)
    end

    # Should be in vehicle selection state
    session = ConversationSession.find_by(
      agency: @agency,
      from_phone_e164: @alice.phone_mobile
    )
    assert_equal "awaiting_vehicle_selection", session.state
  end

  test "policy expiration flow still works when not opted out and under rate limit" do
    # Send policy expiration request
    message_log = create_inbound_message(@alice.phone_mobile, "expiring")

    assert_difference -> { ConversationSession.count }, 1 do
      ConversationManager.process_inbound!(message_log_id: message_log.id)
    end

    # Should be in policy selection state
    session = ConversationSession.find_by(
      agency: @agency,
      from_phone_e164: @alice.phone_mobile
    )
    assert_equal "awaiting_policy_selection", session.state
  end

  test "MENU command still works when not opted out and under rate limit" do
    message_log = create_inbound_message(@alice.phone_mobile, "MENU")

    assert_difference -> { ConversationSession.count }, 1 do
      ConversationManager.process_inbound!(message_log_id: message_log.id)
    end

    # Should have received menu
    outbound = MessageLog.where(direction: "outbound", to_phone: @alice.phone_mobile).last
    assert [ MessageTemplates::GLOBAL_MENU, MessageTemplates::GLOBAL_MENU_SHORT ].include?(outbound.body)
  end

  private

  def create_inbound_message(from_phone, body, created_at: Time.current)
    MessageLog.create!(
      agency: @agency,
      direction: "inbound",
      from_phone: from_phone,
      to_phone: @agency.phone_sms,
      body: body,
      provider_message_id: "SM#{SecureRandom.hex(16)}",
      created_at: created_at
    )
  end
end
