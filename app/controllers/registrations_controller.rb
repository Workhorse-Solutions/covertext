# frozen_string_literal: true

class RegistrationsController < ApplicationController
  skip_before_action :require_authentication

  def new
    @agency = Agency.new
  end

  def create
    @agency = Agency.new(agency_params)
    @agency.live_enabled = false # Always start as non-live

    if @agency.save
      # Create default user for the agency
      user = @agency.users.create!(
        first_name: params[:user_first_name],
        last_name: params[:user_last_name],
        email: params[:user_email],
        password: params[:user_password],
        password_confirmation: params[:user_password],
        role: "admin"
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
          agency_id: @agency.id,
          user_id: user.id
        },
        subscription_data: {
          metadata: {
            agency_id: @agency.id
          }
        }
      )

      redirect_to session.url, allow_other_host: true
    else
      render :new, status: :unprocessable_entity
    end
  rescue Stripe::StripeError => e
    flash[:alert] = "Payment setup failed: #{e.message}"
    render :new, status: :unprocessable_entity
  end

  def success
    session_id = params[:session_id]

    begin
      checkout_session = Stripe::Checkout::Session.retrieve(session_id)
      agency_id = checkout_session.metadata.agency_id
      agency = Agency.find(agency_id)

      # Update agency with Stripe details
      agency.update!(
        stripe_customer_id: checkout_session.customer,
        stripe_subscription_id: checkout_session.subscription,
        subscription_status: "active",
        plan_name: params[:plan] || "pilot"
      )

      # Log the user in
      user = agency.users.first
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
