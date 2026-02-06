# PRD: Telnyx SMS Integration (Phase 1 PoC)

## Introduction

Add Telnyx as the SMS provider for CoverText, replacing the existing Twilio stub implementation. This Phase 1 PoC establishes the Telnyx webhook endpoints, message send path, and configuration using a namespaced provider architecture that will make future provider additions straightforward.

The existing messaging infrastructure (`MessageLog`, `ProcessInboundMessageJob`, `ConversationManager`) remains intact. Telnyx code is organized under `OutboundMessenger::Telnyx` and feeds into the same `MessageLog` → `ProcessInboundMessageJob` → `ConversationManager` pipeline.

**Context:** CoverText has not been able to use Twilio in production. All existing `agency.phone_sms` numbers are Telnyx numbers. This PoC replaces Twilio entirely with Telnyx while maintaining the same architecture patterns.

## Goals

- Receive inbound SMS/MMS from Telnyx via webhook and persist to `MessageLog`
- Route inbound Telnyx messages through the existing `ConversationManager` pipeline
- Send outbound SMS/MMS via Telnyx asynchronously using ActiveJob
- Verify Telnyx webhook signatures for security
- Use namespaced provider architecture: `OutboundMessenger::Telnyx` (preparing for future `OutboundMessenger::Twilio` if needed)
- Update `ConversationManager` to use `OutboundMessenger::Telnyx` for outbound messages
- Achieve end-to-end SMS conversation flow (inbound → conversation → outbound)
- Pass full test suite with Telnyx-specific test coverage

## User Stories

### US-001: Add Telnyx gem and configuration
**Description:** As a developer, I need the Telnyx Ruby gem installed and configured so the app can authenticate with the Telnyx API.

**Acceptance Criteria:**
- [ ] `telnyx` gem added to Gemfile and `bundle install` passes
- [ ] `config/initializers/telnyx.rb` created, following the same pattern as `config/initializers/twilio.rb`
- [ ] Initializer reads `TELNYX_API_KEY` from `Rails.application.credentials.dig(:telnyx, :api_key)` with fallback to `ENV["TELNYX_API_KEY"]`
- [ ] Initializer reads `TELNYX_WEBHOOK_SECRET` from credentials with `ENV` fallback
- [ ] Initializer provides a stubbed client for test environment (matching TwilioClient pattern)
- [ ] App boots without error in test environment with no Telnyx credentials set
- [ ] `bin/rails test` passes

### US-002: Telnyx inbound webhook endpoint
**Description:** As the system, I need to receive inbound SMS/MMS from Telnyx so messages from Telnyx-provisioned numbers enter the existing message pipeline.

