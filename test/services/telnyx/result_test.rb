require "test_helper"

class Telnyx::ResultTest < ActiveSupport::TestCase
  test "success? returns true for successful results" do
    result = Telnyx::Result.success("It worked!")

    assert result.success?
    assert_equal "It worked!", result.message
  end

  test "success? returns false for failed results" do
    result = Telnyx::Result.failure("Something broke")

    assert_not result.success?
    assert_equal "Something broke", result.message
  end

  test "data defaults to empty hash" do
    result = Telnyx::Result.success("OK")

    assert_equal({}, result.data)
  end

  test "data can be populated" do
    result = Telnyx::Result.success("OK", data: { phone_number: "+18001234567" })

    assert_equal "+18001234567", result.data[:phone_number]
  end

  test "phone_number convenience method reads from data" do
    result = Telnyx::Result.success("OK", data: { phone_number: "+18001234567" })

    assert_equal "+18001234567", result.phone_number
  end

  test "phone_number returns nil when not in data" do
    result = Telnyx::Result.success("OK")

    assert_nil result.phone_number
  end

  test "constructor accepts keyword arguments" do
    result = Telnyx::Result.new(success: true, message: "Hello", data: { foo: "bar" })

    assert result.success?
    assert_equal "Hello", result.message
    assert_equal "bar", result.data[:foo]
  end
end
