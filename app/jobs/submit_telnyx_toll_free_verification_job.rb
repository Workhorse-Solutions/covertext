class SubmitTelnyxTollFreeVerificationJob < ApplicationJob
  queue_as :default

  def perform(verification_id)
    verification = TelnyxTollFreeVerification.find(verification_id)

    # Only submit if still in draft status (idempotency check)
    return unless verification.draft?

    # Call the Telnyx API service to submit
    Telnyx::TollFreeVerification.submit!(verification)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("SubmitTelnyxTollFreeVerificationJob: Verification #{verification_id} not found")
  rescue StandardError => e
    Rails.logger.error("SubmitTelnyxTollFreeVerificationJob: #{e.class} - #{e.message}")
    verification&.update(last_error: e.message) if verification
  end
end
