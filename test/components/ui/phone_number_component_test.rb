require "test_helper"

class UI::PhoneNumberComponentTest < ViewComponent::TestCase
  test "formats US toll-free number with country code" do
    render_inline(UI::PhoneNumberComponent.new(number: "+18775551234"))

    assert_selector "span", text: "(877) 555-1234"
  end

  test "formats US number with country code" do
    render_inline(UI::PhoneNumberComponent.new(number: "+15551234567"))

    assert_selector "span", text: "(555) 123-4567"
  end

  test "formats 10-digit number without country code" do
    render_inline(UI::PhoneNumberComponent.new(number: "8005559876"))

    assert_selector "span", text: "(800) 555-9876"
  end

  test "returns original string for non-standard length" do
    render_inline(UI::PhoneNumberComponent.new(number: "+442071234567"))

    assert_selector "span", text: "+442071234567"
  end

  test "handles nil number" do
    render_inline(UI::PhoneNumberComponent.new(number: nil))

    assert_selector "span", text: ""
  end

  test "handles empty string" do
    render_inline(UI::PhoneNumberComponent.new(number: ""))

    assert_selector "span", text: ""
  end

  test "applies custom class_name" do
    render_inline(UI::PhoneNumberComponent.new(number: "+18775551234", class_name: "font-mono text-lg"))

    assert_selector "span.font-mono.text-lg", text: "(877) 555-1234"
  end
end
