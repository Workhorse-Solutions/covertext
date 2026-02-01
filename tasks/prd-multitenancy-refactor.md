# PRD: Multitenancy Architecture Refactor

## Introduction

Refactor CoverText's tenancy model from a flat Agency-based structure to a hierarchical Account → Agency model. This enables agency owners with multiple physical locations or brands to manage them under a single billing relationship while maintaining per-location Twilio numbers and settings.

**Current State:**
- User → Agency (1:1)
- Agency holds Stripe billing, Twilio number, and all operational data
- Single location per agency signup

**Target State:**
- Account = billing owner (Stripe customer + subscription)
- Agency = physical location/brand (Twilio number + settings), belongs_to Account
- User belongs_to Account (not Agency)
- Access requires: active subscription + at least 1 active Agency

## Goals

- Separate billing ownership (Account) from operational units (Agency)
- Enable multi-location agencies under single billing relationship
- Maintain backward-compatible UX for single-location agencies
- Preserve all existing functionality during refactor
- Establish foundation for future role-based agency access (out of scope)

## User Stories

### US-001: Create Account model and migration
**Description:** As a developer, I need to create the Account model that owns billing and users.

**Acceptance Criteria:**
- [ ] Create `accounts` table with: `name`, `stripe_customer_id`, `stripe_subscription_id`, `subscription_status`, `plan_name`, `created_at`, `updated_at`
- [ ] Add unique index on `stripe_customer_id` and `stripe_subscription_id`
- [ ] Create Account model with validations (name required, stripe IDs unique)
- [ ] Account has_many :agencies, has_many :users
- [ ] Typecheck/lint passes (`bin/rails test`)

---

### US-002: Add account_id to agencies table
**Description:** As a developer, I need agencies to belong to an account.

**Acceptance Criteria:**
- [ ] Add `account_id` foreign key to agencies table (required, not null)
- [ ] Remove Stripe billing columns from agencies (`stripe_customer_id`, `stripe_subscription_id`, `subscription_status`, `plan_name`)
- [ ] Add `active` boolean column to agencies (default: true)
- [ ] Agency belongs_to :account
- [ ] Unique constraint on `phone_sms` remains
- [ ] Typecheck/lint passes

---

### US-003: Move user association from Agency to Account
**Description:** As a developer, I need users to belong to Account instead of Agency.

**Acceptance Criteria:**
- [ ] Add `account_id` foreign key to users table (required)
- [ ] Remove `agency_id` foreign key from users table
- [ ] Add `role` enum or string: `owner`, `admin` (default: `admin`)
- [ ] User belongs_to :account
- [ ] Account has_many :users
- [ ] Unique constraint on email remains
- [ ] Typecheck/lint passes

---

### US-004: Implement Account subscription and access methods
**Description:** As a developer, I need Account to provide subscription status checks and access validation.

**Acceptance Criteria:**
- [ ] `Account#subscription_active?` returns true when `subscription_status == "active"`
- [ ] `Account#has_active_agency?` returns true when at least one agency has `active: true`
- [ ] `Account#can_access_system?` returns `subscription_active? && has_active_agency?`
- [ ] `Account#owner` returns user with role "owner"
- [ ] Unit tests pass for all methods
- [ ] Typecheck/lint passes

---

### US-005: Implement Agency activation and access methods
**Description:** As a developer, I need Agency to provide activation status checks.

**Acceptance Criteria:**
- [ ] `Agency#can_go_live?` returns `active? && account.subscription_active? && live_enabled?`
- [ ] Remove old `subscription_active?` method from Agency
- [ ] `Agency#deactivate!` sets `active: false`
- [ ] `Agency#activate!` sets `active: true`
- [ ] Unit tests pass
- [ ] Typecheck/lint passes

---

### US-006: Update ApplicationController authentication
**Description:** As a developer, I need the authentication layer to work with the new Account-based model.

**Acceptance Criteria:**
- [ ] `current_user` remains unchanged
- [ ] Add `current_account` helper method returning `current_user.account`
- [ ] Add `require_active_subscription` before_action that checks `current_account.can_access_system?`
- [ ] Redirect to billing page with message when subscription inactive
- [ ] Redirect to agency setup when no active agencies
- [ ] Typecheck/lint passes

---

### US-007: Update Admin::BaseController for account context
**Description:** As a developer, I need the admin namespace to use Account context.

**Acceptance Criteria:**
- [ ] Add `current_account` helper (delegates to ApplicationController)
- [ ] `current_agency` returns first active agency for account (temporary until agency switcher)
- [ ] All admin controllers inherit proper context
- [ ] Typecheck/lint passes

---

