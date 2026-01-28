# Rails Credentials Setup for CoverText

This guide explains what credentials need to be configured and where.

## Overview

CoverText uses Rails encrypted credentials for sensitive configuration. You'll need to set up credentials for:
- **Development**: Local development and testing (uses test mode)
- **Staging**: Production-like environment for testing (uses test mode)
- **Production**: Live deployment (uses live mode)

## What You Need

### 1. Stripe API Keys

Sign up for a free Stripe account at https://stripe.com

You'll need:
- **Test keys** (for development/test)
  - Secret Key (starts with `sk_test_`)
  - Publishable Key (starts with `pk_test_`)
  - Webhook Secret (starts with `whsec_` - from Stripe CLI or Dashboard)
  - Price IDs for your products

- **Live keys** (for production - when ready)
  - Secret Key (starts with `sk_live_`)
  - Publishable Key (starts with `pk_live_`)
  - Webhook Secret
  - Price IDs for live products

### 2. Create Stripe Products

In your Stripe Dashboard (test mode):

1. Go to **Products** → **Add Product**
2. Create two products:
   - **Pilot Plan**: $49/month recurring
   - **Growth Plan**: $99/month recurring
3. Note the Price IDs (e.g., `price_1ABC123...`)

## Setup Instructions

### Development/Test Credentials

```bash
# Edit development credentials
EDITOR="code --wait" bin/rails credentials:edit
```

Add this structure:

```yaml
stripe:
  secret_key: sk_test_YOUR_KEY_HERE
  publishable_key: pk_test_YOUR_KEY_HERE
  pilot_price_id: price_1ABC123_YOUR_PILOT_PRICE_ID
  growth_price_id: price_1DEF456_YOUR_GROWTH_PRICE_ID
  webhook_secret: whsec_YOUR_WEBHOOK_SECRET
```

**To get the webhook secret for local testing:**

```bash
# Install Stripe CLI: https://stripe.com/docs/stripe-cli
stripe listen --forward-to localhost:3000/webhooks/stripe

# This will output a webhook secret like: whsec_abc123...
# Copy that into your credentials
```

### Production Credentials

```bash
# Edit production credentials
EDITOR="code --wait" bin/rails credentials:edit --environment production
```

Use the same YAML structure but with `sk_live_` keys and live Price IDs.

### Staging Credentials

```bash
# Edit staging credentials
EDITOR="code --wait" bin/rails credentials:edit --environment staging
```

**Important**: Staging uses **test mode** keys, not live keys.

```yaml
stripe:
  secret_key: sk_test_YOUR_KEY_HERE  # Use test keys!
  publishable_key: pk_test_YOUR_KEY_HERE
  pilot_price_id: price_1ABC123_YOUR_PILOT_PRICE_ID  # Can reuse dev products or create separate
  growth_price_id: price_1DEF456_YOUR_GROWTH_PRICE_ID
  webhook_secret: whsec_YOUR_STAGING_WEBHOOK_SECRET  # From Stripe Dashboard webhook endpoint
```

**Why test mode for staging?**
- No risk of charging real customers
- Test the full signup/billing flow safely
- Use test credit cards (4242 4242 4242 4242)
- Can reset data without consequences

**Staging webhook setup:**
Configure a webhook endpoint in Stripe Dashboard (test mode):
- Endpoint URL: `https://staging.yourdomain.com/webhooks/stripe`
- Use the same events as production
- Copy the signing secret to staging credentials

### Webhook Setup in Stripe Dashboard

**For Staging and Production**, configure webhooks at https://dashboard.stripe.com/webhooks

**Staging** (test mode):
1. Switch to Test mode in Stripe Dashboard
2. **Endpoint URL**: `https://staging.yourdomain.com/webhooks/stripe`
3. **Events to send**: (same as production)
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
4. Copy the **Signing Secret** to staging credentials

**Production** (live mode):
1. Switch to Live mode in Stripe Dashboard
2. **Endpoint URL**: `https://yourdomain.com/webhooks/stripe`
3. **Events to send**: (same as above)
4. Copy the **Signing Secret** to production credentials

## Verifying Setup

After adding credentials, test that they load:

```bash
# Start Rails console
bin/rails console

# Check Stripe is configured
Stripe.api_key
# Should output: "sk_test_..."

# Check price IDs
Rails.application.credentials.dig(:stripe, :pilot_price_id)
# Should output: "price_1ABC..."
```

## Testing Locally

1. Start the dev server: `bin/dev`
2. In another terminal, start Stripe webhook forwarding:
   ```bash
   stripe listen --forward-to localhost:3000/webhooks/stripe
   ```
3. Visit http://localhost:3000 to see the marketing site
4. Sign up with test card: `4242 4242 4242 4242` (any future expiry, any CVC)

## Current State

✅ **Phase M1 Complete**:
- Marketing homepage at `/`
- Self-serve signup at `/signup`
- Admin billing page at `/admin/billing`
- Stripe subscriptions fully integrated
- Plan gating with `live_enabled` flag
- WebMock configured for test isolation

⚠️ **Pending**: Full webhook integration tests (requires proper test credential setup)

## Commit Checklist

Before committing, ensure:
- [ ] `.gitignore` includes `config/credentials/development.key` (already done)
- [ ] Only `config/credentials/*.yml.enc` files are committed (encrypted)
- [ ] Never commit `*.key` files
- [ ] `docs/STRIPE_SETUP.md` documents the full integration

## Next Steps

After you add the credentials:
1. Restart the Rails server
2. Test the signup flow
3. Verify webhook handling with Stripe CLI
4. Run `bin/ci` to confirm all tests pass
