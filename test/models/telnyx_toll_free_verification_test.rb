require "test_helper"

class TelnyxTollFreeVerificationTest < ActiveSupport::TestCase
  test "valid verification" do
    agency = agencies(:reliable)
    verification = TelnyxTollFreeVerification.new(
      agency: agency,
      telnyx_number: "+18885551234",
      status: "draft"
    )
    assert verification.valid?
  end

  test "requires agency" do
    verification = TelnyxTollFreeVerification.new(telnyx_number: "+18885551234")
    assert_not verification.valid?
    assert_includes verification.errors[:agency], "must exist"
  end

  test "requires telnyx_number" do
    verification = TelnyxTollFreeVerification.new(agency: agencies(:reliable))
    assert_not verification.valid?
    assert_includes verification.errors[:telnyx_number], "can't be blank"
  end

  test "requires unique telnyx_number scoped to agency" do
    agency = agencies(:reliable)
    TelnyxTollFreeVerification.create!(
      agency: agency,
      telnyx_number: "+18885551234",
      status: "draft"
    )

    duplicate = TelnyxTollFreeVerification.new(
      agency: agency,
      telnyx_number: "+18885551234"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:telnyx_number], "has already been taken"
  end

  test "allows same number for different agencies" do
    verification1 = TelnyxTollFreeVerification.create!(
      agency: agencies(:reliable),
      telnyx_number: "+18885551234",
      status: "draft"
    )

    verification2 = TelnyxTollFreeVerification.new(
      agency: agencies(:acme),
      telnyx_number: "+18885551234"
    )
    assert verification2.valid?
  end

  test "validates status inclusion" do
    verification = TelnyxTollFreeVerification.new(
      agency: agencies(:reliable),
      telnyx_number: "+18885551234",
      status: "invalid_status"
    )
    assert_not verification.valid?
    assert_includes verification.errors[:status], "is not included in the list"
  end

  test "defaults status to draft" do
    verification = TelnyxTollFreeVerification.create!(
      agency: agencies(:reliable),
      telnyx_number: "+18885551234"
    )
    assert_equal "draft", verification.status
  end

  test "defaults payload to empty hash" do
    verification = TelnyxTollFreeVerification.create!(
      agency: agencies(:reliable),
      telnyx_number: "+18885551234"
    )
    assert_equal({}, verification.payload)
  end

  test "draft? predicate" do
    verification = TelnyxTollFreeVerification.new(status: "draft")
    assert verification.draft?
    verification.status = "submitted"
    assert_not verification.draft?
  end

  test "submitted? predicate" do
    verification = TelnyxTollFreeVerification.new(status: "submitted")
    assert verification.submitted?
    verification.status = "draft"
    assert_not verification.submitted?
  end

  test "in_review? predicate" do
    verification = TelnyxTollFreeVerification.new(status: "in_review")
    assert verification.in_review?
    verification.status = "draft"
    assert_not verification.in_review?
  end

  test "waiting_for_customer? predicate" do
    verification = TelnyxTollFreeVerification.new(status: "waiting_for_customer")
    assert verification.waiting_for_customer?
    verification.status = "draft"
    assert_not verification.waiting_for_customer?
  end

  test "approved? predicate" do
    verification = TelnyxTollFreeVerification.new(status: "approved")
    assert verification.approved?
    verification.status = "draft"
    assert_not verification.approved?
  end

  test "rejected? predicate" do
    verification = TelnyxTollFreeVerification.new(status: "rejected")
    assert verification.rejected?
    verification.status = "draft"
    assert_not verification.rejected?
  end

  test "terminal? returns true for approved" do
    verification = TelnyxTollFreeVerification.new(status: "approved")
    assert verification.terminal?
  end

  test "terminal? returns true for rejected" do
    verification = TelnyxTollFreeVerification.new(status: "rejected")
    assert verification.terminal?
  end

  test "terminal? returns false for non-terminal statuses" do
    %w[draft submitted in_review waiting_for_customer].each do |status|
      verification = TelnyxTollFreeVerification.new(status: status)
      assert_not verification.terminal?, "Expected status '#{status}' to not be terminal"
    end
  end

  test "STATUSES constant contains all valid statuses" do
    expected = %w[draft submitted in_review waiting_for_customer approved rejected]
    assert_equal expected, TelnyxTollFreeVerification::STATUSES
  end
end
