require "test_helper"

module Webhooks
  class StripeWebhooksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @account = accounts(:reliable_group)
      @account.update!(
        stripe_customer_id: "cus_test_123",
        stripe_subscription_id: "sub_test_123",
        subscription_status: "active"
      )
      @agency = agencies(:reliable)
    end

    test "handles subscription updated event" do
      skip "Requires proper Stripe webhook signature mocking - TODO: implement with proper test credentials"
    end

    test "handles payment succeeded event" do
      skip "Requires proper Stripe webhook signature mocking - TODO: implement with proper test credentials"
    end

    test "handles payment failed event" do
      skip "Requires proper Stripe webhook signature mocking - TODO: implement with proper test credentials"
    end
  end

  class StripeWebhooksControllerUnitTest < ActiveSupport::TestCase
    setup do
      @account = accounts(:reliable_group)
      @account.update!(
        stripe_customer_id: "cus_test_123",
        stripe_subscription_id: "sub_test_123",
        subscription_status: "active"
      )
      @controller = StripeWebhooksController.new
    end

    test "handle_subscription_update updates account status" do
      subscription = OpenStruct.new(
        id: "sub_test_123",
        status: "past_due",
        metadata: OpenStruct.new(plan_name: nil),
        cancel_at_period_end: false
      )

      @controller.send(:handle_subscription_update, subscription)

      @account.reload
      assert_equal "past_due", @account.subscription_status
    end

    test "handle_subscription_update sets canceled when cancel_at_period_end" do
      subscription = OpenStruct.new(
        id: "sub_test_123",
        status: "active",
        metadata: OpenStruct.new(plan_name: nil),
        cancel_at_period_end: true
      )

      @controller.send(:handle_subscription_update, subscription)

      @account.reload
      assert_equal "canceled", @account.subscription_status
    end

    test "handle_subscription_update finds account by metadata when subscription ID not stored yet" do
      new_account = Account.create!(name: "New Account")

      subscription = OpenStruct.new(
        id: "sub_new_123",
        status: "active",
        metadata: OpenStruct.new(account_id: new_account.id.to_s, plan_name: "pilot"),
        cancel_at_period_end: false
      )

      @controller.send(:handle_subscription_update, subscription)

      new_account.reload
      assert_equal "active", new_account.subscription_status
      assert_equal "pilot", new_account.plan_name
    end

    test "handle_payment_success updates account to active" do
      @account.update!(subscription_status: "past_due")

      invoice = OpenStruct.new(subscription: "sub_test_123")

      @controller.send(:handle_payment_success, invoice)

      @account.reload
      assert_equal "active", @account.subscription_status
    end

    test "handle_payment_failure updates account to past_due" do
      invoice = OpenStruct.new(subscription: "sub_test_123")

      @controller.send(:handle_payment_failure, invoice)

      @account.reload
      assert_equal "past_due", @account.subscription_status
    end

    test "handle_subscription_update does nothing for unknown subscription" do
      subscription = OpenStruct.new(
        id: "sub_unknown_123",
        status: "active",
        metadata: OpenStruct.new(account_id: nil, plan_name: nil),
        cancel_at_period_end: false
      )

      assert_nothing_raised do
        @controller.send(:handle_subscription_update, subscription)
      end
    end

    test "handle_payment_failure does nothing for unknown subscription" do
      invoice = OpenStruct.new(subscription: "sub_unknown_123")

      assert_nothing_raised do
        @controller.send(:handle_payment_failure, invoice)
      end
    end
  end
end
