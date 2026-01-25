class ProcessInboundMessageJob < ApplicationJob
  queue_as :default

  def perform(message_log_id)
    ConversationManager.process_inbound!(message_log_id: message_log_id)
  end
end
