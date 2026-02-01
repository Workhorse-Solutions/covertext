# frozen_string_literal: true

class RegistrationsController < ApplicationController
  skip_before_action :require_authentication

  def new
    @agency = Agency.new
  end

  def create
    # Create Account first
    @account = Account.new(name: agency_params[:name])

    @agency = @account.agencies.build(agency_params)
    @agency.live_enabled = false # Always start as non-live
    @agency.active = true

    ActiveRecord::Base.transaction do
      @account.save!
      @agency.save!

      # Create owner user for the account
      user = @account.users.create!(
        first_name: params[:user_first_name],
        last_name: params[:user_last_name],
        email: params[:user_email],
        password: params[:user_password],
        password_confirmation: params[:user_password],
        role: "owner"
      )

      # Create Stripe checkout session
      session = Stripe::Checkout::Session.create(
        customer_email: user.email,
        mode: "subscription",
        line_items: [ {
          price: stripe_price_id_for_plan(params[:plan] || "pilot"),
          quantity: 1
        } ],
        success_url: signup_success_url(session_id: "{CHECKOUT_SESSION_ID}"),
        cancel_url: signup_url,
        metadata: {
          account_id: @account.id,
          agency_id: @agency.id,
          user_id: user.id
        },
        subscription_data: {
          metadata: {
            account_id: @account.id
          }
        }
      )

      redirect_to session.url, allow_other_host: true
    end
  rescue ActiveRecord::RecordInvalid => e
    render :new, status: :unprocessable_entity
  rescue Stripe::StripeError => e
    flash[:alert] = "Payment setup failed: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def success
    session_id = params[:session_id]

    begin
      checkout_session = Stripe::Checkout::Session.retrieve(session_id)

      # Get account from metadata (fallback to agency for legacy signups)
      if checkout_session.metadata.account_id
        account = Account.find(checkout_session.metadata.account_id)
      else
        agency = Agency.find(checkout_session.metadata.agency_id)
        account = agency.account
      end

      # Update account with Stripe details
      account.update!(
        stripe_customer_id: checkout_session.customer,
        stripe_subscription_id: checkout_session.subscription,
        subscription_status: "active",
        plan_name: params[:plan] || "pilot"
      )

      # Log the user in
      user = account.users.first
      session[:user_id] = user.id

      redirect_to admin_requests_path, notice: "Welcome to CoverText! Your subscription is active."
    rescue => e
      redirect_to login_path, alert: "Something went wrong. Please contact support."
    end
  end

  private

  def agency_params
    params.require(:agency).permit(:name, :phone_sms)
  end

  def stripe_price_id_for_plan(plan)
    # These should be stored in credentials in production
    case plan
    when "pilot"
      Rails.application.credentials.dig(:stripe, :pilot_price_id) || "price_pilot_placeholder"
    when "growth"
      Rails.application.credentials.dig(:stripe, :growth_price_id) || "price_growth_placeholder"
    else
      Rails.application.credentials.dig(:stripe, :pilot_price_id) || "price_pilot_placeholder"
    end
  end
end
