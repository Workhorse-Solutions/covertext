# frozen_string_literal: true

module Admin
  class BillingController < BaseController
    skip_before_action :require_active_subscription

    def show
      @account = current_account
      @agency = current_agency

      if @account&.stripe_customer_id
        @portal_session = Stripe::BillingPortal::Session.create(
          customer: @account.stripe_customer_id,
          return_url: admin_billing_url
        )
      end
    rescue Stripe::StripeError => e
      flash.now[:alert] = "Unable to load billing information: #{e.message}"
    end
  end
end
