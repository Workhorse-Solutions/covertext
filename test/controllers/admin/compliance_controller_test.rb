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

  # New action tests
  test "new renders form when phone_sms is present and no active verification" do
    get admin_new_compliance_verification_path

    assert_response :success
    assert_select "h1", text: "Submit Toll-Free Verification"
    assert_select "form[action=?]", admin_compliance_verifications_path
  end

  test "new redirects when no phone_sms" do
    @agency.update!(phone_sms: nil)

    get admin_new_compliance_verification_path

    assert_redirected_to admin_compliance_path
    assert_equal "A toll-free number must be assigned before submitting verification.", flash[:alert]
  end

  test "new redirects when active verification already exists" do
    TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: @agency.phone_sms,
      status: "submitted"
    )

    get admin_new_compliance_verification_path

    assert_redirected_to admin_compliance_path
    assert_equal "A verification request is already in progress.", flash[:alert]
  end

  test "new allows new submission when previous verification was rejected" do
    TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: @agency.phone_sms,
      status: "rejected"
    )

    get admin_new_compliance_verification_path

    assert_response :success
  end

  # Create action tests
  test "create submits verification and enqueues job" do
    assert_difference "TelnyxTollFreeVerification.count", 1 do
      assert_enqueued_with(job: SubmitTelnyxTollFreeVerificationJob) do
        post admin_compliance_verifications_path, params: {
          telnyx_toll_free_verification: {
            business_name: "Reliable Insurance",
            corporate_website: "https://reliableinsurance.example",
            contact_first_name: "John",
            contact_last_name: "Doe",
            contact_email: "john@example.com",
            contact_phone: "+18005551234",
            address1: "123 Main St",
            address2: "",
            city: "Denver",
            state: "Colorado",
            zip: "80202",
            country: "US",
            business_registration_number: "12-3456789",
            business_registration_type: "EIN",
            entity_type: "PRIVATE_PROFIT"
          }
        }
      end
    end

    assert_redirected_to admin_compliance_path
    assert_equal "Verification request submitted successfully. Status will update shortly.", flash[:notice]

    verification = TelnyxTollFreeVerification.last
    assert_equal @agency, verification.agency
    assert_equal @agency.phone_sms, verification.telnyx_number
    assert_equal "draft", verification.status
    assert verification.payload.present?
  end

  test "create redirects when no phone_sms" do
    @agency.update!(phone_sms: nil)

    assert_no_difference "TelnyxTollFreeVerification.count" do
      post admin_compliance_verifications_path, params: {
        telnyx_toll_free_verification: { business_name: "Test" }
      }
    end

    assert_redirected_to admin_compliance_path
    assert_equal "A toll-free number must be assigned before submitting verification.", flash[:alert]
  end

  test "create prevents duplicate submissions (idempotency)" do
    TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: @agency.phone_sms,
      status: "submitted"
    )

    assert_no_difference "TelnyxTollFreeVerification.count" do
      post admin_compliance_verifications_path, params: {
        telnyx_toll_free_verification: {
          business_name: "Reliable Insurance",
          corporate_website: "https://example.com",
          contact_first_name: "John",
          contact_last_name: "Doe",
          contact_email: "john@example.com",
          contact_phone: "+18005551234",
          address1: "123 Main St",
          city: "Denver",
          state: "Colorado",
          zip: "80202"
        }
      }
    end

    assert_redirected_to admin_compliance_path
    assert_equal "A verification request is already in progress.", flash[:alert]
  end

  test "create allows resubmission after rejection" do
    rejected_verification = TelnyxTollFreeVerification.create!(
      agency: @agency,
      telnyx_number: @agency.phone_sms,
      status: "rejected"
    )

    # Old rejected verification is replaced, so count stays the same
    assert_no_difference "TelnyxTollFreeVerification.count" do
      post admin_compliance_verifications_path, params: {
        telnyx_toll_free_verification: {
          business_name: "Reliable Insurance",
          corporate_website: "https://reliableinsurance.example",
          contact_first_name: "John",
          contact_last_name: "Doe",
          contact_email: "john@example.com",
          contact_phone: "+18005551234",
          address1: "123 Main St",
          city: "Denver",
          state: "Colorado",
          zip: "80202"
        }
      }
    end

    assert_redirected_to admin_compliance_path

    # Verify the old rejected verification was replaced
    assert_not TelnyxTollFreeVerification.exists?(rejected_verification.id)
    assert_equal "draft", @agency.telnyx_toll_free_verifications.last.status
  end
end
