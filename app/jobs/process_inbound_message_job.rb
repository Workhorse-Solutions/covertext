class ProcessInboundMessageJob < ApplicationJob
  queue_as :default

  def perform(message_log_id)
    # TODO: Phase 2 - Implement conversation session logic
    # For Phase 1, this is just a stub
    message_log = MessageLog.find(message_log_id)
    Rails.logger.info "ProcessInboundMessageJob: Received message_log_id=#{message_log_id}"
  end
end
