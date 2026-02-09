require "test_helper"

class Agency::ReadinessTest < ActiveSupport::TestCase
  test "subscription_ready? returns true when account has active subscription" do
    agency = agencies(:reliable)
    agency.account.update!(subscription_status: "active")

    assert agency.subscription_ready?
  end

  test "subscription_ready? returns false when account has inactive subscription" do
    agency = agencies(:reliable)
    agency.account.update!(subscription_status: "canceled")

    assert_not agency.subscription_ready?
  end

  test "phone_ready? returns true when phone_sms is present" do
    agency = agencies(:reliable)
    agency.update!(phone_sms: "+15551234567")

    assert agency.phone_ready?
  end

  test "phone_ready? returns false when phone_sms is nil" do
    agency = agencies(:reliable)
    agency.update!(phone_sms: nil)

    assert_not agency.phone_ready?
  end

  test "fully_ready? returns true when both subscription and phone are ready" do
    agency = agencies(:reliable)
    agency.account.update!(subscription_status: "active")
    agency.update!(phone_sms: "+15551234567")

    # Create an active verification to satisfy verification_ready?
    TelnyxTollFreeVerification.create!(
      agency: agency,
      telnyx_number: "+15551234567",
      status: "submitted"
    )

    assert agency.fully_ready?
  end

  test "fully_ready? returns false when subscription is not ready" do
    agency = agencies(:reliable)
    agency.account.update!(subscription_status: "canceled")
    agency.update!(phone_sms: "+15551234567")

    assert_not agency.fully_ready?
  end

  test "fully_ready? returns false when phone is not ready" do
    agency = agencies(:reliable)
    agency.account.update!(subscription_status: "active")
    agency.update!(phone_sms: nil)

    assert_not agency.fully_ready?
  end

  test "fully_ready? returns false when neither is ready" do
    agency = agencies(:reliable)
    agency.account.update!(subscription_status: "canceled")
    agency.update!(phone_sms: nil)

    assert_not agency.fully_ready?
  end

  test "fully_ready? returns false when verification is not ready" do
    agency = agencies(:reliable)
    agency.account.update!(subscription_status: "active")
    agency.update!(phone_sms: "+15551234567")

    # No verification submitted
    assert_not agency.fully_ready?
  end

  # --- verification_ready? ---

  test "verification_ready? returns true when active verification exists" do
    agency = agencies(:reliable)
    agency.update!(phone_sms: "+15551234567")

    TelnyxTollFreeVerification.create!(
      agency: agency,
      telnyx_number: "+15551234567",
      status: "in_review"
    )

    assert agency.verification_ready?
  end

  test "verification_ready? returns false when no verification exists" do
    agency = agencies(:reliable)
    agency.update!(phone_sms: "+15551234567")

    assert_not agency.verification_ready?
  end

  test "verification_ready? returns false for draft verification" do
    agency = agencies(:reliable)
    agency.update!(phone_sms: "+15551234567")

    TelnyxTollFreeVerification.create!(
      agency: agency,
      telnyx_number: "+15551234567",
      status: "draft"
    )

    assert_not agency.verification_ready?
  end

  test "verification_ready? returns false for rejected verification" do
    agency = agencies(:reliable)
    agency.update!(phone_sms: "+15551234567")

    TelnyxTollFreeVerification.create!(
      agency: agency,
      telnyx_number: "+15551234567",
      status: "rejected"
    )

    assert_not agency.verification_ready?
  end

  test "verification_ready? returns false when phone is not ready" do
    agency = agencies(:reliable)
    agency.update!(phone_sms: nil)

    assert_not agency.verification_ready?
  end
end
