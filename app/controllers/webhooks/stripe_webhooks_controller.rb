# frozen_string_literal: true

module Webhooks
  class StripeWebhooksController < ApplicationController
    skip_before_action :require_authentication
    skip_before_action :verify_authenticity_token

    def create
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
      endpoint_secret = Rails.application.credentials.dig(:stripe, :webhook_secret)

      begin
        event = Stripe::Webhook.construct_event(
          payload, sig_header, endpoint_secret
        )
      rescue JSON::ParserError, Stripe::SignatureVerificationError => e
        render json: { error: "Invalid webhook" }, status: :bad_request
        return
      end

      # Handle the event
      case event.type
      when "customer.subscription.updated", "customer.subscription.deleted"
        handle_subscription_update(event.data.object)
      when "invoice.payment_succeeded"
        handle_payment_success(event.data.object)
      when "invoice.payment_failed"
        handle_payment_failure(event.data.object)
      end

      render json: { received: true }, status: :ok
    end

    private

    def handle_subscription_update(subscription)
      account = find_account_for_subscription(subscription)
      return unless account

      status = subscription.status
      if subscription.respond_to?(:cancel_at_period_end) && subscription.cancel_at_period_end
        status = "canceled"
      end

      # Map Stripe price ID to plan tier
      plan_tier = plan_tier_from_subscription(subscription)

      account.update!(
        subscription_status: status,
        plan_tier: plan_tier
      )

      Rails.logger.info "Updated subscription for account #{account.id}: #{status}, tier: #{plan_tier}"
    end

    def handle_payment_success(invoice)
      return unless invoice.subscription

      account = Account.find_by(stripe_subscription_id: invoice.subscription)
      return unless account

      account.update!(subscription_status: "active")
      Rails.logger.info "Payment succeeded for account #{account.id}"
    end

    def handle_payment_failure(invoice)
      return unless invoice.subscription

      account = Account.find_by(stripe_subscription_id: invoice.subscription)
      return unless account

      account.update!(subscription_status: "past_due")
      Rails.logger.warn "Payment failed for account #{account.id}"
    end

    def find_account_for_subscription(subscription)
      # First try to find by subscription ID
      account = Account.find_by(stripe_subscription_id: subscription.id)
      return account if account

      # Fallback: find by account_id in metadata (for new subscriptions)
      if subscription.metadata&.account_id
        Account.find_by(id: subscription.metadata.account_id)
      end
    end

    def plan_tier_from_subscription(subscription)
      # First check metadata (set during checkout)
      if subscription.metadata&.plan_tier
        tier = subscription.metadata.plan_tier.to_sym
        return tier if Plan.valid?(tier)
      end

      # Fallback: map price ID to tier
      price_id = subscription.items.data.first&.price&.id
      return Plan.default unless price_id

      starter_id = Rails.application.credentials.dig(:stripe, :starter_price_id)
      professional_id = Rails.application.credentials.dig(:stripe, :professional_price_id)
      enterprise_id = Rails.application.credentials.dig(:stripe, :enterprise_price_id)

      case price_id
      when starter_id
        :starter
      when professional_id
        :professional
      when enterprise_id
        :enterprise
      else
        Plan.default
      end
    end
  end
end
