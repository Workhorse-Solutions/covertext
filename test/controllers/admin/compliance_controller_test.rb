require "test_helper"

class Admin::ComplianceControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john_owner)
    @agency = agencies(:reliable)
    sign_in(@user)
  end

  test "show renders when no verification exists" do
    get admin_compliance_path

    assert_response :success
    assert_select "h1", text: "Messaging Compliance"
    assert_select "div", text: /Verification Required/i
  end

  test "show renders with verification in draft status" do
    verification = TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: @agency.phone_sms,
      status: "draft"
    )

    get admin_compliance_path

    assert_response :success
    assert_select ".badge", text: /Draft/i
  end

  test "show renders with verification in submitted status" do
    verification = TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: @agency.phone_sms,
      status: "submitted",
      submitted_at: 1.hour.ago
    )

    get admin_compliance_path

    assert_response :success
    assert_select ".badge", text: /In Review/i
    assert_select "div", text: /Submitted/
  end

  test "show renders with verification in in_review status" do
    verification = TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: @agency.phone_sms,
      status: "in_review",
      submitted_at: 1.day.ago,
      last_status_at: 1.hour.ago
    )

    get admin_compliance_path

    assert_response :success
    assert_select ".badge", text: /In Review/i
    assert_select ".alert-info", text: /typically takes 1-5 business days/
  end

  test "show renders with verification in waiting_for_customer status" do
    verification = TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: @agency.phone_sms,
      status: "waiting_for_customer",
      submitted_at: 1.day.ago,
      last_status_at: 1.hour.ago,
      last_error: "Additional documentation required"
    )

    get admin_compliance_path

    assert_response :success
    assert_select ".badge", text: /Action Required/i
    assert_select ".alert-warning", text: /Additional Information Required/
    assert_select ".alert-warning", text: /Additional documentation required/
  end

  test "show renders with verification in approved status" do
    verification = TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: @agency.phone_sms,
      status: "approved",
      submitted_at: 2.days.ago,
      last_status_at: 1.day.ago
    )

    get admin_compliance_path

    assert_response :success
    assert_select ".badge-success", text: /Approved/i
    assert_select ".alert-success", text: /Verification Complete/
    assert_select ".alert-success", text: /ready to send messages/
  end

  test "show renders with verification in rejected status" do
    verification = TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: @agency.phone_sms,
      status: "rejected",
      submitted_at: 2.days.ago,
      last_status_at: 1.day.ago,
      last_error: "Invalid business information provided"
    )

    get admin_compliance_path

    assert_response :success
    assert_select ".badge-error", text: /Rejected/i
    assert_select ".alert-error", text: /Verification Rejected/
    assert_select ".alert-error", text: /Invalid business information provided/
  end

  test "show displays agency phone number" do
    get admin_compliance_path

    assert_response :success
    assert_select "div", text: @agency.phone_sms
  end

  test "show displays most recent verification when multiple exist" do
    old_verification = TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: "+18885551111",
      status: "rejected",
      created_at: 2.days.ago
    )

    new_verification = TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: @agency.phone_sms,
      status: "approved",
      created_at: 1.day.ago
    )

    get admin_compliance_path

    assert_response :success
    # Should show the newer verification's status
    assert_select ".badge-success", text: /Approved/i
  end

  test "show displays warning when agency has no phone_sms" do
    @agency.update!(phone_sms: nil)

    get admin_compliance_path

    assert_response :success
    assert_select ".alert-warning", text: /No Toll-Free Number Assigned/
    assert_select ".alert-warning", text: /contact support/i
  end

  test "show requires authentication" do
    sign_out

    get admin_compliance_path

    assert_redirected_to login_path
  end

  test "show requires active subscription" do
    @user.account.update!(subscription_status: "canceled")

    get admin_compliance_path

    assert_redirected_to admin_billing_path
  end
end
