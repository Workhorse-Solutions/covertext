# PRD: Telnyx Toll-Free Verification Self-Serve

## Introduction

Add self-serve Telnyx toll-free verification to CoverText so agency admins can submit a toll-free verification request directly from the admin panel. CoverText auto-generates most of the Telnyx payload from a deterministic template — the agency only provides basic business info (name, website, contact, address). This eliminates the need for agency staff to understand opt-in image URLs, messaging templates, ISV/reseller rules, or the Telnyx portal.

CoverText uses Telnyx toll-free numbers exclusively (no 10DLC yet). Before an agency can send outbound SMS, the toll-free number must be verified through Telnyx's carrier process. This feature brings that workflow in-house.

## Goals

- Allow agency admins to submit a toll-free verification request without leaving CoverText
- Auto-generate the Telnyx verification payload so agencies only provide business identity fields
- Track verification status (draft → submitted → in_review → approved/rejected) with clear UI feedback
- Poll Telnyx for status updates via background jobs (no webhooks for status in Phase 1)
- Keep the implementation small, deterministic, and shippable — no AI/LLMs

## User Stories

### US-001: Add TelnyxTollFreeVerification model and migration ✅ COMPLETED
**Description:** As a developer, I need a database model to store toll-free verification requests scoped to an agency.

**Acceptance Criteria:**
- [x] Create migration for `telnyx_toll_free_verifications` table with columns:
  - `agency_id` (bigint, not null, foreign key to agencies)
  - `telnyx_number` (string, not null) — the toll-free number being verified (E.164)
  - `telnyx_request_id` (string, nullable) — Telnyx's `id` from response, set after submission
  - `status` (string, not null, default: `"draft"`) — one of: `draft`, `submitted`, `in_review`, `waiting_for_customer`, `approved`, `rejected`
  - `payload` (jsonb, not null, default: `{}`) — snapshot of the full request body sent to Telnyx
  - `last_error` (text, nullable) — Telnyx rejection reason or error message
  - `submitted_at` (datetime, nullable)
  - `last_status_at` (datetime, nullable)
  - `created_at`, `updated_at` (timestamps)
- [x] Add unique composite index on `[:agency_id, :telnyx_number]`
- [x] Add index on `[:status]` for polling queries
- [x] Create `TelnyxTollFreeVerification` model with:
  - `belongs_to :agency`
  - Validations: `agency`, `telnyx_number` presence; `status` inclusion in allowed values; `telnyx_number` uniqueness scoped to `agency_id`
  - `STATUSES` constant with all valid statuses
  - Predicate methods: `draft?`, `submitted?`, `approved?`, `rejected?`, `terminal?`
- [x] Add `has_many :telnyx_toll_free_verifications, dependent: :destroy` to Agency model
- [x] Migration runs cleanly: `bin/rails db:migrate`
- [x] All tests pass (`bin/rails test`)
- [x] Rubocop clean

### US-002: Telnyx API client for toll-free verification ✅ COMPLETED
**Description:** As a developer, I need a small HTTP client wrapper to submit and check status of toll-free verification requests via the Telnyx REST API.

**Acceptance Criteria:**
- [x] Create `Telnyx::TollFreeVerification` service in `app/services/telnyx/toll_free_verification.rb`
- [x] Uses `Net::HTTP` (no heavy gems) — the existing `telnyx` gem does not cover this API endpoint
- [x] Reads API key from `Rails.application.credentials.dig(:telnyx, :api_key)` with fallback to `ENV["TELNYX_API_KEY"]`
- [x] Implements class method `submit!(verification)`:
  - POSTs to `https://api.telnyx.com/v2/messaging_tollfree/verification/requests`
  - Sends `Authorization: Bearer <api_key>` header and `Content-Type: application/json`
  - Request body is `verification.payload` (already built as a Hash)
  - On success (HTTP 200/201): updates `verification` with `telnyx_request_id` (from response `id`), sets `status` to `"submitted"`, sets `submitted_at`
  - On failure: sets `last_error` with response body, does NOT change status
  - Returns the updated verification record
