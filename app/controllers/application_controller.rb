class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_authentication

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

  def current_account
    current_user&.account
  end
  helper_method :current_account

  def require_authentication
    redirect_to login_path, alert: "Please log in to continue" unless current_user
  end

  def require_active_subscription
    return unless current_account

    unless current_account.can_access_system?
      if !current_account.subscription_active?
        redirect_to admin_billing_path, alert: "Your subscription is inactive. Please update your billing to continue."
      elsif !current_account.has_active_agency?
        redirect_to admin_billing_path, alert: "No active agencies found. Please contact support to set up your agency."
      end
    end
  end
end
