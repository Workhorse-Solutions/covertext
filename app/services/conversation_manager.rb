class ConversationManager
  SESSION_EXPIRY = 15.minutes
  MENU_RATE_LIMIT = 60.seconds

  def self.process_inbound!(message_log_id:)
    new(message_log_id: message_log_id).process!
  end

  def initialize(message_log_id:)
    @message_log_id = message_log_id
  end

  def process!
    load_message_log
    find_or_create_session
    handle_session_expiry if session_expired?
    update_session
    send_menu
    create_audit_event
  end

  private

  attr_reader :message_log_id, :message_log, :session

  def load_message_log
    @message_log = MessageLog.find(message_log_id)
  end

  def find_or_create_session
    @session = ConversationSession.find_or_initialize_by(
      agency_id: message_log.agency_id,
      from_phone_e164: message_log.from_phone
    )
  end

  def session_expired?
    session.persisted? && session.expires_at && session.expires_at < Time.current
  end

  def handle_session_expiry
    session.context = {}
    session.state = "awaiting_intent_selection"
  end

  def update_session
    session.assign_attributes(
      state: "awaiting_intent_selection",
      last_activity_at: Time.current,
      expires_at: Time.current + SESSION_EXPIRY
    )
    session.save!
  end

  def send_menu
    if should_send_short_menu?
      send_short_menu
    else
      send_full_menu
    end
  end

  def should_send_short_menu?
    return false unless session.context["last_menu_sent_at"]

    last_sent = Time.zone.parse(session.context["last_menu_sent_at"])
    Time.current - last_sent < MENU_RATE_LIMIT
  rescue ArgumentError
    false
  end

  def send_full_menu
    OutboundMessenger.send_sms!(
      agency: message_log.agency,
      to_phone: message_log.from_phone,
      body: MessageTemplates::GLOBAL_MENU
    )
    update_last_menu_sent_at
    @menu_template_used = "global.menu"
  end

  def send_short_menu
    OutboundMessenger.send_sms!(
      agency: message_log.agency,
      to_phone: message_log.from_phone,
      body: MessageTemplates::GLOBAL_MENU_SHORT
    )
    @menu_template_used = "global.menu_short"
  end

  def update_last_menu_sent_at
    session.context["last_menu_sent_at"] = Time.current.iso8601
    session.save!
  end

  def create_audit_event
    AuditEvent.create!(
      agency_id: message_log.agency_id,
      event_type: "conversation.menu_sent",
      metadata: {
        message_log_id: message_log_id,
        template: @menu_template_used,
        session_id: session.id
      }
    )
  end
end