- [x] Implements class method `fetch_status!(verification)`:
  - GETs `https://api.telnyx.com/v2/messaging_tollfree/verification/requests/{telnyx_request_id}`
  - Maps Telnyx `verificationStatus` values to CoverText statuses:
    - `"In Progress"` / `"Waiting For Telnyx"` / `"Waiting For Vendor"` → `"in_review"`
    - `"Waiting For Customer"` → `"waiting_for_customer"`
    - `"Verified"` → `"approved"`
    - `"Rejected"` → `"rejected"`
  - Updates `verification.status` and `last_status_at`
  - If response includes `reason`, saves it to `last_error`
  - Returns the updated verification record
- [x] Gracefully handles network errors (timeout, connection refused) by setting `last_error`
- [x] All tests pass (`bin/rails test`)
- [x] Rubocop clean

### US-003: Payload generator service ✅ COMPLETED
**Description:** As a developer, I need a deterministic service that builds the Telnyx API request payload from agency-provided business info and CoverText defaults.

**Note:** Business info is NOT stored in the CoverText database — it's collected from the form and passed directly to Telnyx via the payload.

**Acceptance Criteria:**
- [x] Create `Telnyx::TollFreeVerificationPayload` service in `app/services/telnyx/toll_free_verification_payload.rb`
- [x] Class method `build(verification, business_info:)` returns a Hash with all required Telnyx fields
- [x] `business_info` is a Hash with keys the agency provides: `business_name`, `corporate_website`, `contact_first_name`, `contact_last_name`, `contact_email`, `contact_phone`, `address1`, `address2` (optional), `city`, `state`, `zip`, `country` (default `"US"`), `business_registration_number` (optional), `business_registration_type` (default `"EIN"`), `entity_type` (default `"PRIVATE_PROFIT"`)
- [x] CoverText auto-generates these fields in the payload:
  - `useCase`: `"Insurance Services"`
  - `messageVolume`: `"1,000"` (default)
  - `useCaseSummary`: A deterministic string describing customer-initiated insurance support (e.g., "Clients of {business_name} text their agency's toll-free number to request proof of insurance, ID cards, policy information, and expiration reminders. All messaging is customer-initiated and transactional.")
  - `productionMessageContent`: 2–3 example messages (e.g., `"Here is your auto insurance ID card for policy #ABC123. Reply STOP to opt out."` and `"Your policy expires on 03/15/2026. Contact your agent to renew. Reply STOP to opt out."`)
  - `optInWorkflow`: deterministic description of inbound-message opt-in (e.g., "Clients opt in by initiating a text message to the agency's toll-free number. No marketing messages are sent. The first response includes: 'You are now connected with {business_name} for insurance support. Reply STOP to opt out. Reply HELP for help. Msg & data rates may apply.'")
  - `optInWorkflowImageURLs`: `[{"url": "https://covertext.app/compliance/opt-in-flow.png"}]`
  - `additionalInformation`: deterministic string (e.g., "Transactional use only. Customer-initiated. Reply STOP to opt out at any time. Reply HELP for assistance. No marketing or promotional messages.")
  - `isvReseller`: `"CoverText"` (always — we are the ISV/reseller)
  - `ageGatedContent`: `false`
  - `phoneNumbers`: `[{"phoneNumber": verification.telnyx_number}]`
  - `businessRegistrationNumber`: from business_info
  - `businessRegistrationType`: from business_info (default `"EIN"`)
  - `businessRegistrationCountry`: from business_info country (default `"US"`)
  - `entityType`: from business_info (default `"PRIVATE_PROFIT"`)
- [x] Payload Hash uses camelCase keys matching Telnyx API field names
- [x] All tests pass (`bin/rails test`)
- [x] Rubocop clean

### US-004: Background jobs for submission and status polling
**Description:** As a developer, I need background jobs to submit verification requests to Telnyx and poll for status updates asynchronously.

