module Admin
  class ComplianceController < BaseController
    def show
      @verification = current_agency.telnyx_toll_free_verifications
                                     .order(created_at: :desc)
                                     .first
    end
  end
end