### US-008: Refactor RegistrationsController for Account + Agency signup
**Description:** As a developer, I need signup to create Account, Agency, and User together.

**Acceptance Criteria:**
- [ ] Create Account with name from agency name
- [ ] Create Agency under Account with phone_sms, active: true
- [ ] Create User under Account with role: "owner"
- [ ] Pass `account_id` (not agency_id) in Stripe metadata
- [ ] Stripe checkout success updates Account (not Agency)
- [ ] Auto-login user after successful signup
- [ ] Typecheck/lint passes

---

### US-009: Update Stripe webhook handler for Account billing
**Description:** As a developer, I need Stripe webhooks to update Account subscription status.

**Acceptance Criteria:**
- [ ] `customer.subscription.updated` updates Account by `account_id` in metadata
- [ ] `customer.subscription.deleted` sets Account status to "canceled"
- [ ] `invoice.payment_failed` sets Account status to "past_due"
- [ ] Webhook continues to work for existing events
- [ ] Typecheck/lint passes

---

### US-010: Update BillingController for Account context
**Description:** As a developer, I need billing management to work with Account.

**Acceptance Criteria:**
- [ ] Billing page shows Account subscription info
- [ ] Stripe customer portal uses Account's `stripe_customer_id`
- [ ] Plan upgrades/downgrades update Account
- [ ] Typecheck/lint passes
- [ ] Verify in browser: billing page loads and shows correct info

---

### US-011: Update seeds.rb for new data model
**Description:** As a developer, I need seed data that demonstrates the new hierarchy.

**Acceptance Criteria:**
- [ ] Create 1 Account ("Reliable Insurance Group")
- [ ] Create 2 Agencies under Account (different locations/brands)
- [ ] Create 1 User (owner) under Account
- [ ] Distribute existing clients/policies across both agencies
- [ ] `bin/rails db:seed` runs without errors
- [ ] Summary output shows Account → Agencies → Users hierarchy

---

### US-012: Update all agency-scoped queries to use current_agency
**Description:** As a developer, I need all admin queries to properly scope to the current agency.

**Acceptance Criteria:**
- [ ] RequestsController scopes to `current_agency.requests`
- [ ] All other admin controllers scope to current_agency where applicable
- [ ] No direct references to `current_user.agency` remain
- [ ] Typecheck/lint passes

---

### US-013: Add Account settings page (basic)
**Description:** As a user, I want to view and edit my account name.

**Acceptance Criteria:**
- [ ] New route: `GET/PATCH /admin/account`
- [ ] Account settings page shows account name (editable)
- [ ] Shows list of agencies under account (read-only for now)
- [ ] Shows current subscription status
- [ ] Owner role required to access
- [ ] Typecheck/lint passes
- [ ] Verify in browser: account settings page loads and saves

---

### US-014: Add navigation link to Account settings
**Description:** As a user, I want to access Account settings from the admin nav.

**Acceptance Criteria:**
- [ ] Add "Account" link to admin sidebar/nav
- [ ] Link only visible to users with owner role
- [ ] Typecheck/lint passes
- [ ] Verify in browser: nav shows Account link for owner

---

### US-015: Implement grace period for subscription lapses
**Description:** As a developer, I need to handle subscription cancellation with a 14-day read-only grace period.

**Acceptance Criteria:**
- [ ] Add `subscription_ends_at` timestamp to accounts table
- [ ] When subscription canceled, set `subscription_ends_at` to end of billing period
- [ ] `Account#in_grace_period?` returns true if canceled but `subscription_ends_at` is in future (max 14 days)
- [ ] `Account#read_only?` returns true when in grace period
- [ ] `Account#can_access_system?` allows access during grace period (read-only)
- [ ] Add `Account#days_until_lockout` helper
- [ ] Typecheck/lint passes

---

### US-016: Add subscription warning banner
**Description:** As a user, I want to see a warning when my subscription is about to expire.

**Acceptance Criteria:**
- [ ] Show warning banner in admin layout when `in_grace_period?`
- [ ] Banner shows days remaining and link to billing
- [ ] Banner dismissible (session-based)
- [ ] Typecheck/lint passes
- [ ] Verify in browser: banner appears when subscription is in grace period

---

### US-017: Create warning email job for expiring accounts
**Description:** As a developer, I need a background job to send warning emails before account lockout.

**Acceptance Criteria:**
- [ ] Create `SubscriptionExpiryWarningJob` (Solid Queue)
- [ ] Job finds accounts in grace period
- [ ] Job sends warning email to owner at 7 days, 3 days, and 1 day before lockout
- [ ] Add `last_expiry_warning_sent_at` to accounts to prevent duplicate emails
- [ ] Job scheduled to run daily
- [ ] Typecheck/lint passes

