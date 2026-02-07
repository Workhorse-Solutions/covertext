require "net/http"
require "json"

module Telnyx
  class TollFreeVerification
    BASE_URL = "https://api.telnyx.com/v2/messaging_tollfree/verification/requests"

    class << self
      def submit!(verification)
        api_key = fetch_api_key
        uri = URI(BASE_URL)

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{api_key}"
        request["Content-Type"] = "application/json"
        request.body = verification.payload.to_json

        response = perform_request(uri, request)

        if response.is_a?(Net::HTTPSuccess)
          response_body = JSON.parse(response.body)
          verification.update!(
            telnyx_request_id: response_body.dig("data", "id"),
            status: "submitted",
            submitted_at: Time.current
          )
        else
          verification.update!(
            last_error: "HTTP #{response.code}: #{response.body}"
          )
        end

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

        api_key = fetch_api_key
        uri = URI("#{BASE_URL}/#{verification.telnyx_request_id}")

        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{api_key}"

        response = perform_request(uri, request)

        if response.is_a?(Net::HTTPSuccess)
          response_body = JSON.parse(response.body)
          telnyx_status = response_body.dig("data", "verificationStatus")
          reason = response_body.dig("data", "reason")

          covertext_status = map_telnyx_status(telnyx_status)

          updates = {
            status: covertext_status,
            last_status_at: Time.current
          }
          updates[:last_error] = reason if reason.present?

          verification.update!(updates)
        else
          verification.update!(
            last_error: "HTTP #{response.code}: #{response.body}"
          )
        end

        verification
      rescue StandardError => e
        Rails.logger.error "[Telnyx::TollFreeVerification] Fetch status error: #{e.message}"
        verification.update!(last_error: e.message)
        verification
      end

      private

      def fetch_api_key
        api_key = begin
          Rails.application.credentials.dig(:telnyx, :api_key)
        rescue StandardError
          nil
        end
        api_key ||= ENV["TELNYX_API_KEY"]

        raise "Telnyx API key not configured" unless api_key

        api_key
      end

      def perform_request(uri, request)
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30, open_timeout: 30) do |http|
          http.request(request)
        end
      end

      def map_telnyx_status(telnyx_status)
        case telnyx_status
        when "In Progress", "Waiting For Telnyx", "Waiting For Vendor"
          "in_review"
        when "Waiting For Customer"
          "waiting_for_customer"
        when "Verified"
          "approved"
        when "Rejected"
          "rejected"
        else
          "in_review" # Default fallback
        end
      end
    end
  end
end