**Acceptance Criteria:**
- [ ] Create `SubmitTelnyxTollFreeVerificationJob` in `app/jobs/submit_telnyx_toll_free_verification_job.rb`:
  - Takes `verification_id` as argument
  - Calls `Telnyx::TollFreeVerification.submit!(verification)`
  - On success, enqueues `PollTelnyxTollFreeVerificationStatusJob` with delay (e.g., 5 minutes)
  - On error, logs and sets `last_error` on the verification record
- [ ] Create `PollTelnyxTollFreeVerificationStatusJob` in `app/jobs/poll_telnyx_toll_free_verification_status_job.rb`:
  - Takes `verification_id` as argument
  - Calls `Telnyx::TollFreeVerification.fetch_status!(verification)`
  - If status is not terminal (`approved` or `rejected`), re-enqueues itself with exponential backoff (5 min → 15 min → 1 hour → 4 hours, capped at 4 hours)
  - Stops re-enqueuing after terminal status
  - Logs status transitions
- [ ] Both jobs inherit from `ApplicationJob`
- [ ] Both jobs use `queue_as :default`
- [ ] All tests pass (`bin/rails test`)
- [ ] Rubocop clean

### US-005: Admin "Messaging Compliance" page — read-only status view ✅ COMPLETED
**Description:** As an agency admin, I want to see the toll-free verification status for my agency's number so I know whether we're verified to send messages.

**Acceptance Criteria:**
- [x] Create `Admin::ComplianceController` inheriting from `Admin::BaseController`
- [x] Action: `show` — loads the agency's most recent `TelnyxTollFreeVerification` (if any)
- [x] Add route: `get "compliance", to: "compliance#show"` inside the `admin` namespace
- [x] Create view `app/views/admin/compliance/show.html.erb`:
  - Show the agency's assigned toll-free number (`current_agency.phone_sms`) or "No toll-free number assigned" if nil
  - If a verification record exists, display:
    - Status badge (color-coded: green=approved, yellow=in_review/submitted, red=rejected, gray=draft, orange=waiting_for_customer)
    - `submitted_at` timestamp (if submitted)
    - `last_status_at` timestamp (if checked)
    - When `waiting_for_customer` or `rejected`: display `last_error` text in a warning/error alert box with guidance
  - If no verification exists and `phone_sms` is present: show "Submit Verification Request" button
  - If `phone_sms` is nil: show message that a toll-free number must be assigned first
- [x] Add "Messaging Compliance" link to admin sidebar navigation
- [x] Uses DaisyUI components (badges, alerts, cards) matching existing admin styling
- [x] All tests pass (`bin/rails test`)
- [x] Rubocop clean
- [x] Verify in browser using dev server (`bin/dev`)

### US-006: Admin verification submission form ✅ COMPLETED
**Description:** As an agency admin, I want to fill in my business details and submit a toll-free verification request so my agency can start sending SMS.

**Acceptance Criteria:**
- [x] Add `new` and `create` actions to `Admin::ComplianceController`
- [x] `new` action: renders a form pre-filled with known data (agency name, user name/email)
- [x] Form collects only what the agency must provide (note: these fields are NOT stored in the CoverText database, only passed to Telnyx):
  - Business name (pre-filled from agency name, editable)
  - Corporate website (required)
  - Contact first name (pre-filled from current_user, editable)
  - Contact last name (pre-filled from current_user, editable)
  - Contact email (pre-filled from current_user, editable)
  - Contact phone (required, E.164)
  - Business address line 1 (required)
  - Business address line 2 (optional)
  - City (required)
  - State (required — full name, not abbreviation)
  - ZIP (required)
  - Country (hidden field, default "US" for MVP)
  - Business Registration Number / EIN (optional)
  - Business Registration Type (select: EIN, TAX_ID, DUNS; default "EIN")
  - Entity Type (select: SOLE_PROPRIETOR, PRIVATE_PROFIT, PUBLIC_PROFIT, NON_PROFIT, GOVERNMENT; default PRIVATE_PROFIT)
