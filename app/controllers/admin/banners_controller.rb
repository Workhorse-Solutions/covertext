module Admin
  class BannersController < BaseController
    skip_before_action :require_active_subscription

    def dismiss_grace_period
      session[:grace_period_banner_dismissed] = true
      head :ok
    end
  end
end
