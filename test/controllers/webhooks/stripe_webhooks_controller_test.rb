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

      # Save original method
      @original_construct_event = Stripe::Webhook.method(:construct_event)
    end

    teardown do
      # Restore original method if it was replaced
      if @stubbed_event
        Stripe::Webhook.define_singleton_method(:construct_event) do |*args|
          @original_construct_event.call(*args)
        end
      end
    end

    # Test 1: checkout.session.completed
    test "handles checkout.session.completed event" do
      event_data = to_deep_ostruct({
        customer: "cus_new_456",
        subscription: "sub_new_456",
        metadata: { account_id: @account.id.to_s }
      })

      stub_webhook_event("checkout.session.completed", event_data)
      post webhooks_stripe_path, params: {}, headers: { "HTTP_STRIPE_SIGNATURE" => "test_sig" }

      assert_response :success
      assert_equal({ "received" => true }, JSON.parse(response.body))

      @account.reload
      assert_equal "cus_new_456", @account.stripe_customer_id
      assert_equal "sub_new_456", @account.stripe_subscription_id
    end

    # Test 2: customer.subscription.created
    test "handles customer.subscription.created event" do
      new_account = Account.create!(name: "Test Account")

      event_data = to_deep_ostruct({
        id: "sub_created_789",
        status: "active",
        metadata: { account_id: new_account.id.to_s, plan_tier: "professional" },
        cancel_at_period_end: false,
        items: { data: [ { price: { id: "price_pro_test" } } ] }
      })

      stub_webhook_event("customer.subscription.created", event_data)
      post webhooks_stripe_path, params: {}, headers: { "HTTP_STRIPE_SIGNATURE" => "test_sig" }

      assert_response :success
      new_account.reload
      assert_equal "active", new_account.subscription_status
      assert new_account.professional?
    end

    # Test 3: customer.subscription.updated
    test "handles customer.subscription.updated event" do
      event_data = to_deep_ostruct({
        id: "sub_test_123",
        status: "past_due",
        metadata: { plan_tier: "starter" },
        cancel_at_period_end: false,
        items: { data: [ { price: { id: "price_starter_test" } } ] }
      })

      stub_webhook_event("customer.subscription.updated", event_data)
      post webhooks_stripe_path, params: {}, headers: { "HTTP_STRIPE_SIGNATURE" => "test_sig" }

      assert_response :success
      @account.reload
      assert_equal "past_due", @account.subscription_status
      assert @account.starter?
    end

    # Test 4: customer.subscription.deleted
    test "handles customer.subscription.deleted event" do
      event_data = to_deep_ostruct({
        id: "sub_test_123",
        status: "canceled",
        metadata: { plan_tier: "starter" },
        cancel_at_period_end: true,
        items: { data: [ { price: { id: "price_starter_test" } } ] }
      })

      stub_webhook_event("customer.subscription.deleted", event_data)
      post webhooks_stripe_path, params: {}, headers: { "HTTP_STRIPE_SIGNATURE" => "test_sig" }

      assert_response :success
      @account.reload
      assert_equal "canceled", @account.subscription_status
    end

    # Test 5: invoice.payment_succeeded
    test "handles invoice.payment_succeeded event" do
      @account.update!(subscription_status: "past_due")

      event_data = to_deep_ostruct({
        subscription: "sub_test_123"
      })

      stub_webhook_event("invoice.payment_succeeded", event_data)
      post webhooks_stripe_path, params: {}, headers: { "HTTP_STRIPE_SIGNATURE" => "test_sig" }

      assert_response :success
      @account.reload
      assert_equal "active", @account.subscription_status
    end

    # Test 6: invoice.payment_failed
    test "handles invoice.payment_failed event" do
      event_data = to_deep_ostruct({
        subscription: "sub_test_123"
      })

      stub_webhook_event("invoice.payment_failed", event_data)
      post webhooks_stripe_path, params: {}, headers: { "HTTP_STRIPE_SIGNATURE" => "test_sig" }

      assert_response :success
      @account.reload
      assert_equal "past_due", @account.subscription_status
    end

    # Error handling tests
    test "returns 400 for invalid signature" do
      stub_webhook_error(Stripe::SignatureVerificationError.new("Invalid signature", "sig"))
      post webhooks_stripe_path, params: {}, headers: { "HTTP_STRIPE_SIGNATURE" => "invalid_sig" }

      assert_response :bad_request
      assert_equal({ "error" => "Invalid webhook" }, JSON.parse(response.body))
    end

    test "returns 400 for malformed JSON" do
      stub_webhook_error(JSON::ParserError.new("Invalid JSON"))
      post webhooks_stripe_path, params: {}, headers: { "HTTP_STRIPE_SIGNATURE" => "test_sig" }

      assert_response :bad_request
      assert_equal({ "error" => "Invalid webhook" }, JSON.parse(response.body))
    end

    private

    def stub_webhook_event(event_type, data_object)
      event = OpenStruct.new(
        type: event_type,
        data: OpenStruct.new(object: data_object)
      )

      @stubbed_event = event
      Stripe::Webhook.define_singleton_method(:construct_event) do |*args|
        event
      end
    end

    def stub_webhook_error(error)
      @stubbed_event = true
      Stripe::Webhook.define_singleton_method(:construct_event) do |*args|
        raise error
      end
    end

    def to_deep_ostruct(obj)
      case obj
      when Hash
        OpenStruct.new(obj.transform_values { |v| to_deep_ostruct(v) })
      when Array
        obj.map { |item| to_deep_ostruct(item) }
      else
        obj
      end
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

    # Test 1: checkout.session.completed
    test "handle_checkout_completed updates account with Stripe IDs" do
      new_account = Account.create!(name: "New Account")

      session = OpenStruct.new(
        customer: "cus_new_123",
        subscription: "sub_new_123",
        metadata: OpenStruct.new(account_id: new_account.id.to_s)
      )

      @controller.send(:handle_checkout_completed, session)

      new_account.reload
      assert_equal "cus_new_123", new_account.stripe_customer_id
      assert_equal "sub_new_123", new_account.stripe_subscription_id
    end

    test "handle_checkout_completed does nothing without account_id in metadata" do
      session = OpenStruct.new(
        customer: "cus_new_123",
        subscription: "sub_new_123",
        metadata: OpenStruct.new(account_id: nil)
      )

      assert_nothing_raised do
        @controller.send(:handle_checkout_completed, session)
      end
    end

    test "handle_checkout_completed does nothing for unknown account" do
      session = OpenStruct.new(
        customer: "cus_new_123",
        subscription: "sub_new_123",
        metadata: OpenStruct.new(account_id: "999999")
      )

      assert_nothing_raised do
        @controller.send(:handle_checkout_completed, session)
      end
    end

    # Test 2: customer.subscription.created
    test "handle_subscription_update works for newly created subscriptions" do
      new_account = Account.create!(name: "New Account")

      subscription = OpenStruct.new(
        id: "sub_brand_new_123",
        status: "active",
        metadata: OpenStruct.new(account_id: new_account.id.to_s, plan_tier: "starter"),
        cancel_at_period_end: false,
        items: OpenStruct.new(
          data: [ OpenStruct.new(price: OpenStruct.new(id: "price_starter_test")) ]
        )
      )

      @controller.send(:handle_subscription_update, subscription)

      new_account.reload
      assert_equal "active", new_account.subscription_status
      assert new_account.starter?
    end

    # Test 3: customer.subscription.updated
    test "handle_subscription_update updates account status" do
      subscription = OpenStruct.new(
        id: "sub_test_123",
        status: "past_due",
        metadata: OpenStruct.new(plan_tier: "professional"),
        cancel_at_period_end: false,
        items: OpenStruct.new(
          data: [ OpenStruct.new(price: OpenStruct.new(id: "price_professional_test")) ]
        )
      )

      @controller.send(:handle_subscription_update, subscription)

      @account.reload
      assert_equal "past_due", @account.subscription_status
      assert @account.professional?
    end

    # Test 4: customer.subscription.deleted (cancel_at_period_end)
    test "handle_subscription_update sets canceled when cancel_at_period_end" do
      subscription = OpenStruct.new(
        id: "sub_test_123",
        status: "active",
        metadata: OpenStruct.new(plan_tier: "starter"),
        cancel_at_period_end: true,
        items: OpenStruct.new(
          data: [ OpenStruct.new(price: OpenStruct.new(id: "price_starter_test")) ]
        )
      )

      @controller.send(:handle_subscription_update, subscription)

      @account.reload
      assert_equal "canceled", @account.subscription_status
      assert @account.starter?
    end

    test "handle_subscription_update finds account by metadata when subscription ID not stored yet" do
      new_account = Account.create!(name: "New Account")

      subscription = OpenStruct.new(
        id: "sub_new_123",
        status: "active",
        metadata: OpenStruct.new(account_id: new_account.id.to_s, plan_tier: "professional"),
        cancel_at_period_end: false,
        items: OpenStruct.new(
          data: [ OpenStruct.new(price: OpenStruct.new(id: "price_professional_test")) ]
        )
      )

      @controller.send(:handle_subscription_update, subscription)

      new_account.reload
      assert_equal "active", new_account.subscription_status
      assert new_account.professional?
    end

    # Test 5: invoice.payment_succeeded
    test "handle_payment_success updates account to active" do
      @account.update!(subscription_status: "past_due")

      invoice = OpenStruct.new(subscription: "sub_test_123")

      @controller.send(:handle_payment_success, invoice)

      @account.reload
      assert_equal "active", @account.subscription_status
    end

    # Test 6: invoice.payment_failed
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
        metadata: OpenStruct.new(account_id: nil, plan_tier: nil),
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