- [x] On submit:
  1. Build payload via `Telnyx::TollFreeVerificationPayload.build`
  2. Create `TelnyxTollFreeVerification` record with `status: "draft"`, `telnyx_number: current_agency.phone_sms`, `payload: built_payload`
  3. Enqueue `SubmitTelnyxTollFreeVerificationJob`
  4. Redirect to compliance show page with flash notice
- [x] Use Turbo for form submission (Turbo Drive is sufficient; no Turbo Frames needed)
- [x] Form uses `UI::Form::FieldComponent` for fields where form builder is available
- [x] Validation errors display inline per field
- [x] Guard: do not allow submission if agency has no `phone_sms`
- [x] Guard: do not allow submission if an active (non-rejected, non-draft) verification already exists
- [x] Prevent concurrent submissions with UI debouncing (disable submit button on click) and backend idempotency check
- [x] Old rejected/draft verifications are destroyed before creating new submission (enforces uniqueness constraint)
- [x] All tests pass (`bin/rails test`)
- [x] Rubocop clean
- [x] Verify in browser using dev server (`bin/dev`)

### US-007: Compliance opt-in flow asset ✅ COMPLETED
**Description:** As a developer, I need a publicly accessible opt-in flow image at `/compliance/opt-in-flow.png` for the Telnyx verification payload.

**Status:** Already implemented via `Compliance::OptInFlowController` with SVG/PNG support.

**Acceptance Criteria:**
- [x] Place a PNG image at `public/compliance/opt-in-flow.png` (served statically by Rails, no controller needed)
  - If a real opt-in flow diagram isn't ready, place a placeholder PNG with text: "CoverText Opt-In Flow: Client initiates by texting the toll-free number. No marketing messages."
- [x] The existing `Compliance::OptInFlowController` route (`GET /compliance/opt-in-flow.png`) should serve the image, OR redirect to the static file if preferred
- [x] Verify `https://covertext.app/compliance/opt-in-flow.png` resolves (in production) or `http://localhost:3000/compliance/opt-in-flow.png` resolves (in dev)
- [x] All tests pass (`bin/rails test`)
- [x] Rubocop clean

### US-008: Model and service tests
**Description:** As a developer, I need test coverage for the verification model, payload generator, and Telnyx API client.

**Acceptance Criteria:**
- [ ] Model test (`test/models/telnyx_toll_free_verification_test.rb`):
  - Validates presence of `agency`, `telnyx_number`, `status`
  - Validates `status` inclusion in allowed values
  - Validates uniqueness of `telnyx_number` scoped to `agency_id`
  - Tests predicate methods (`draft?`, `approved?`, `terminal?`, etc.)
  - Tests `payload` default value is `{}`
- [ ] Payload service test (`test/services/telnyx/toll_free_verification_payload_test.rb`):
  - Asserts all required Telnyx fields are present in generated payload
  - Asserts `isvReseller` is always `"CoverText"`
  - Asserts `useCase` is `"Insurance Services"`
  - Asserts `ageGatedContent` is `false`
  - Asserts `phoneNumbers` contains the verification's `telnyx_number`
  - Asserts `businessName`, contact fields, and address fields are populated from input
  - Asserts payload keys are camelCase
  - Asserts `businessRegistrationNumber`, `businessRegistrationType`, `businessRegistrationCountry` are present
- [ ] API client test (`test/services/telnyx/toll_free_verification_test.rb`):
  - Tests `submit!` with stubbed HTTP response (success): sets `telnyx_request_id`, `status`, `submitted_at`
  - Tests `submit!` with stubbed HTTP response (failure): sets `last_error`, does not change status
  - Tests `fetch_status!` with stubbed responses for each Telnyx status mapping
  - Tests network error handling
- [ ] All tests pass (`bin/rails test`)
- [ ] Rubocop clean

### US-009: Job tests
**Description:** As a developer, I need test coverage for the submission and polling background jobs.

**Acceptance Criteria:**
- [ ] Test `SubmitTelnyxTollFreeVerificationJob` (`test/jobs/submit_telnyx_toll_free_verification_job_test.rb`):
  - Stubs `Telnyx::TollFreeVerification.submit!`
  - Asserts job calls `submit!` with the correct verification record
  - Asserts `PollTelnyxTollFreeVerificationStatusJob` is enqueued on success
  - Asserts error is logged on failure (no crash)
