module Admin
  class ComplianceController < BaseController
    def show
      @verification = current_agency.telnyx_toll_free_verifications
                                     .order(created_at: :desc)
                                     .first
    end

    def new
      # Guard: must have phone_sms
      unless current_agency.phone_sms.present?
        redirect_to admin_compliance_path, alert: "A toll-free number must be assigned before submitting verification."
        return
      end

      # Guard: cannot have an active verification already
      if active_verification_exists?
        redirect_to admin_compliance_path, alert: "A verification request is already in progress."
        return
      end

      @verification = current_agency.telnyx_toll_free_verifications.build
    end

    def create
      # Guard: must have phone_sms
      unless current_agency.phone_sms.present?
        redirect_to admin_compliance_path, alert: "A toll-free number must be assigned before submitting verification."
        return
      end

      # Guard: cannot have an active verification already (idempotency check)
      if active_verification_exists?
        redirect_to admin_compliance_path, alert: "A verification request is already in progress."
        return
      end

      # Build payload from form params
      business_info = extract_business_info(verification_params)

      # Create a temporary verification object to build the payload
      temp_verification = current_agency.telnyx_toll_free_verifications.build(
        telnyx_number: current_agency.phone_sms
      )

      payload = Telnyx::TollFreeVerificationPayload.build(
        temp_verification,
        business_info: business_info
      )

      # Destroy old draft/rejected verifications to allow resubmission
      current_agency.telnyx_toll_free_verifications
                    .where(telnyx_number: current_agency.phone_sms)
                    .where(status: [ "draft", "rejected" ])
                    .destroy_all

      # Create verification record
      @verification = current_agency.telnyx_toll_free_verifications.build(
        telnyx_number: current_agency.phone_sms,
        status: "draft",
        payload: payload
      )

      if @verification.save
        # Enqueue background job to submit to Telnyx
        SubmitTelnyxTollFreeVerificationJob.perform_later(@verification.id)

        redirect_to admin_compliance_path, notice: "Verification request submitted successfully. Status will update shortly."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def active_verification_exists?
      current_agency.telnyx_toll_free_verifications
                    .where.not(status: [ "rejected", "draft" ])
                    .exists?
    end

    def verification_params
      params.require(:telnyx_toll_free_verification).permit(
        :business_name,
        :corporate_website,
        :contact_first_name,
        :contact_last_name,
        :contact_email,
        :contact_phone,
        :address1,
        :address2,
        :city,
        :state,
        :zip,
        :country,
        :business_registration_number,
        :business_registration_type,
        :entity_type
      )
    end

    def extract_business_info(params)
      {
        business_name: params[:business_name],
        corporate_website: params[:corporate_website],
        contact_first_name: params[:contact_first_name],
        contact_last_name: params[:contact_last_name],
        contact_email: params[:contact_email],
        contact_phone: params[:contact_phone],
        address1: params[:address1],
        address2: params[:address2],
        city: params[:city],
        state: params[:state],
        zip: params[:zip],
        country: params[:country] || "US",
        business_registration_number: params[:business_registration_number],
        business_registration_type: params[:business_registration_type] || "EIN",
        entity_type: params[:entity_type] || "PRIVATE_PROFIT"
      }
    end
  end
end
