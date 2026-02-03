# Stripe Configuration

This application uses Stripe for subscription billing. To configure Stripe:

## 1. Create Stripe Products

In your Stripe Dashboard, create the following products:

- **Starter Plan**: $49/month ($490/year) recurring subscription
- **Professional Plan**: $99/month ($950/year) recurring subscription
- **Enterprise Plan**: $199/month ($1990/year) recurring subscription

Note the Price IDs for each plan (e.g., `price_1ABC123...`).

**Note**: Currently, the app uses monthly pricing only. Annual billing support can be added later.

## 2. Configure Credentials

Add the following to your Rails credentials:

```yaml
stripe:
  secret_key: sk_test_... # Your Stripe secret key
  publishable_key: pk_test_... # Your Stripe publishable key (not currently used but good to have)
  starter_price_id: price_1ABC123... # Starter plan price ID
  professional_price_id: price_1DEF456... # Professional plan price ID
  enterprise_price_id: price_1GHI789... # Enterprise plan price ID
  webhook_secret: whsec_... # Webhook signing secret from Stripe Dashboard
```

### Development/Test

```bash
EDITOR="code --wait" bin/rails credentials:edit
```

### Production

```bash
EDITOR="code --wait" bin/rails credentials:edit --environment production
```

## 3. Set Up Webhooks

In Stripe Dashboard → Developers → Webhooks, add an endpoint:

**URL**: `https://yourdomain.com/webhooks/stripe`

**Events to listen for**:
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_succeeded`
- `invoice.payment_failed`

Copy the webhook signing secret to your credentials as `stripe.webhook_secret`.

## 4. Test Locally

To test webhooks locally, use the Stripe CLI:

```bash
stripe listen --forward-to localhost:3000/webhooks/stripe
```

This will give you a webhook secret for local testing (starts with `whsec_`).

## Features Implemented

### Public Marketing Site
- Homepage at `/` with product positioning
- Clear value proposition and pricing
- No authentication required

### Self-Serve Signup
- Agency registration at `/signup`
- Creates agency + admin user
- Redirects to Stripe Checkout for payment
- Handles subscription confirmation

### Subscription Management
- Billing page at `/admin/billing`
- Shows current plan and status
- Links to Stripe Customer Portal for:
  - Plan changes
  - Cancellation
  - Payment method updates

### Plan Gating
- `Agency.subscription_active?` - checks if subscription is active
- `Agency.can_go_live?` - checks both subscription AND `live_enabled` flag
- UI banners in admin showing:
  - Subscription issues (if not active)
  - "Not Live" status (if active but not enabled)

### Database Fields

Added to `accounts` table:
- `stripe_customer_id` - Stripe Customer ID (unique, nullable)
- `stripe_subscription_id` - Stripe Subscription ID (unique, nullable)
- `subscription_status` - Status from Stripe (active, past_due, canceled, etc.)
- `plan_tier` - Plan tier name (starter, professional, enterprise) - defaults to "starter"

The `plan_tier` field is used for feature gating throughout the application. It's set during signup and updated via Stripe webhooks when subscriptions change.

## Compliance & A2P Readiness

Even with an active subscription, agencies start with `live_enabled: false`. This supports:
- Manual compliance review before activation
- A2P registration verification
- Gradual rollout control

To enable an agency:

```ruby
agency = Agency.find(...)
agency.update!(live_enabled: true)
```

## Next Steps (Not Implemented)

Future enhancements could include:
- Email notifications for failed payments
- Usage-based billing tiers
- Annual billing options
- Team member seats
- Grace periods for past_due subscriptions
