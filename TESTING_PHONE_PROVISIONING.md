# Testing the Phone Provisioning & Toll-Free Verification Flow

## ✅ Implementation Summary

The phone provisioning and toll-free verification flow is now fully implemented and ready for testing. Here's what was done:

### 1. Phone Provisioning Service Updated
- **File:** `app/services/telnyx/phone_provisioning_service.rb`
- **Changes:**
  - Implemented real Telnyx API calls using the `telnyx` gem
  - `search_toll_free_numbers`: Calls `/v2/available_phone_numbers` with filters
  - `purchase_number`: Calls `/v2/number_orders` with `messaging_profile_id` (combines purchase + profile assignment in one call)
  - `add_to_messaging_profile`: No longer makes a separate API call (handled during purchase)

### 2. Documentation Created
- **TELNYX_SETUP.md**: Complete guide for getting Telnyx credentials and configuring the system
- **ENV_VARS.md**: Updated with Telnyx configuration requirements
- **AGENTS.md**: Updated with Telnyx workflow patterns

### 3. Tests Updated
- **File:** `test/services/telnyx/phone_provisioning_service_test.rb`
- All 6 tests now pass:
  - ✅ Returns success if phone already provisioned
  - ✅ Checks for required credentials
  - ✅ Successfully provisions toll-free number
  - ✅ Handles no available numbers
  - ✅ Handles API errors gracefully
  - ✅ Rolls back transaction on configuration failure

## 🔧 Required Setup

### Step 1: Get Telnyx Credentials

1. **Sign up/Login:** https://portal.telnyx.com/
2. **Get API Key:**
   - Navigate to "API Keys" → Create new key
   - Copy the key (format: `KEY01234567890ABCDEFGH_...`)
3. **Get Messaging Profile ID:**
   - Navigate to "Messaging" → "Profiles"
   - Create profile if needed (name: "CoverText")
   - Copy the Profile ID (UUID format: `12345678-1234-1234-1234-123456789abc`)

### Step 2: Configure Rails Credentials

```bash
# Edit development credentials
EDITOR="code --wait" bin/rails credentials:edit --environment development
```

Add:
```yaml
telnyx:
  api_key: KEY01234567890ABCDEFGH_your_actual_key
  messaging_profile_id: 12345678-1234-1234-1234-123456789abc

stripe:
  secret_key: sk_test_YOUR_KEY
  publishable_key: pk_test_YOUR_KEY
  # ... other stripe keys
```

**Alternative (Dev Only):** Use ENV variables:
```bash
export TELNYX_API_KEY="KEY01234567890ABCDEFGH_your_actual_key"
export TELNYX_MESSAGING_PROFILE_ID="12345678-1234-1234-1234-123456789abc"
```

### Step 3: Verify Configuration

```bash
bin/rails runner "
  api_key = Rails.application.credentials.dig(:telnyx, :api_key) || ENV['TELNYX_API_KEY']
  profile_id = Rails.application.credentials.dig(:telnyx, :messaging_profile_id) || ENV['TELNYX_MESSAGING_PROFILE_ID']

  puts '✓ Telnyx API Key: ' + (api_key.present? ? 'Configured' : '✗ MISSING')
  puts '✓ Messaging Profile ID: ' + (profile_id.present? ? 'Configured' : '✗ MISSING')
"
```

## 🧪 Testing in Dev UI

### Current Database State
Your development database already has:
- **Account:** Reliable Insurance Group (active subscription)
- **Agency:** Reliable Insurance - Downtown (phone: +12087108182)
- **User:** john@reliableinsurance.example (password: password123)

### Test Scenario 1: View Existing Phone Number

1. **Login:** http://localhost:3000/login
   - Email: `john@reliableinsurance.example`
   - Password: `password123`

2. **Dashboard:** http://localhost:3000/admin/dashboard
   - Should show "System Ready" with existing phone number
   - Phone number: +12087108182

3. **Compliance:** http://localhost:3000/admin/compliance
   - Should show toll-free number
   - Button: "Submit Verification Request"

### Test Scenario 2: Provision New Phone Number

To test provisioning from scratch:

```bash
# Create a test agency without a phone number
bin/rails runner "
  account = User.find_by(email: 'john@reliableinsurance.example').account
  agency = account.agencies.create!(
    name: 'Test Agency - New Phone',
    phone_sms: nil,
    active: true
  )

  # Update current_agency helper to return this agency (or switch in UI)
  puts 'Created agency: ' + agency.name + ' (ID: ' + agency.id.to_s + ')'
"
```

