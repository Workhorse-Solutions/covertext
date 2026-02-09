
class RegistrationsController < ApplicationController
  skip_before_action :require_authentication

  # Valid billing intervals
  BILLING_INTERVALS = [ :monthly, :yearly ].freeze

  def new
    @selected_plan = selected_plan_from_params
    @selected_interval = selected_interval_from_params
    @plan_info = Plan.info(@selected_plan, @selected_interval)
  end

  def create
    plan = selected_plan_from_params
    interval = selected_interval_from_params
    account_name = params[:account_name]
    agency_name = params[:agency_name]

    # Basic validation
    if account_name.blank? || agency_name.blank?
      @selected_plan = plan
      @selected_interval = interval
      @plan_info = Plan.info(@selected_plan, @selected_interval)
      flash.now[:alert] = "Account and Agency names are required"
      render :new, status: :unprocessable_entity
      return
    end

    # Create Stripe checkout session with business data only (not sensitive)
    stripe_session = Stripe::Checkout::Session.create(
      mode: "subscription",
      line_items: [ {
        price: stripe_price_id_for_plan(plan, interval),
        quantity: 1
      } ],
      phone_number_collection: { enabled: true },
      custom_fields: [
        {
          key: Forms::Registration::FIRST_NAME_FIELD,
          label: { type: "custom", custom: "First Name" },
          type: "text"
        },
        {
          key: Forms::Registration::LAST_NAME_FIELD,
          label: { type: "custom", custom: "Last Name" },
          type: "text"
        }
      ],
      success_url: "#{signup_success_url}?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: signup_url(plan: plan, interval: interval),
      metadata: {
        account_name: account_name,
        agency_name: agency_name,
        plan_tier: plan.to_s,
        billing_interval: interval.to_s
      }
    )

    redirect_to stripe_session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    @selected_plan = selected_plan_from_params
    @selected_interval = selected_interval_from_params
    @plan_info = Plan.info(@selected_plan, @selected_interval)
    flash.now[:alert] = "Payment setup failed: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def success
    session_id = params[:session_id]

    unless session_id.present?
      redirect_to signup_path, alert: "Invalid session. Please start over."
      return
    end

    begin
      # Retrieve Stripe checkout session and create registration for display
      checkout_session = Stripe::Checkout::Session.retrieve(session_id)

      # FormObject extracts all display data from checkout_session
      @registration = Forms::Registration.new(checkout_session: checkout_session)
      @session_id = session_id
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error during signup success: #{e.message}"
      redirect_to signup_path, alert: "Something went wrong. Please try again."
    rescue StandardError => e
      Rails.logger.error "Unexpected error during signup success: #{e.message}"
      redirect_to signup_path, alert: "Something went wrong. Please contact support."
    end
  end

  def complete
    session_id = params[:session_id]

    unless session_id.present?
      redirect_to signup_path, alert: "Invalid session. Please start over."
      return
    end

    begin
      # Retrieve Stripe checkout session to get all account data
      checkout_session = Stripe::Checkout::Session.retrieve(session_id)

      # Create registration with checkout session and password params only
      # FormObject extracts account/agency/user data from Stripe
      registration = Forms::Registration.new(
        checkout_session: checkout_session,
        password_params: password_params
      )

      if registration.save
        # Log the user in
        session[:user_id] = registration.user.id
        redirect_to admin_requests_path, notice: "Welcome to CoverText! Your subscription is active."
      else
        # Re-display form with errors
        @session_id = session_id
        @registration = registration
        flash.now[:alert] = registration.errors.full_messages.join(", ")
        render :success, status: :unprocessable_entity
      end
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error during signup completion: #{e.message}"
      redirect_to signup_path, alert: "Invalid session. Please start over."
    rescue StandardError => e
      Rails.logger.error "Unexpected error during signup completion: #{e.message}"
      redirect_to signup_path, alert: "Something went wrong. Please contact support."
    end
  end

  private

  def password_params
    params.permit(:password, :password_confirmation)
  end

  def selected_plan_from_params
    plan = params[:plan]&.to_sym
    Plan.valid?(plan) ? plan : Plan.default
  end

  def selected_interval_from_params
    interval = params[:interval]&.to_sym
    BILLING_INTERVALS.include?(interval) ? interval : :yearly
  end

  def stripe_price_id_for_plan(plan, interval = :yearly)
    # Build credential key: starter_monthly_price_id, professional_yearly_price_id, etc.
    key = "#{plan}_#{interval}_price_id".to_sym

    Rails.application.credentials.dig(:stripe, key) || "price_#{plan}_#{interval}_placeholder"
  end
end