**Acceptance Criteria:**
- [ ] Route added: `POST /webhooks/telnyx/inbound` → `Webhooks::TelnyxInboundController#create`
- [ ] Controller skips `verify_authenticity_token` and `require_authentication`
- [ ] Controller verifies Telnyx webhook signature (using gem's built-in verification)
- [ ] Signature verification can be skipped in test env via `ENV["TELNYX_SKIP_SIGNATURE"]` (matching Twilio pattern)
- [ ] Controller parses Telnyx `message.received` event payload and extracts: from number, to number, body, message ID, media count
- [ ] Controller resolves Agency by `to_number` matching `agency.phone_sms`
- [ ] Returns 404 if no matching agency found
- [ ] Idempotency: duplicate `provider_message_id` does not create duplicate `MessageLog`
- [ ] Creates `MessageLog` with `direction: "inbound"` and all parsed fields
- [ ] Enqueues `ProcessInboundMessageJob` with the new `MessageLog` ID
- [ ] Returns 200 OK on success
- [ ] Unknown event types are logged and return 200 OK (no error)
- [ ] `bin/rails test` passes

### US-003: Telnyx outbound messenger service
**Description:** As the system, I need to send outbound SMS/MMS via Telnyx so agencies can reply to clients.

**Acceptance Criteria:**
- [ ] `OutboundMessenger::Telnyx` service created in `app/services/outbound_messenger/telnyx.rb`
- [ ] Mirrors the existing `OutboundMessenger` API: `send_sms!(agency:, to_phone:, body:, request: nil)` and `send_mms!(agency:, to_phone:, body:, media_url:, request: nil)`
- [ ] Sends SMS/MMS via Telnyx gem API (using `agency.phone_sms` as from number)
- [ ] Creates `MessageLog` after successful send
- [ ] Creates `MessageLog` with `provider_message_id: nil` on error (matching OutboundMessenger pattern)
- [ ] Returns the created `MessageLog` record
- [ ] Logs failures via `Rails.logger.error`
- [ ] `bin/rails test` passes

### US-004: Update ConversationManager to use Telnyx
**Description:** As the system, I need outbound messages to use Telnyx so the conversation flow works end-to-end.

**Acceptance Criteria:**
- [ ] `ConversationManager` updated to call `OutboundMessenger::Telnyx.send_sms!` instead of `OutboundMessenger.send_sms!`
- [ ] All calls to `OutboundMessenger.send_mms!` updated to `OutboundMessenger::Telnyx.send_mms!`
- [ ] Existing tests updated to work with Telnyx service
- [ ] `bin/rails test` passes

### US-006: Telnyx status webhook
**Description:** As the system, I need delivery status updates from Telnyx so we can track message delivery success/failure.

**Acceptance Criteria:**
- [ ] Route added: `POST /webhooks/telnyx/status` → `Webhooks::TelnyxStatusController#create`
- [ ] Controller skips `verify_authenticity_token` and `require_authentication`
- [ ] Controller verifies Telnyx webhook signature (can be skipped in test via `TELNYX_SKIP_SIGNATURE`)
- [ ] Controller parses `message.finalized` events and extracts message ID and delivery status
- [ ] Controller finds `MessageLog` by `provider_message_id`
- [ ] Controller updates `MessageLog` with delivery status (if status field exists; log if not)
- [ ] Unknown event types are logged and return 200 OK
- [ ] Returns 200 OK for all requests
- [ ] `bin/rails test` passes

### US-006: Telnyx webhook integration tests
**Description:** As a developer, I need test coverage for the Telnyx webhook endpoints to ensure correctness and prevent regressions.

**Acceptance Criteria:**
- [ ] Test: valid `message.received` event creates `MessageLog` and enqueues `ProcessInboundMessageJob`
- [ ] Test: duplicate message ID is idempotent (no duplicate `MessageLog`)
- [ ] Test: unknown `to_number` returns 404
- [ ] Test: unknown event type returns 200 OK
- [ ] Test: missing/malformed payload returns appropriate error
- [ ] Test: status webhook `message.finalized` event updates `MessageLog` delivery status
- [ ] Test: status webhook with unknown message ID logs error and returns 200 OK
- [ ] All tests use realistic Telnyx payload structure (nested `data.payload` format)
- [ ] `bin/rails test` passes

### US-007: Telnyx outbound service tests
**Description:** As a developer, I need test coverage for the outbound send service to verify Telnyx API integration works correctly.

**Acceptance Criteria:**
- [ ] Test: `OutboundMessenger::Telnyx.send_sms!` sends SMS and creates `MessageLog`
- [ ] Test: `OutboundMessenger::Telnyx.send_mms!` sends MMS and creates `MessageLog`
- [ ] Test: service creates `MessageLog` with `provider_message_id: nil` on API error
- [ ] Test: service raises error after logging failure (matching OutboundMessenger pattern)
- [ ] Tests use mocked/stubbed Telnyx client (no real API calls)
- [ ] `bin/rails test` passes

## Functional Requirements

- FR-1: The `telnyx` Ruby gem must be added to the Gemfile
- FR-2: Telnyx API key and webhook secret must be configurable via Rails credentials (`credentials.dig(:telnyx, :api_key)`) with ENV fallback (`TELNYX_API_KEY`, `TELNYX_WEBHOOK_SECRET`)
- FR-3: `config/initializers/telnyx.rb` must initialize the Telnyx client and provide a stub for test environment, following the same module pattern as `TwilioClient`
- FR-4: `POST /webhooks/telnyx/inbound` must accept Telnyx `message.received` events, verify webhook signature, parse the nested `data.payload` structure, resolve Agency by `to_number`, and create a `MessageLog`
- FR-5: The inbound webhook must be idempotent — duplicate Telnyx message IDs must not create duplicate `MessageLog` records
- FR-6: After creating the `MessageLog`, the inbound webhook must enqueue `ProcessInboundMessageJob`
- FR-7: Unknown Telnyx event types must be safely logged and return 200 OK
- FR-8: `OutboundMessenger::Telnyx` must send SMS/MMS via the Telnyx gem, create `MessageLog` records, and match the existing `OutboundMessenger` API
- FR-9: `ConversationManager` must use `OutboundMessenger::Telnyx` for all outbound messages
- FR-10: `POST /webhooks/telnyx/status` must process `message.finalized` events and update `MessageLog` delivery status
- FR-11: The app must boot and all tests must pass with no Telnyx credentials configured (graceful fallback in initializer)

## Non-Goals (Out of Scope)

- Multi-provider runtime switching (agencies will use Telnyx exclusively for PoC)
- A2P Brand or Campaign registration logic (handled at Telnyx dashboard level)
- Opt-in / opt-out enforcement beyond Telnyx platform defaults
- Staff inboxes or conversation UI
- HawkSoft or AMS integration
- Rate-limit management at the application level
- Inbound MMS media storage (log media URLs but do not download/store media attachments)
- Adding `sms_provider` field to Agency (all agencies use Telnyx)
- Maintaining Twilio integration (can be deprecated after Telnyx is confirmed working)

## Technical Considerations

### Architecture Flow
Telnyx replaces Twilio entirely:
- **Inbound:** `TelnyxInboundController` → `MessageLog` (provider: "telnyx") → `ProcessInboundMessageJob` → `ConversationManager`
- **Outbound:** `ConversationManager` → `OutboundMessenger::Telnyx` → Telnyx API → `MessageLog` (provider: "telnyx")
- **Status:** `TelnyxStatusController` → Update `MessageLog` delivery status

### File Organization
- `app/controllers/webhooks/telnyx_inbound_controller.rb`
- `app/controllers/webhooks/telnyx_status_controller.rb`
- `app/services/outbound_messenger/telnyx.rb`
- `config/initializers/telnyx.rb`
- `test/controllers/webhooks/telnyx_inbound_controller_test.rb`
- `test/controllers/webhooks/telnyx_status_controller_test.rb`
- `test/services/outbound_messenger/telnyx_test.rb`

### Namespaced Provider Pattern
Using `OutboundMessenger::Telnyx` instead of a separate service allows:
- Consistent API with existing `OutboundMessenger`
- Easy addition of `OutboundMessenger::Twilio` if needed later
- Clear provider isolation in codebase
- Natural refactoring path to a router class if multi-provider support is added

### Telnyx Payload Structure
Telnyx webhooks use a nested JSON structure unlike Twilio's flat form params:
```json
{
  "data": {
    "event_type": "message.received",
    "payload": {
      "id": "unique-message-id",
      "from": { "phone_number": "+15551234567" },
      "to": [{ "phone_number": "+15559876543" }],
      "text": "Message body here",
      "media": [{ "url": "https://..." }]
    }
  }
}
```

### Webhook Signature Verification
Use the Telnyx gem's built-in signature verification (`Telnyx::Webhook::Signature.verify`). The webhook secret is configured per Telnyx messaging profile.

### Agency Lookup
Inbound controllers resolve the Agency by matching the destination phone number against `agency.phone_sms`. All existing agencies have Telnyx numbers.

### Environment Variables
- `TELNYX_API_KEY` - Telnyx API key (or via Rails credentials)
- `TELNYX_WEBHOOK_SECRET` - Webhook signing secret from Telnyx messaging profile
- `TELNYX_SKIP_SIGNATURE` - Set to "true" in test environment to skip signature verification

### Webhook Configuration (Telnyx Dashboard)
- **Inbound webhook URL:** `https://yourdomain.com/webhooks/telnyx/inbound`
- **Status callback URL:** `https://yourdomain.com/webhooks/telnyx/status`
- **Events to enable:** `message.received`, `message.finalized`
- **Webhook secret:** Configure in messaging profile, add to Rails credentials

### Dependencies
- `telnyx` gem (official Ruby SDK)
- Existing: `MessageLog`, `ProcessInboundMessageJob`, `ConversationManager`
- Modified: `ConversationManager` (to call `OutboundMessenger::Telnyx`)

## Success Metrics

- All Telnyx-specific tests pass
- Full existing test suite passes with Telnyx integration
- **End-to-end test:** Inbound SMS from real Telnyx number → `ConversationManager` processes → Outbound SMS reply sent via Telnyx → Delivered to client
- Delivery status updates received and logged for outbound messages
- `bin/ci` passes cleanly

## Open Questions

1. Should we add a `delivery_status` field to `MessageLog` now for tracking message delivery, or log status in a separate table?
2. Should we store inbound MMS media URLs in a JSON column on `MessageLog`, or create a separate `MessageMedia` model?
3. Does Telnyx require any specific number format normalization beyond E.164 (which we already use)?
4. Should we deprecate/remove Twilio code immediately after Telnyx is confirmed working, or leave it in place as a reference?