- [ ] Test `PollTelnyxTollFreeVerificationStatusJob` (`test/jobs/poll_telnyx_toll_free_verification_status_job_test.rb`):
  - Stubs `Telnyx::TollFreeVerification.fetch_status!`
  - Asserts job re-enqueues itself when status is non-terminal
  - Asserts job does NOT re-enqueue when status is `approved` or `rejected`
- [ ] All tests pass (`bin/rails test`)
- [ ] Rubocop clean

### US-010: Controller tests
**Description:** As a developer, I need test coverage for the admin compliance controller.

**Acceptance Criteria:**
- [ ] Test `Admin::ComplianceController` (`test/controllers/admin/compliance_controller_test.rb`):
  - Test `show` renders with no verification record
  - Test `show` renders with a verification record in each status
  - Test `new` renders form with pre-filled fields
  - Test `create` creates verification record and enqueues job
  - Test `create` rejects when agency has no `phone_sms`
  - Test `create` rejects when active verification already exists
  - Test requires authentication (redirects when not logged in)
  - Test requires active subscription
- [ ] All tests pass (`bin/rails test`)
- [ ] Rubocop clean

## Functional Requirements

- FR-1: The system must store toll-free verification requests in a `telnyx_toll_free_verifications` table scoped to Agency with a unique constraint on `(agency_id, telnyx_number)`
- FR-2: The system must track verification status through the lifecycle: `draft` → `submitted` → `in_review` → `approved` / `rejected` / `waiting_for_customer`
- FR-3: The agency admin provides only business identity fields (name, website, contact info, address, EIN); CoverText auto-generates all messaging/compliance fields
- FR-4: The payload generator must always set `isvReseller` to `"CoverText"` and `useCase` to `"Insurance Services"`
- FR-5: The system must submit verification requests to Telnyx via `POST /v2/messaging_tollfree/verification/requests` with Bearer token auth
- FR-6: The system must poll Telnyx for status updates via `GET /v2/messaging_tollfree/verification/requests/{id}` using background jobs with exponential backoff
- FR-7: The admin compliance page must display the current verification status with color-coded badges and actionable guidance when status is `waiting_for_customer` or `rejected`
- FR-8: The system must not allow submission when the agency has no `phone_sms` assigned
- FR-9: The system must not allow a new submission when an active (non-draft, non-rejected) verification already exists for the same agency+number
- FR-10: A publicly accessible opt-in flow image must be available at `/compliance/opt-in-flow.png`
- FR-11: The payload should include `businessRegistrationNumber`, `businessRegistrationType`, and `businessRegistrationCountry` when provided by the agency (optional fields)
- FR-12: All Telnyx API calls must happen in background jobs — never in the request cycle

## Non-Goals (Out of Scope)

- Telnyx webhook-based status updates (polling only for Phase 1)
- 10DLC brand/campaign registration
- Editing or resubmitting a rejected verification (Phase 2 — for now, admin creates a new one)
- Multi-number verification in a single request (one number per verification)
- Agency self-service Telnyx number provisioning (numbers assigned by CoverText ops)
- Automated opt-in flow image generation
- Marketing message support (transactional only)
- Staff inbox or conversation UI
- AI/LLM-powered form filling
- Time-based override for stuck verifications (Phase 2 — surface to CoverText support to investigate)
- Email/push notifications for verification status changes (Phase 2 — manual refresh for now)
- Non-US business support (MVP assumes US-based agencies only)

## Design Considerations

- Reuse existing admin layout and DaisyUI component patterns (badges, alerts, cards)
- Status badge colors should match existing patterns in the admin dashboard
- The form should feel lightweight — most of the complexity is hidden from the agency admin
- Pre-fill form fields from `current_agency.name`, `current_user.first_name`, `current_user.last_name`, `current_user.email` to minimize typing
- Consider a "review before submit" step showing the auto-generated payload summary (nice-to-have, not required for Phase 1)

