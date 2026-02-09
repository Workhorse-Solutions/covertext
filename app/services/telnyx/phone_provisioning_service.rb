module Telnyx
  class PhoneProvisioningService
    class Result
      attr_reader :success, :message, :phone_number

      def initialize(success:, message:, phone_number: nil)
        @success = success
        @message = message
        @phone_number = phone_number
      end

      def success?
        @success
      end
    end

    def initialize(agency)
      @agency = agency
    end

    def call
      # Idempotency check
      if @agency.phone_sms.present?
        return Result.new(
          success: true,
          message: "Phone number already provisioned",
          phone_number: @agency.phone_sms
        )
      end

      # Configure Telnyx gem with credentials
      configure_telnyx!

      # Purchase and configure number
      provision_number
    rescue => e
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Error: #{e.message}"

      # Return user-friendly error message
      user_message = case e.message
      when /API key/i
        "Phone number provisioning requires Telnyx API credentials. Please contact support."
      when /messaging profile/i
        "Phone number configuration is incomplete. Please contact support."
      when /No toll-free numbers/i
        "No toll-free numbers are currently available. Please try again later or contact support."
      when /available in your area/i
        "No toll-free numbers are currently available. Please try again later or contact support."
      else
        "Unable to provision phone number. Please contact support."
      end

      Result.new(
        success: false,
        message: user_message
      )
    end

    private

    def provision_number
      phone_number = nil

      ActiveRecord::Base.transaction do
        # Search for available toll-free numbers
        available_numbers = search_toll_free_numbers

        if available_numbers.empty?
          raise "No toll-free numbers available in your area"
        end

        # Purchase the first available number
        phone_number = purchase_number(available_numbers.first["phone_number"])

        # Add number to messaging profile
        add_to_messaging_profile(phone_number)

        # Update agency
        @agency.update!(
          phone_sms: phone_number,
          live_enabled: true
        )
      end

      Result.new(
        success: true,
        message: "Phone number provisioned successfully",
        phone_number: phone_number
      )
    rescue => e
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Provisioning failed: #{e.message}"
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Purchased number (if any): #{phone_number}"

      # Log full error for debugging but return user-friendly message
      user_message = if phone_number.present?
        "Phone number was reserved but setup is incomplete. Please contact support to complete provisioning."
      else
        "Unable to provision phone number. Please contact support."
      end

      Result.new(
        success: false,
        message: user_message
      )
    end

    def search_toll_free_numbers
      # Search for available toll-free numbers in US
      # API: GET /v2/available_phone_numbers
      # Docs: https://developers.telnyx.com/api-reference/phone-number-search/list-available-phone-numbers

      response = ::Telnyx::AvailablePhoneNumber.list(
        filter: {
          phone_number_type: "toll_free",
          country_code: "US",
          features: "sms",
          limit: 5
        }
      )

      response.data
    rescue => e
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Search failed: #{e.message}"
      raise "Failed to search for available numbers: #{e.message}"
    end

    def purchase_number(phone_number)
      # Purchase number and assign to messaging profile in one API call
      # API: POST /v2/number_orders
      # Docs: https://developers.telnyx.com/api-reference/phone-number-orders/create-a-number-order

      messaging_profile_id = Rails.application.credentials.dig(:telnyx, :messaging_profile_id) ||
                             ENV["TELNYX_MESSAGING_PROFILE_ID"]

      unless messaging_profile_id
        raise "Telnyx messaging profile ID not configured"
      end

      order = ::Telnyx::NumberOrder.create(
        phone_numbers: [ { phone_number: phone_number } ],
        messaging_profile_id: messaging_profile_id
      )

      # Return the purchased phone number
      order.data.phone_numbers.first.phone_number
    rescue => e
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Purchase failed: #{e.message}"
      raise "Failed to purchase number: #{e.message}"
    end

    def add_to_messaging_profile(phone_number)
      # No longer needed - number is associated with messaging profile during purchase
      # The messaging_profile_id is passed in the NumberOrder.create call
      true
    end

    def configure_telnyx!
      # Get API key from credentials or ENV
      api_key = Rails.application.credentials.dig(:telnyx, :api_key) || ENV["TELNYX_API_KEY"]
      messaging_profile_id = Rails.application.credentials.dig(:telnyx, :messaging_profile_id) ||
                             ENV["TELNYX_MESSAGING_PROFILE_ID"]

      unless api_key
        raise "Telnyx API key not configured. Please set it in Rails credentials or ENV."
      end

      unless messaging_profile_id
        raise "Telnyx messaging profile ID not configured. Please set it in Rails credentials or ENV."
      end

      # Configure Telnyx gem
      ::Telnyx.api_key = api_key
    end
  end
end
