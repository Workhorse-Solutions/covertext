# frozen_string_literal: true

module Admin
  class AccountsController < BaseController
    before_action :require_owner

    def show
      @account = current_account
      @agencies = @account.agencies.order(:name)
    end

    def update
      @account = current_account
      @agencies = @account.agencies.order(:name)

      if @account.update(account_params)
        redirect_to admin_account_path, notice: "Account updated successfully."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def require_owner
      unless current_user.role == "owner"
        redirect_to admin_requests_path, alert: "Only account owners can access account settings."
      end
    end

    def account_params
      params.require(:account).permit(:name)
    end
  end
end
