# Telnyx Setup Guide

## Overview
CoverText uses Telnyx for SMS messaging and automated phone number provisioning. This guide walks you through setting up Telnyx credentials.

## Quick Start

### 1. Get Telnyx Account
1. Sign up at https://telnyx.com/ (if you haven't already)
2. Complete account verification
3. Log in to the [Telnyx Portal](https://portal.telnyx.com/)

### 2. Get API Key
1. In Telnyx Portal, navigate to **API Keys** (left sidebar)
2. Click **Create API Key**
3. Name it (e.g., "CoverText Development")
4. Copy the key (format: `KEY01234567890ABCDEFGH_...`)
5. Store it securely - you won't be able to see it again

### 3. Get Messaging Profile ID
1. In Telnyx Portal, navigate to **Messaging** → **Profiles**
2. If you don't have a profile, click **Create Messaging Profile**:
   - Name: "CoverText"
   - URL Type: "Webhook"
   - Webhook URL: `https://yourdomain.com/webhooks/telnyx/inbound` (or localhost for dev)
   - Enabled: Yes
3. Once created, click on the profile name
4. Copy the **Profile ID** (UUID format: `12345678-1234-1234-1234-123456789abc`)

### 4. Configure Rails Credentials

#### Development Environment
```bash
# Edit development credentials
EDITOR="code --wait" bin/rails credentials:edit --environment development
```

Add this structure:
```yaml
telnyx:
  api_key: KEY01234567890ABCDEFGH_your_actual_key_here
  messaging_profile_id: 12345678-1234-1234-1234-123456789abc

stripe:
  secret_key: sk_test_YOUR_STRIPE_KEY
  publishable_key: pk_test_YOUR_STRIPE_KEY
  starter_price_id: price_1ABC123
  professional_price_id: price_1DEF456
  enterprise_price_id: price_1GHI789
  webhook_secret: whsec_YOUR_WEBHOOK_SECRET
```

Save and close the editor.

#### Alternative: Use Environment Variables (Dev/Test Only)
```bash
# Add to your shell profile or .env file
export TELNYX_API_KEY="KEY01234567890ABCDEFGH_your_actual_key_here"
export TELNYX_MESSAGING_PROFILE_ID="12345678-1234-1234-1234-123456789abc"
```

⚠️ **Important:** ENV vars are a fallback for development only. Always use Rails credentials in staging/production.

### 5. Verify Configuration

Test that credentials are loaded:
```bash
bin/rails runner "
  api_key = Rails.application.credentials.dig(:telnyx, :api_key) || ENV['TELNYX_API_KEY']
  profile_id = Rails.application.credentials.dig(:telnyx, :messaging_profile_id) || ENV['TELNYX_MESSAGING_PROFILE_ID']

  puts '✓ Telnyx API Key: ' + (api_key.present? ? 'Configured' : '✗ MISSING')
  puts '✓ Messaging Profile ID: ' + (profile_id.present? ? 'Configured' : '✗ MISSING')
"
```

Expected output:
```
✓ Telnyx API Key: Configured
✓ Messaging Profile ID: Configured
```

### 6. Test Phone Provisioning

Once credentials are configured:
1. Log in to admin portal: http://localhost:3000/login
2. Go to dashboard: http://localhost:3000/admin/dashboard
3. Click **"Provision Phone Number"** button
4. Service will:
   - Search for available toll-free numbers
   - Purchase the first available number
   - Associate it with your messaging profile
   - Update your agency record

## API Workflow

### How Phone Provisioning Works

```
┌─────────────────────────────────────────────────────┐
│ 1. User clicks "Provision Phone Number"            │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 2. Service searches for available toll-free numbers│
│    GET /v2/available_phone_numbers                  │
│    - Filter: phone_number_type=toll_free           │
│    - Filter: country_code=US                       │
│    - Filter: features=sms                          │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 3. Service purchases first available number        │
│    POST /v2/number_orders                          │
│    Body: {                                         │
│      phone_numbers: [{phone_number: "+18005551234"}]│
│      messaging_profile_id: "your-profile-uuid"     │
│    }                                               │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 4. Number is now associated with messaging profile │
│    No additional API call needed!                  │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ 5. Agency record updated with phone_sms            │
│    Agency.update!(phone_sms: "+18005551234")       │
└─────────────────────────────────────────────────────┘
```

**Key Point:** The `messaging_profile_id` is passed when creating the number order. This automatically associates the purchased number with your messaging profile in one API call.

## Messaging Profile Configuration

For the provisioning to work correctly, your Telnyx messaging profile must be configured to receive webhooks:

1. **Webhook URL (Development):**
   ```
   http://localhost:3000/webhooks/telnyx/inbound
   ```

   For local testing with real Telnyx webhooks, use [ngrok](https://ngrok.com/):
   ```bash
   ngrok http 3000
   # Use the https URL: https://abc123.ngrok.io/webhooks/telnyx/inbound
   ```

2. **Webhook URL (Production):**
   ```
   https://yourdomain.com/webhooks/telnyx/inbound
   ```

3. **Status Webhook URL:**
   ```
   https://yourdomain.com/webhooks/telnyx/status
   ```

## Troubleshooting

### Error: "Telnyx messaging profile ID not configured"
**Solution:** Add `messaging_profile_id` to Rails credentials (see Step 4 above)

### Error: "Failed to search for available numbers"
**Causes:**
- Invalid API key
- Insufficient account balance
- No available toll-free numbers in region

**Solution:**
1. Verify API key is correct
2. Check account balance in Telnyx Portal
3. Try again or contact Telnyx support

### Error: "Failed to purchase number"
**Causes:**
- Invalid messaging profile ID
- Insufficient account balance
- Number became unavailable between search and purchase

**Solution:**
1. Verify messaging profile ID is correct UUID
2. Check account balance
3. Try provisioning again (will search for new number)

### Numbers Not Receiving Messages
**Causes:**
- Messaging profile webhook URL not configured
- Webhook URL not publicly accessible
- Number not properly associated with profile

**Solution:**
1. Check messaging profile webhook configuration
2. Use ngrok for local development testing
3. Check Telnyx Portal → Numbers → verify profile assignment

## Production Setup

For production, follow the same steps but use production credentials:

```bash
# Edit production credentials
EDITOR="code --wait" bin/rails credentials:edit --environment production
```

Add production Telnyx credentials:
```yaml
telnyx:
  api_key: KEY01234567890ABCDEFGH_production_key
  messaging_profile_id: 12345678-production-profile-uuid
```

**Important:** Use separate messaging profiles for development and production to avoid webhook conflicts.

## Cost Information

- **Phone Number Purchase:** ~$3-5 one-time fee (varies by number)
- **Monthly Number Rental:** ~$1.50-3.00/month per number
- **Outbound SMS:** ~$0.0040 per message
- **Inbound SMS:** Free

Check current pricing at https://telnyx.com/pricing/messaging

## API References

- [Search Available Numbers](https://developers.telnyx.com/api-reference/phone-number-search/list-available-phone-numbers)
- [Create Number Order](https://developers.telnyx.com/api-reference/phone-number-orders/create-a-number-order)
- [Messaging Profiles](https://developers.telnyx.com/docs/v2/messaging/messaging-profiles)
- [Telnyx Ruby SDK](https://github.com/team-telnyx/telnyx-ruby)

## Support

- **Telnyx Support:** https://support.telnyx.com/
- **CoverText Issues:** Create issue in GitHub repository
