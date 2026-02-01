module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_authentication
    before_action :require_active_subscription

    private

    def current_agency
      @current_agency ||= current_user.account.agencies.where(active: true).first
    end
    helper_method :current_agency
  end
end
