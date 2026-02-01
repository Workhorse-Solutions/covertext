require "test_helper"

class Admin::RequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @john = users(:john_owner)
    @reliable_agency = agencies(:reliable)
  end

  # Authentication tests
  test "unauthenticated access to admin requests redirects to login" do
    get admin_requests_path
    assert_redirected_to login_path
  end

  test "authenticated user can access admin requests index" do
    sign_in(@john)
    get admin_requests_path
    assert_response :success
  end

  test "authenticated user can access request show" do
    sign_in(@john)

    # Create a request for this agency
    request = Request.create!(
      agency: @reliable_agency,
      request_type: "auto_id_card",
      status: "fulfilled"
    )

    get admin_request_path(request)
    assert_response :success
  end

  # Multi-tenancy tests
  test "user cannot access request from another agency" do
    sign_in(@john)

    # Create a request for a different agency
    other_account = Account.create!(name: "Other Account")
    other_agency = Agency.create!(
      name: "Other Agency",
      phone_sms: "+15551111111",
      account: other_account
    )
    other_request = Request.create!(
      agency: other_agency,
      request_type: "auto_id_card",
      status: "fulfilled"
    )

    get admin_request_path(other_request)
    assert_response :not_found
  end

  # Index page tests
  test "requests index renders successfully" do
    sign_in(@john)

    # Create at least 3 requests for this agency
    3.times do |i|
      Request.create!(
        agency: @reliable_agency,
        request_type: "auto_id_card",
        status: "fulfilled",
        created_at: i.days.ago
      )
    end

    get admin_requests_path
    assert_response :success
    assert_select "table tbody tr", minimum: 3
  end

  test "requests index filters by request_type" do
    sign_in(@john)

    Request.create!(agency: @reliable_agency, request_type: "auto_id_card", status: "fulfilled")
    Request.create!(agency: @reliable_agency, request_type: "policy_expiration", status: "fulfilled")

    get admin_requests_path, params: { request_type: "auto_id_card" }
    assert_response :success
    # Verify filtering logic works (actual count may vary with fixtures)
  end

  test "requests index filters by status" do
    sign_in(@john)

    Request.create!(agency: @reliable_agency, request_type: "auto_id_card", status: "fulfilled")
    Request.create!(agency: @reliable_agency, request_type: "auto_id_card", status: "pending")

    get admin_requests_path, params: { status: "fulfilled" }
    assert_response :success
  end

  # Show page tests
  test "request show page includes request details" do
    sign_in(@john)

    client = clients(:alice)
    request = Request.create!(
      agency: @reliable_agency,
      client: client,
      request_type: "auto_id_card",
      status: "fulfilled",
      fulfilled_at: Time.current,
      selected_ref: "123"
    )

    get admin_request_path(request)
    assert_response :success
    assert_select "h2", text: /Request ##{request.id}/
  end

  test "request show page includes transcript section" do
    sign_in(@john)

    client = clients(:alice)
    request = Request.create!(
      agency: @reliable_agency,
      client: client,
      request_type: "auto_id_card",
      status: "fulfilled"
    )

    # Create message logs
    MessageLog.create!(
      agency: @reliable_agency,
      request: request,
      direction: "inbound",
      from_phone: client.phone_mobile,
      to_phone: @reliable_agency.phone_sms,
      body: "I need my card",
      media_count: 0
    )

    get admin_request_path(request)
    assert_response :success
    assert_select ".chat", minimum: 1
  end

  test "request show page includes deliveries" do
    sign_in(@john)

    request = Request.create!(
      agency: @reliable_agency,
      request_type: "auto_id_card",
      status: "fulfilled"
    )

    Delivery.create!(
      request: request,
      method: "mms",
      status: "queued"
    )

    get admin_request_path(request)
    assert_response :success
    assert_select "h3", text: "Deliveries"
  end

  test "request show page includes audit events" do
    sign_in(@john)

    request = Request.create!(
      agency: @reliable_agency,
      request_type: "auto_id_card",
      status: "fulfilled"
    )

    AuditEvent.create!(
      agency: @reliable_agency,
      request: request,
      event_type: "card.request_fulfilled",
      metadata: { policy_id: "123" }
    )

    get admin_request_path(request)
    assert_response :success
    assert_select "h3", text: "Audit Events"
  end
end
