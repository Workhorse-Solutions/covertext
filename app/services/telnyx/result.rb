module Telnyx
  # Shared result value object for all Telnyx service operations.
  # Provides a consistent interface for success/failure reporting
  # across PhoneProvisioningService, TollFreeVerification, etc.
  #
  # Usage:
  #   Result.success("It worked!", data: { phone_number: "+18001234567" })
  #   Result.failure("Something broke")
  class Result
    attr_reader :message, :data

    def initialize(success:, message:, data: {})
      @success = success
      @message = message
      @data = data
    end

    def success?
      @success
    end

    # Convenience factory methods
    def self.success(message, data: {})
      new(success: true, message: message, data: data)
    end

    def self.failure(message, data: {})
      new(success: false, message: message, data: data)
    end

    # Backwards compatibility: allow result.phone_number for PhoneProvisioningService
    def phone_number
      data[:phone_number]
    end
  end
end
