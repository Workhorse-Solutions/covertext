# frozen_string_literal: true

class RegistrationsController < ApplicationController
  skip_before_action :require_authentication

  def new
    @agency = Agency.new
  end

  def create
    # Get selected plan, validate and default to starter
    plan = params[:plan]&.to_sym
    plan = Plan.default unless Plan.valid?(plan)

    # Create Account first
    @account = Account.new(
      name: agency_params[:name],
      plan_tier: plan
    )

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
          price: stripe_price_id_for_plan(plan),
          quantity: 1
        } ],
        success_url: signup_success_url(session_id: "{CHECKOUT_SESSION_ID}", plan: plan),
        cancel_url: signup_url(plan: plan),
        metadata: {
          account_id: @account.id,
          agency_id: @agency.id,
          user_id: user.id,
          plan_tier: plan
        },
        subscription_data: {
          metadata: {
            account_id: @account.id,
            plan_tier: plan
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
      plan_tier = checkout_session.metadata.plan_tier&.to_sym
      plan_tier = Plan.default unless Plan.valid?(plan_tier)

      account.update!(
        stripe_customer_id: checkout_session.customer,
        stripe_subscription_id: checkout_session.subscription,
        subscription_status: "active",
        plan_tier: plan_tier
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
    case plan.to_sym
    when :starter
      Rails.application.credentials.dig(:stripe, :starter_price_id) || "price_starter_placeholder"
    when :professional
      Rails.application.credentials.dig(:stripe, :professional_price_id) || "price_professional_placeholder"
    when :enterprise
      Rails.application.credentials.dig(:stripe, :enterprise_price_id) || "price_enterprise_placeholder"
    else
      # Default to starter
      Rails.application.credentials.dig(:stripe, :starter_price_id) || "price_starter_placeholder"
    end
  end
end
