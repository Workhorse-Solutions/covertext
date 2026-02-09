module Telnyx
  class PhoneProvisioningService
    include Telnyx::Configuration

    def initialize(agency)
      @agency = agency
    end

    # Search for available toll-free numbers. Returns a Result with
    # data: { phone_numbers: ["+18005551234", ...] } on success.
    def search_available_numbers(limit: 10)
      client = telnyx_client
      response = client.available_phone_numbers.list(
        "filter[phone_number_type]" => "toll_free",
        "filter[country_code]" => "US",
        "filter[features]" => "sms",
        "filter[limit]" => limit
      )

      numbers = response.data.map(&:phone_number)

      if numbers.empty?
        Result.failure("No toll-free numbers are currently available. Please try again later.")
      else
        Result.success("Found #{numbers.size} available numbers", data: { phone_numbers: numbers })
      end
    rescue => e
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Search failed: #{e.message}"
      Result.failure(user_friendly_message(e))
    end

    # Provision a specific phone number chosen by the user.
    def provision(phone_number)
      if @agency.phone_sms.present?
        return Result.success(
          "Phone number already provisioned",
          data: { phone_number: @agency.phone_sms }
        )
      end

      purchase_and_assign(phone_number)
    rescue => e
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Error: #{e.message}"
      Result.failure(user_friendly_message(e))
    end

    private

    def purchase_and_assign(phone_number)
      purchased_number = nil

      ActiveRecord::Base.transaction do
        purchased_number = purchase_number(phone_number)

        @agency.update!(
          phone_sms: purchased_number,
          live_enabled: true
        )
      end

      Result.success(
        "Phone number provisioned successfully",
        data: { phone_number: purchased_number }
      )
    rescue => e
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Provisioning failed: #{e.message}"
      Rails.logger.error "[Telnyx::PhoneProvisioningService] Purchased number (if any): #{purchased_number}"

      message = if purchased_number.present?
        "Phone number was reserved but setup is incomplete. Please contact support to complete provisioning."
      else
        "Unable to provision phone number. Please contact support."
      end

      Result.failure(message)
    end

    def purchase_number(phone_number)
      client = telnyx_client
      order = client.number_orders.create(
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