## Technical Considerations

### Telnyx API Details
- **Submit endpoint:** `POST https://api.telnyx.com/v2/messaging_tollfree/verification/requests`
- **Status endpoint:** `GET https://api.telnyx.com/v2/messaging_tollfree/verification/requests/{id}`
- **Auth:** `Authorization: Bearer <TELNYX_API_KEY>`
- **Content-Type:** `application/json`
- **Response ID field:** `id` (UUID) — store as `telnyx_request_id`
- **Status field:** `verificationStatus` — values: `In Progress`, `Waiting For Telnyx`, `Waiting For Vendor`, `Waiting For Customer`, `Verified`, `Rejected`

### Status Mapping (Telnyx → CoverText)
| Telnyx Status | CoverText Status |
|---|---|
| `In Progress` | `in_review` |
| `Waiting For Telnyx` | `in_review` |
| `Waiting For Vendor` | `in_review` |
| `Waiting For Customer` | `waiting_for_customer` |
| `Verified` | `approved` |
| `Rejected` | `rejected` |

### File Organization
- `db/migrate/YYYYMMDD_create_telnyx_toll_free_verifications.rb`
- `app/models/telnyx_toll_free_verification.rb`
- `app/services/telnyx/toll_free_verification.rb` (API client)
- `app/services/telnyx/toll_free_verification_payload.rb` (payload builder)
- `app/controllers/admin/compliance_controller.rb`
- `app/views/admin/compliance/show.html.erb`
- `app/views/admin/compliance/new.html.erb`
- `app/jobs/submit_telnyx_toll_free_verification_job.rb`
- `app/jobs/poll_telnyx_toll_free_verification_status_job.rb`
- `public/compliance/opt-in-flow.png`
- `test/models/telnyx_toll_free_verification_test.rb`
- `test/services/telnyx/toll_free_verification_test.rb`
- `test/services/telnyx/toll_free_verification_payload_test.rb`
- `test/jobs/submit_telnyx_toll_free_verification_job_test.rb`
- `test/jobs/poll_telnyx_toll_free_verification_status_job_test.rb`
- `test/controllers/admin/compliance_controller_test.rb`

### HTTP Client Choice
Use `Net::HTTP` directly rather than adding Faraday or another gem. The existing `telnyx` gem handles messaging but does not cover the toll-free verification API endpoints. Keep it simple — two HTTP methods (POST, GET) against two endpoints.

### Dependencies
- Existing: `Agency`, `Admin::BaseController`, `ApplicationJob`, DaisyUI, Turbo
- No new gems required
- `TELNYX_API_KEY` already configured via credentials/ENV for the messaging integration

### Polling Strategy
- Initial poll: 5 minutes after submission
- Backoff: 5 min → 15 min → 1 hour → 4 hours (capped)
- Stop on terminal status (`approved`, `rejected`)
- Telnyx typically approves in 1–5 business days

## Success Metrics

- Agency admin can submit a toll-free verification request in under 2 minutes
- Verification status updates within the app reflect Telnyx status within 4 hours of change
- Zero manual intervention required from CoverText ops for standard verifications
- All tests pass (`bin/rails test`)
- `bin/ci` passes cleanly

## Open Questions

1. ~~Should the opt-in flow image be a real diagram or a placeholder for Phase 1?~~ **RESOLVED:** Real diagram already implemented via `Compliance::OptInFlowController`.
2. ~~Should we add a Telnyx webhook endpoint for verification status updates in Phase 1, or is polling sufficient?~~ **RESOLVED:** Polling is sufficient for Phase 1.
3. ~~Should we support re-submission of rejected verifications with edited business info, or require creating a new record?~~ **RESOLVED:** New record for Phase 1.
4. ~~What `messageVolume` should we default to — `"1,000"` or `"10,000"`?~~ **RESOLVED:** Default to `"1,000"`.
5. ~~Do we need the `businessRegistrationCountry` to support non-US agencies in Phase 1?~~ **RESOLVED:** Default `"US"` for MVP, non-US out of scope.