Then in Rails console:
```ruby
# Make this the current agency (temporarily for testing)
user = User.find_by(email: 'john@reliableinsurance.example')
# You'd need to implement agency switching in the UI or console
```

Or update your agency to remove the phone:
```bash
bin/rails runner "
  agency = Agency.find_by(name: 'Reliable Insurance - Downtown')
  agency.update!(phone_sms: nil)
  puts 'Removed phone from: ' + agency.name
"
```

Then:
1. **Dashboard:** Should show "Provision Phone Number" button
2. **Click Button:** Triggers Telnyx API calls
3. **Expected Flow:**
   - Searches for available toll-free numbers
   - Purchases first available number
   - Associates with messaging profile
   - Updates agency record
4. **Result:** Redirect with success message, dashboard shows new number

### Test Scenario 3: Submit Toll-Free Verification

1. **Go to Compliance:** http://localhost:3000/admin/compliance
2. **Click:** "Submit Verification Request"
3. **Fill Form:**
   - Business Name: Pre-filled
   - Website: `https://reliableinsurance.example`
   - Contact: Pre-filled from user
   - Phone: `+18005551234` (E.164 format)
   - Address: Any valid US address
   - Business Registration (optional): Leave blank or add EIN
4. **Submit:** Background job runs
5. **Check Status:** Return to compliance page

## 📊 Monitoring

### Watch Logs
In the terminal running `bin/dev`:
```bash
# You'll see:
[Telnyx::PhoneProvisioningService] Searching for toll-free numbers...
[Telnyx::PhoneProvisioningService] Provisioning failed: ... (if error)
[Telnyx::PhoneProvisioningService] Purchasing number: +18005551234
```

### Check Background Jobs
```bash
bin/rails runner "
  puts 'Solid Queue Jobs:'
  SolidQueue::Job.all.each do |job|
    puts '  ' + job.class_name + ': ' + job.status
  end
"
```

### Verify Database State
```bash
bin/rails runner "
  Agency.all.each do |a|
    puts a.name + ': ' + (a.phone_sms || 'NO PHONE')
  end

  TelnyxTollFreeVerification.all.each do |v|
    puts v.telnyx_number + ': ' + v.status + ' (' + v.created_at.to_s + ')'
  end
"
```

## 🐛 Troubleshooting

### Error: "Telnyx messaging profile ID not configured"
**Solution:** Configure credentials (see Step 2 above)

### Error: "Failed to search for available numbers"
**Causes:**
- Invalid API key
- Insufficient Telnyx account balance
- No toll-free numbers available

**Solutions:**
1. Verify API key in credentials
2. Check Telnyx Portal balance: https://portal.telnyx.com/
3. Try again or contact Telnyx support

### Error: "Failed to purchase number"
**Causes:**
- Invalid messaging profile ID
- Insufficient balance
- Number became unavailable

**Solutions:**
1. Verify messaging profile ID is correct UUID
2. Add funds to Telnyx account
3. Try provisioning again (will search for new number)

### Verification Status Not Updating
**Cause:** Background job not running

**Solutions:**
1. Check `bin/dev` logs for job execution
2. Verify `SOLID_QUEUE_IN_PUMA=true` is set
3. Check job queue: `SolidQueue::Job.count`

## 💰 Cost Information

- **Phone Number Purchase:** ~$3-5 one-time (varies)
- **Monthly Rental:** ~$1.50-3.00/month per number
- **Outbound SMS:** ~$0.0040 per message
- **Inbound SMS:** Free

Current pricing: https://telnyx.com/pricing/messaging

## 📚 API References

- [Telnyx: Search Available Numbers](https://developers.telnyx.com/api-reference/phone-number-search/list-available-phone-numbers)
- [Telnyx: Create Number Order](https://developers.telnyx.com/api-reference/phone-number-orders/create-a-number-order)
- [Telnyx: Messaging Profiles](https://developers.telnyx.com/docs/v2/messaging/messaging-profiles)
- [Telnyx Ruby SDK](https://github.com/team-telnyx/telnyx-ruby)

## ✨ Next Steps

1. **Configure Telnyx credentials** (see Step 2 above)
2. **Test phone provisioning** in dev UI
3. **Submit toll-free verification** and monitor status
4. **Receive first SMS** and verify webhook works

For production deployment, repeat credential setup in production environment and configure production messaging profile.
