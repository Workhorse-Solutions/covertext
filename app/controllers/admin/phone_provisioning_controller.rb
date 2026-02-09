module Admin
  class PhoneProvisioningController < BaseController
    skip_before_action :require_active_subscription
    before_action :require_owner
    before_action :require_active_subscription_for_provisioning

    def new
      if current_agency.phone_ready?
        redirect_to admin_dashboard_path, notice: "Phone number already provisioned"
        return
      end

      service = Telnyx::PhoneProvisioningService.new(current_agency)
      result = service.search_available_numbers

      if result.success?
        @phone_numbers = result.data[:phone_numbers]
      else
        @phone_numbers = []
        @error = result.message
      end

      render layout: false if turbo_frame_request?
    end

    def create
      if current_agency.phone_ready?
        redirect_to admin_dashboard_path, notice: "Phone number already provisioned"
        return
      end

      phone_number = params[:phone_number]
      unless phone_number.present?
        redirect_to admin_dashboard_path, alert: "Please select a phone number"
        return
      end

      service = Telnyx::PhoneProvisioningService.new(current_agency)
      result = service.provision(phone_number)

      if result.success?
        redirect_to admin_dashboard_path, notice: "Phone number provisioned successfully!"
      else
        redirect_to admin_dashboard_path, alert: result.message
      end
    end

    private

    def require_owner
      unless current_user.role == "owner"
        redirect_to admin_dashboard_path, alert: "Only account owners can provision phone numbers"
      end
    end

    def require_active_subscription_for_provisioning
      unless current_account.subscription_active?
        redirect_to admin_dashboard_path, alert: "An active subscription is required to provision a phone number"
      end
    end
  end
end
