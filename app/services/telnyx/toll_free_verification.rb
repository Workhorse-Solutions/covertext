module Telnyx
  class TollFreeVerification
    class << self
      include ::Telnyx::Configuration

      def submit!(verification)
        client = telnyx_client
        response = client.messaging_tollfree.verification.requests.create(verification.payload)

        verification.update!(
          telnyx_request_id: response.id,
          status: "submitted",
          submitted_at: Time.current
        )

        verification
      rescue StandardError => e
        Rails.logger.error "[Telnyx::TollFreeVerification] Submit error: #{e.message}"
        verification.update!(last_error: e.message)
        verification
      end

      def fetch_status!(verification)
        unless verification.telnyx_request_id
          verification.update!(last_error: "Cannot fetch status: telnyx_request_id is missing")
          return verification
        end

        client = telnyx_client
        response = client.messaging_tollfree.verification.requests.retrieve(verification.telnyx_request_id)

        updates = {
          status: map_telnyx_status(response.verification_status),
          last_status_at: Time.current
        }
        updates[:last_error] = response.reason if response.reason.present?

        verification.update!(updates)
        verification
      rescue StandardError => e
        Rails.logger.error "[Telnyx::TollFreeVerification] Fetch status error: #{e.message}"
        verification.update!(last_error: e.message)
        verification
      end

      private

      def map_telnyx_status(telnyx_status)
        case telnyx_status.to_s
        when "In Progress", "Waiting For Telnyx", "Waiting For Vendor"
          "in_review"
        when "Waiting For Customer"
          "waiting_for_customer"
        when "Verified"
          "approved"
        when "Rejected"
          "rejected"
        else
          "in_review"
        end
      end
    end
  end
end
