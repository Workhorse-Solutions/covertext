module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_authentication

    private

    def current_agency
      @current_agency ||= current_user.agency
    end
    helper_method :current_agency
  end
end