---

### US-018: Update test fixtures for new model
**Description:** As a developer, I need test fixtures that reflect the new hierarchy.

**Acceptance Criteria:**
- [ ] Create accounts.yml with test accounts
- [ ] Update agencies.yml to reference accounts
- [ ] Update users.yml to reference accounts (not agencies)
- [ ] All existing tests pass after fixture updates
- [ ] Typecheck/lint passes (`bin/rails test`)

---

### US-019: Write integration tests for signup flow
**Description:** As a developer, I need integration tests for the new signup flow.

**Acceptance Criteria:**
- [ ] Test: successful signup creates Account + Agency + User
- [ ] Test: User has owner role after signup
- [ ] Test: Agency is active after signup
- [ ] Test: Stripe webhook updates Account subscription
- [ ] All tests pass
- [ ] Typecheck/lint passes

---

### US-020: Write integration tests for access control
**Description:** As a developer, I need integration tests for subscription-based access.

**Acceptance Criteria:**
- [ ] Test: active subscription + active agency = access granted
- [ ] Test: canceled subscription + expired grace = access denied
- [ ] Test: active subscription + no active agencies = redirect to setup
- [ ] Test: grace period = access granted with warning
- [ ] All tests pass
- [ ] Typecheck/lint passes

## Functional Requirements

- FR-1: Account model stores billing relationship (Stripe customer/subscription) and owns Users and Agencies
- FR-2: Agency model represents a physical location with unique Twilio phone number, belongs to Account
- FR-3: User model belongs to Account (not Agency), has role field (owner/admin)
- FR-4: System access requires Account with active subscription AND at least one active Agency
- FR-5: Signup flow creates Account + first Agency + owner User in single transaction
- FR-6: Stripe webhooks update Account subscription status (not Agency)
- FR-7: Grace period allows read-only access for 14 days after subscription cancellation
- FR-8: Expired accounts are soft-locked (not deleted) after grace period; manual cleanup later
- FR-9: Owner role required to manage Account settings and billing
- FR-10: Admin controllers scope all queries to current_agency within current_account

## Non-Goals (Out of Scope)

- Agency switcher UI (users access only one agency at a time for now)
- Role-based permissions per agency (planned for future)
- Multiple owners per account
- Agency-level billing or separate subscriptions
- User invitations or team management UI
- Agency creation/deletion UI (seed data only for now)
- HawkSoft or other CRM integrations

## Deployment Strategy

**Constraint:** Each commit + push triggers a production deploy on green CI.

**Approach:** Since production only has sample data, we can do a clean-slate deploy:

1. **Feature branch:** Complete all user stories (US-001 through US-020) on a feature branch
2. **Single merge:** Merge to main as one atomic change
3. **Deploy steps:**
   - `bin/rails db:drop db:create db:migrate db:seed` on production
   - No data migration needed—sample data recreated by seeds

**Alternative (if we later need incremental deploys):**
- Use expand-contract pattern: add new tables/columns → backfill → remove old
- Each PR must leave the app in a working state with both old and new code paths

For this refactor, we'll use the **clean-slate approach** since no real customer data exists.

## Technical Considerations

- **Database:** Fresh start—drop and recreate with new schema
- **Migrations:** Single migration batch creating new structure
- **Foreign Keys:** Proper cascading deletes (Account → Agencies → operational data)
- **Sessions:** Store `account_id` in session alongside `user_id` for faster lookups
- **Stripe Metadata:** Use `account_id` in all Stripe metadata going forward
- **Background Jobs:** Use Solid Queue for cleanup job

### Model Relationships (Target)

```
Account
├── has_many :users (owner, admin roles)
├── has_many :agencies
│   ├── has_many :clients
│   ├── has_many :requests
│   ├── has_many :message_logs
│   ├── has_many :conversation_sessions
│   ├── has_many :audit_events
│   └── has_many :sms_opt_outs
├── stripe_customer_id
├── stripe_subscription_id
└── subscription_status
```

## Design Considerations

- Keep UI changes minimal—billing page, account settings, warning banner
- Reuse existing DaisyUI components for new pages
- Account settings page follows same layout as existing admin pages
- Warning banner uses DaisyUI alert component

## Success Metrics

- All existing tests pass after refactor
- New signup flow creates correct hierarchy
- Billing operations work correctly with Account model
- Grace period and cleanup job function as specified
- No regressions in SMS functionality

## Decisions Made

1. **Grace period:** 14 days read-only access after subscription cancellation
2. **Account deletion:** No automatic deletion; send warning emails at 7/3/1 days before lockout
3. **Roles:** Only `owner` and `admin` roles initially; all admins can see everything; granular agency-level roles deferred
