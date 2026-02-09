require "test_helper"

module Admin
  class PhoneProvisioningControllerTest < ActionDispatch::IntegrationTest
    setup do
      @owner = users(:john_owner)
      @agency = agencies(:not_ready)
      @agency.update!(account: @owner.account)

      # Deactivate other agencies so current_agency returns @agency
      @owner.account.agencies.where.not(id: @agency.id).update_all(active: false)

      # Set test credentials
      ENV["TELNYX_API_KEY"] = "test_api_key"
      ENV["TELNYX_MESSAGING_PROFILE_ID"] = "test_profile_id"
    end

    # --- Authentication & Authorization ---

    test "new requires authentication" do
      get admin_new_phone_provisioning_path
      assert_redirected_to login_path
    end

    test "create requires authentication" do
      post admin_phone_provisioning_path, params: { phone_number: "+18005551234" }
      assert_redirected_to login_path
    end

    test "new requires owner role" do
      admin = User.create!(
        account: @owner.account,
        first_name: "Admin",
        last_name: "User",
        email: "admin@test.com",
        password: "password123",
        role: "admin"
      )
      sign_in(admin)

      get admin_new_phone_provisioning_path
      assert_redirected_to admin_dashboard_path
      assert_equal "Only account owners can provision phone numbers", flash[:alert]
    end

    test "create requires owner role" do
      admin = User.create!(
        account: @owner.account,
        first_name: "Admin",
        last_name: "User",
        email: "admin@test.com",
        password: "password123",
        role: "admin"
      )
      sign_in(admin)

      post admin_phone_provisioning_path, params: { phone_number: "+18005551234" }
      assert_redirected_to admin_dashboard_path
      assert_equal "Only account owners can provision phone numbers", flash[:alert]
    end

    test "new rejects if subscription not active" do
      @owner.account.update!(subscription_status: "canceled")
      sign_in(@owner)

      get admin_new_phone_provisioning_path
      assert_redirected_to admin_dashboard_path
      assert_equal "An active subscription is required to provision a phone number", flash[:alert]
    end

    test "create rejects if subscription not active" do
      @owner.account.update!(subscription_status: "canceled")
      sign_in(@owner)

      post admin_phone_provisioning_path, params: { phone_number: "+18005551234" }
      assert_redirected_to admin_dashboard_path
      assert_equal "An active subscription is required to provision a phone number", flash[:alert]
    end

    # --- GET new (phone number selection) ---

    test "new returns available phone numbers" do
      sign_in(@owner)

      stub_search_service([ "+18005551234", "+18775559876" ])

      get admin_new_phone_provisioning_path
      assert_response :success
      assert_match "(800) 555-1234", response.body
      assert_match "(877) 555-9876", response.body
    end

    test "new redirects if phone already provisioned" do
      @agency.update!(phone_sms: "+18001234567")
      sign_in(@owner)

      get admin_new_phone_provisioning_path
      assert_redirected_to admin_dashboard_path
    end

    test "new shows error when search fails" do
      sign_in(@owner)

      stub_search_service([], error: "No toll-free numbers are currently available.")

      get admin_new_phone_provisioning_path
      assert_response :success
      assert_match "No toll-free numbers", response.body
    end

    # --- POST create (provision selected number) ---

    test "provisions selected phone number on success" do
      sign_in(@owner)

      stub_provision_service("+18005551234", success: true)

      post admin_phone_provisioning_path, params: { phone_number: "+18005551234" }

      assert_redirected_to admin_dashboard_path
      assert_equal "Phone number provisioned successfully!", flash[:notice]
    end

    test "displays error message on provisioning failure" do
      sign_in(@owner)

      stub_provision_service("+18005551234", success: false, message: "Unable to provision phone number. Please contact support.")

      post admin_phone_provisioning_path, params: { phone_number: "+18005551234" }

      assert_redirected_to admin_dashboard_path
      assert_equal "Unable to provision phone number. Please contact support.", flash[:alert]
    end

    test "create rejects if no phone number selected" do
      sign_in(@owner)

      post admin_phone_provisioning_path
      assert_redirected_to admin_dashboard_path
      assert_equal "Please select a phone number", flash[:alert]
    end

    test "create redirects if phone already provisioned" do
      @agency.update!(phone_sms: "+18001234567")
      sign_in(@owner)

      post admin_phone_provisioning_path, params: { phone_number: "+18005551234" }
      assert_redirected_to admin_dashboard_path
      assert_equal "Phone number already provisioned", flash[:notice]
    end

    private

    def stub_search_service(numbers, error: nil)
      service_instance = Telnyx::PhoneProvisioningService.new(@agency)

      if error
        service_instance.define_singleton_method(:search_available_numbers) do |limit: 10|
          Telnyx::Result.failure(error)
        end
      else
        service_instance.define_singleton_method(:search_available_numbers) do |limit: 10|
          Telnyx::Result.success("Found #{numbers.size} available numbers", data: { phone_numbers: numbers })
        end
      end

      Telnyx::PhoneProvisioningService.define_singleton_method(:new) do |agency|
        service_instance
      end
    end

    def stub_provision_service(phone_number, success:, message: nil)
      service_instance = Telnyx::PhoneProvisioningService.new(@agency)

      if success
        service_instance.define_singleton_method(:provision) do |number|
          Telnyx::Result.success("Phone number provisioned successfully", data: { phone_number: number })
        end
      else
        service_instance.define_singleton_method(:provision) do |number|
          Telnyx::Result.failure(message || "Unable to provision phone number. Please contact support.")
        end
      end

      Telnyx::PhoneProvisioningService.define_singleton_method(:new) do |agency|
        service_instance
      end
    end
  end
end
