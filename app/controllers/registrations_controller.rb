# frozen_string_literal: true

class RegistrationsController < ApplicationController
  skip_before_action :require_authentication

  def new
    @registration = RegistrationForm.new
    @selected_plan = selected_plan_from_params
    @plan_info = Plan.info(@selected_plan)
  end

  def create
    # Get selected plan, validate and default to starter
    plan = params[:plan]&.to_sym
    plan = Plan.default unless Plan.valid?(plan)

    @registration = RegistrationForm.new(
      account_name: params[:registration]&.dig(:account_name),
      plan_tier: plan.to_s,
      agency_name: params[:registration]&.dig(:agency_name),

      user_first_name: params[:registration]&.dig(:user_first_name),
      user_last_name: params[:registration]&.dig(:user_last_name),
      user_email: params[:registration]&.dig(:user_email),
      user_password: params[:registration]&.dig(:user_password)
    )

    if @registration.save
      # Create Stripe checkout session
      session = Stripe::Checkout::Session.create(
        customer_email: @registration.user.email,
        mode: "subscription",
        line_items: [ {
          price: stripe_price_id_for_plan(plan),
          quantity: 1
        } ],
        success_url: signup_success_url(session_id: "{CHECKOUT_SESSION_ID}", plan: plan),
        cancel_url: signup_url(plan: plan),
        metadata: {
          account_id: @registration.account.id,
          agency_id: @registration.agency.id,
          user_id: @registration.user.id,
          plan_tier: plan
        },
        subscription_data: {
          metadata: {
            account_id: @registration.account.id,
            plan_tier: plan
          }
        }
      )

      redirect_to session.url, allow_other_host: true
    else
      @selected_plan = selected_plan_from_params
      @plan_info = Plan.info(@selected_plan)
      render :new, status: :unprocessable_entity
    end
  rescue Stripe::StripeError => e
    @selected_plan = selected_plan_from_params
    @plan_info = Plan.info(@selected_plan)
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

  def selected_plan_from_params
    plan = params[:plan]&.to_sym
    Plan.valid?(plan) ? plan : Plan.default
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
