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
    update_session_activity
    route_and_respond
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

    # Initialize state for new sessions
    if session.new_record?
      session.state = "awaiting_intent_selection"
      session.context = {}
    end
  end

  def session_expired?
    session.persisted? && session.expires_at && session.expires_at < Time.current
  end

  def handle_session_expiry
    session.context = {}
    session.state = "awaiting_intent_selection"
  end

  def update_session_activity
    session.assign_attributes(
      last_activity_at: Time.current,
      expires_at: Time.current + SESSION_EXPIRY
    )
    session.save!
  end

  def route_and_respond
    case session.state
    when "awaiting_intent_selection"
      handle_intent_selection
    when "awaiting_vehicle_selection", "awaiting_policy_selection"
      handle_in_flow_message
    else
      # Unknown state, reset to menu
      reset_to_menu
    end
  end

  def handle_intent_selection
    body = message_log.body.to_s.strip

    # Handle numeric menu shortcuts
    case body
    when "1"
      transition_to_card_flow
      return
    when "2"
      transition_to_expiration_flow
      return
    when "3"
      send_unsupported_then_menu
      return
    end

    # Route via IntentRouter
    routing = IntentRouter.route(
      body: body,
      state: session.state,
      last_menu_sent_at: session.context["last_menu_sent_at"]
    )

    create_intent_audit(routing)

    case routing[:intent]
    when :insurance_card
      transition_to_card_flow
    when :policy_expiration
      transition_to_expiration_flow
    when :help_or_other
      send_unsupported_then_menu
    when :menu
      send_menu
    else
      send_menu
    end
  end

  def handle_in_flow_message
    body = message_log.body.to_s.strip.downcase

    # Check for menu/cancel commands
    if body == "menu" || body == "cancel" || body == "restart"
      reset_to_menu
      return
    end

    # Route based on current state
    case session.state
    when "awaiting_vehicle_selection"
      handle_vehicle_selection(body)
    when "awaiting_policy_selection"
      # Phase 5: policy expiration selection handling
      send_simple_message(MessageTemplates::IN_FLOW_MENU_GUIDANCE)
    else
      send_simple_message(MessageTemplates::IN_FLOW_MENU_GUIDANCE)
    end
  end

  def handle_vehicle_selection(body)
    options = session.context["options"] || []
    selected = options.find { |opt| opt["key"] == body }

    if selected
      fulfill_insurance_card_request(selected["ref"])
    else
      send_simple_message(MessageTemplates::INVALID_SELECTION)
    end
  end

  def fulfill_insurance_card_request(policy_id)
    contact = Contact.find_by(
      agency_id: message_log.agency_id,
      mobile_phone_e164: message_log.from_phone
    )

    policy = Policy.find(policy_id)

    # Create Request record
    request = Request.create!(
      agency_id: message_log.agency_id,
      contact: contact,
      request_type: "auto_id_card",
      status: "fulfilled",
      fulfilled_at: Time.current,
      selected_ref: policy_id.to_s
    )

    # Find the document with insurance card
    document = policy.documents.find_by(kind: "auto_id_card")
    raise "No insurance card document found for policy #{policy_id}" unless document&.file&.attached?

    # Build media URL
    blob = document.file.blob
    media_url = Rails.application.routes.url_helpers.public_document_url(
      blob.signed_id,
      host: Rails.application.config.action_mailer.default_url_options[:host] || "example.com"
    )

    # Send MMS
    body = MessageTemplates::CARD_DELIVERY % { label: policy.label }
    OutboundMessenger.send_mms!(
      agency: message_log.agency,
      to_phone: message_log.from_phone,
      body: body,
      media_url: media_url,
      request: request
    )

    # Create audit event
    AuditEvent.create!(
      agency_id: message_log.agency_id,
      request: request,
      event_type: "card.request_fulfilled",
      metadata: {
        policy_id: policy_id,
        document_id: document.id,
        contact_id: contact&.id,
        session_id: session.id
      }
    )

    # Transition to complete state
    session.update!(state: "complete", context: {})
  end

  def transition_to_card_flow
    # Resolve Contact
    contact = Contact.find_by(
      agency_id: message_log.agency_id,
      mobile_phone_e164: message_log.from_phone
    )

    unless contact
      # No contact found - send error and return to menu
      send_simple_message("We couldn't find your account. Please contact your agency.")
      reset_to_menu
      return
    end

    # Query auto policies
    policies = contact.policies.where(policy_type: "auto")

    if policies.empty?
      # No policies found
      send_simple_message("No auto policies found on your account. Please contact your agency.")
      reset_to_menu
      return
    end

    # Build options list
    options = policies.map.with_index(1) do |policy, index|
      {
        "key" => index.to_s,
        "ref" => policy.id.to_s,
        "label" => policy.label
      }
    end

    # Update session context
    session.context["options"] = options
    session.context["intent"] = "insurance_card"
    session.update!(state: "awaiting_vehicle_selection")

    # Build and send vehicle menu
    options_text = options.map { |opt| "#{opt['key']}. #{opt['label']}" }.join("\n")
    menu_text = MessageTemplates::CARD_VEHICLE_MENU % { options: options_text }
    send_simple_message(menu_text)
  end

  def transition_to_expiration_flow
    session.update!(state: "awaiting_policy_selection")
    send_simple_message(MessageTemplates::EXPIRE_PLACEHOLDER_PROMPT)
  end

  def send_unsupported_then_menu
    send_simple_message(MessageTemplates::GLOBAL_UNSUPPORTED)
    send_menu
  end

  def reset_to_menu
    session.update!(state: "awaiting_intent_selection")
    send_menu
  end

  def send_simple_message(body)
    OutboundMessenger.send_sms!(
      agency: message_log.agency,
      to_phone: message_log.from_phone,
      body: body
    )
  end

  def send_menu
    # Only update last_menu_sent_at if we're sending the menu
    if should_send_short_menu?
      send_short_menu
    else
      send_full_menu
    end
    update_last_menu_sent_at
    create_menu_audit_event
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

  def create_menu_audit_event
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

  def create_intent_audit(routing)
    AuditEvent.create!(
      agency_id: message_log.agency_id,
      event_type: "conversation.intent_routed",
      metadata: {
        message_log_id: message_log_id,
        intent: routing[:intent].to_s,
        confidence: routing[:confidence],
        reason: routing[:reason],
        normalized_body: message_log.body.to_s.strip.downcase.gsub(/\s+/, " "),
        session_id: session.id
      }
    )
  end
end
