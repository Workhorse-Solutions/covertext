
class UI::PhoneNumberComponent < ViewComponent::Base
  # Renders a formatted US phone number for display.
  #
  # Converts E.164 format (+18775551234) to human-readable: (877) 555-1234
  # Returns the original string for non-US or unparseable numbers.
  #
  # @param number [String, nil] phone number in E.164 or raw digit format
  # @param class_name [String, nil] extra CSS classes for the wrapping <span>
  def initialize(number:, class_name: nil)
    @number = number
    @class_name = class_name
  end

  def call
    tag.span(formatted_number, class: @class_name)
  end

  private

  def formatted_number
    return @number unless @number.is_a?(String)

    digits = @number.gsub(/\D/, "")

    # Strip leading country code (1 for US/CA)
    digits = digits[1..] if digits.length == 11 && digits.start_with?("1")

    if digits.length == 10
      "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
    else
      @number
    end
  end
end
