module Telnyx
  class PhoneProvisioningService
    include Telnyx::Configuration

    def initialize(agency)
      @agency = agency
    end

    def call
      # Idempotency check
      if @agency.phone_sms.present?
        return Result.success(
          "Phone number already provisioned",
          data: { phone_number: @agency.phone_sms }
        )
      end

      configure_telnyx_gem!
      provision_number
    rescue => e
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Error: #{e.message}"

      Result.failure(user_friendly_message(e))
    end

    private

    def provision_number
      phone_number = nil

      ActiveRecord::Base.transaction do
        available_numbers = search_toll_free_numbers

        if available_numbers.empty?
          raise "No toll-free numbers available in your area"
        end

        phone_number = purchase_number(available_numbers.first["phone_number"])

        @agency.update!(
          phone_sms: phone_number,
          live_enabled: true
        )
      end

      Result.success(
        "Phone number provisioned successfully",
        data: { phone_number: phone_number }
      )
    rescue => e
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Provisioning failed: #{e.message}"
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Purchased number (if any): #{phone_number}"

      message = if phone_number.present?
        "Phone number was reserved but setup is incomplete. Please contact support to complete provisioning."
      else
        "Unable to provision phone number. Please contact support."
      end

      Result.failure(message)
    end

    def search_toll_free_numbers
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
      order = ::Telnyx::NumberOrder.create(
        phone_numbers: [ { phone_number: phone_number } ],
        messaging_profile_id: telnyx_messaging_profile_id
      )

      order.data.phone_numbers.first.phone_number
    rescue => e
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Purchase failed: #{e.message}"
      raise "Failed to purchase number: #{e.message}"
    end

    def user_friendly_message(error)
      case error.message
      when /API key/i
        "Phone number provisioning requires Telnyx API credentials. Please contact support."
      when /messaging profile/i
        "Phone number configuration is incomplete. Please contact support."
      when /No toll-free numbers/i, /available in your area/i
        "No toll-free numbers are currently available. Please try again later or contact support."
      else
        "Unable to provision phone number. Please contact support."
      end
    end
  end
end
