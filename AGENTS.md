# CoverText Agent Guide

## Context
CoverText is a Rails 8 B2B SaaS for SMS-based insurance client service. The text conversation IS the user interface. Deterministic logic only (no AI/LLMs).

### Multi-Tenant Architecture
- **Account** → top-level billing entity (has Stripe subscription)
- **Agency** → belongs to Account, represents insurance agency tenant
- **User** → belongs to Account (NOT Agency), can be 'owner' or 'admin'
- **Client** → belongs to Agency, represents insurance client
- Each Account can have multiple Agencies (active/inactive)
- Agencies are the tenant boundary for operational data (clients, policies, requests)

## Phase Discipline
- Implement only the current phase scope.
- Do not ship future-phase features early.
- Add tests required for the phase only.
- Stop once tests pass.

## Stack Rules
- Rails 8 + PostgreSQL.
- Hotwire (Turbo; Stimulus only if needed).
- Importmap-only (no Node/bundlers).
- Tailwind CSS via tailwindcss-rails + DaisyUI.
- ActiveStorage for documents.
- Solid Queue/Cache/Cable (SQLite for non-primary DBs).
- Minitest only (no RSpec).
- ViewComponent + Heroicon for reusable UI.

## Data Model Patterns

### Account Model
- Handles Stripe billing: `stripe_customer_id`, `stripe_subscription_id`, `subscription_status`, `plan_tier`
- `plan_tier` is an enum: `starter`, `professional`, `enterprise` (default: `starter`)
- Validations: stripe IDs are `unique: true, allow_nil: true`
- subscription_status uses inclusion validation with allowed values
- Key methods: `subscription_active?`, `has_active_agency?`, `can_access_system?`, `owner`
- `has_many :agencies`, `has_many :users`

### Agency Model
- Represents insurance agency tenant
- Belongs to Account: `belongs_to :account`
- Has operational data: `has_many :clients`, `has_many :policies`, `has_many :requests`
- Key fields: `phone_sms` (SMS number), `active` (boolean)
- **phone_sms is optional:** NOT collected during signup; agencies provision SMS numbers later via admin panel
- Validation: `validates :phone_sms, uniqueness: true, allow_nil: true` (allows creation without phone number)
- Key methods: `can_go_live?`, `activate!`, `deactivate!`
- Does NOT have `has_many :users` (users belong to Account)

### User Model
- Belongs to Account: `belongs_to :account` (NOT `belongs_to :agency`)
- Roles: 'owner' (one per account) or 'admin'
- Use `ROLES` constant for role validation

### Client Model (was Contact)
- Belongs to Agency: `belongs_to :agency`
- Phone field: `phone_mobile` (E.164 format)
- Represents insurance agency clients who text for service

### Naming Conventions
- Use "Client" not "Contact" for insurance clients
- Use `phone_mobile` for client phone numbers
- Use `phone_sms` for agency SMS numbers

## FormObject Pattern

### Convention
- FormObjects go in `app/models/forms/` directory
- Use `Forms::` namespace (e.g., `Forms::Registration`, not `RegistrationForm`)
- Tests go in `test/models/forms/`
- Use for multi-model forms or complex form logic that doesn't belong in a single model

### Pattern
```ruby
class Forms::Registration
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :field_name, :type
  validates :field_name, presence: true

  def save
    return false unless valid?
    ActiveRecord::Base.transaction do
      # Create/update multiple models
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    # Copy errors from nested models
    false
  end
end
```

### When to Use
- Forms touching multiple models (Account + Agency + User)
- Complex validations spanning multiple models
- Custom form logic that doesn't fit single-model responsibilities
- NOT for simple single-model forms (use model directly)

## Controller Patterns

### Helper Methods (Always Use These)
```ruby
# ApplicationController
current_user      # Returns authenticated User
current_account   # Returns current_user&.account

# Admin::BaseController (inherits ApplicationController)
current_agency    # Returns current_user.account.agencies.where(active: true).first
```

**Never duplicate this logic.** Always use the helpers.

### Access Control
- `require_active_subscription` before_action in Admin::BaseController
- Redirects to billing page when subscription inactive OR no active agencies
- Admin::BillingController MUST skip this check (users need billing access to fix issues)
- Use `require_owner` before_action for owner-only actions (e.g., account settings)

### Controller Inheritance
- Admin controllers inherit from `Admin::BaseController`
- BillingController and other admin controllers get `current_agency`, `current_account` automatically
- RequestsController uses `current_agency.requests` for scoping

### Route Conventions
- Singular `resource` routes expect **plural** controller names
  - `resource :account` → `Admin::AccountsController` (not AccountController)
  - View folder: `app/views/admin/accounts/` (not account/)

## View Conventions

### Form Fields
- **Always use `UI::Form::FieldComponent`** for form fields with form builders
- Component handles labels, inputs, hints, and inline validation errors automatically
- Example:
  ```erb
  <%= render UI::Form::FieldComponent.new(form: f, attribute: :name, label: "Name", hint: "Optional helper text") do |field| %>
    <%= field.with_input do %>
      <%= f.text_field :name, class: "input input-bordered w-full" %>
    <% end %>
  <% end %>
  ```
- For tag helpers (without form builder), match the component's structure:
  - Use `class: "label text-neutral text-base font-semibold pb-1"` for labels
  - Use `<p class="mt-1 text-xs text-base-content/60">` for hints
  - Wrap in `<div class="form-control">`

### Form Validation Errors
- **Prefer inline field-level errors** over error summary lists
- `UI::Form::FieldComponent` automatically displays errors next to fields
- Do NOT use summary blocks like:
  ```erb
  <% if @model.errors.any? %>
    <div class="alert alert-error">
      <ul><% @model.errors.full_messages.each do |msg| %>...</ul>
    </div>
  <% end %>
  ```
- Why: Field-level errors provide better UX by showing errors in context

### Heroicon Helper
- **The `heroicon` helper does NOT accept a direct `class:` parameter**
- Two correct approaches:
  1. **Wrap in a span/div** (preferred in existing code):
     ```erb
     <span class="size-4">
       <%= heroicon "check-circle", variant: :mini %>
     </span>
     ```
  2. **Use options hash**:
     ```erb
     <%= heroicon "trash", variant: :outline, options: { class: "w-4 h-4 text-error" } %>
     ```
- WRONG usage:
  ```erb
  <%= heroicon "check-circle", variant: :mini, class: "size-4" %>
  ```
- Example from existing code (admin layouts):
  ```erb
  <span class="size-6 shrink-0">
    <%= heroicon "check-circle", variant: :outline %>
  </span>
  ```
- Why: The heroicon gem requires class to be nested inside `options:` hash; passing it directly causes "unknown keyword: :class" errors

## Signup & Billing Flow

### Registration (RegistrationsController)
Creates Account + Agency + User in transaction:
1. Create Account with `name` from agency name
2. Create Agency under Account with `phone_sms`, `active: true`
3. Create User under Account with `role: 'owner'`
4. Pass `account_id` in Stripe subscription metadata
5. On Stripe success, update Account with Stripe IDs
6. Auto-login user after successful signup

### Stripe Webhooks (StripeWebhooksController)
- Updates **Account** (not Agency) for billing events
- Find account by `stripe_subscription_id` or `metadata.account_id`
- `subscription.updated`: set `cancel_at_period_end` → status 'canceled'
- `invoice.payment_succeeded`: set status 'active'
- `invoice.payment_failed`: set status 'past_due'
- Use `OpenStruct` for mocking Stripe objects in tests

### Billing Controller
- Uses `current_account` for subscription info (@account.plan_tier, etc.)
- Uses `current_agency` for agency-specific data (@agency.live_enabled, etc.)
- Stripe portal session uses `current_account.stripe_customer_id`

## Testing Conventions

### Fixtures
- accounts.yml: test accounts (reliable_group, acme_group)
- agencies.yml: agencies reference accounts via `account:` key
- users.yml: users reference accounts (not agencies) with roles
- clients.yml: clients have `phone_mobile` field
- **Fixture renames require updating ALL test file references**

### Common Patterns
- Use `agencies(:reliable)` not `Agency.first` when you need a specific agency
- Use `users(:john_owner)` for owner role, `users(:bob_admin)` for admin role
- When creating agencies in tests, create an Account first
- Use `OpenStruct.new(id: '...', status: '...')` for Stripe object mocks
- Use `.exists?(condition)` for efficient existence checks

## Database & Environment

### Local Development
```bash
# Docker postgres config doesn't work outside container
# Use this for local development:
export DATABASE_URL="postgres://jward@localhost/covertext_test"
```

### Migration Patterns
- Use `foreign_key: true` and `null: false` for required associations
- Use `index: true` for frequently queried columns
- Use `unique: true` for columns that must be unique
- Stripe IDs: `unique: true, allow_nil: true` (unique when present, but optional)

### Common Issues
- Agency.has_many :users causes "agency_id does not exist" - users belong to Account
- When adding account_id to existing model, temporarily remove has_many until migration runs

## Do Not Add (Yet)
- AI, chatbots, or LLMs.
- HawkSoft CRM integration.
- Staff inboxes or manual approval workflows.
- Complex permission systems or over-engineered abstractions.

## Service Object Patterns

### Telnyx Service Objects
Services that interact with Telnyx API follow these conventions:

**API Key Configuration:**
```ruby
def configure_telnyx!
  api_key = Rails.application.credentials.dig(:telnyx, :api_key) || ENV["TELNYX_API_KEY"]

  unless api_key
    raise "Telnyx API key not configured. Please set it in Rails credentials or ENV."
  end

  # CRITICAL: Must set API key on Telnyx module before making API calls
  ::Telnyx.api_key = api_key
end
```

**Error Handling:**
- Log technical errors for debugging: `Rails.logger.error "[ServiceName] Error: #{e.message}"`
- Return user-friendly messages via Result object
- Never expose technical details (API errors, stack traces) to users
- Use case statements to map error types to friendly messages:
  ```ruby
  user_message = case e.message
  when /API key/i
    "Service configuration issue. Please contact support."
  when /specific error pattern/i
    "User-friendly explanation. Please contact support."
  else
    "Unable to complete action. Please contact support."
  end
  ```

**Result Object Pattern:**
```ruby
class Result
  attr_reader :success, :message, :data

  def initialize(success:, message:, data: nil)
    @success = success
    @message = message
    @data = data
  end

  def success?
    @success
  end
end
```

**Example:** See `app/services/telnyx/phone_provisioning_service.rb`
- Configures Telnyx gem before making API calls
- Maps technical errors to user-friendly messages
- Logs full error details for debugging
- Returns Result object with success/failure state

## Local Development
```bash
bin/setup
bin/dev
```

## Testing
```bash
bin/rails test              # Run all tests
bin/rails test:system       # Run system tests
bin/ci                      # Full CI suite (style, security, tests)
```

### CI Pipeline
The `bin/ci` command runs:
1. **Setup:** `bin/rails db:test:prepare` (only touches test DB, not development)
2. **Style checks:**
   - `bin/rubocop` - Ruby code style
   - `bundle exec erb_lint --lint-all` - ERB template linting (autocomplete attributes, closing tags, etc.)
3. **Security audits:** bundler-audit, importmap audit, Brakeman
4. **Tests:** Rails tests

**Important:** `bin/ci` does not run seeds. Seeds are dev convenience data only.

### ERB Linting
- Configuration: `.erb_lint.yml`
- Checks for: missing autocomplete attributes, unclosed tags, accessibility issues
- Run manually: `bundle exec erb_lint --lint-all`
- Add autocomplete to all form inputs: `autocomplete="email"`, `autocomplete="name"`, `autocomplete="new-password"`, etc.

## CI Expectations
- CI must be green before merging.
- GitHub Actions: CI → Publish Docker → Deploy (sequential)
- Security tools: Brakeman, bundler-audit, importmap audit must pass.
- Style checks: Rubocop + ERB Lint must pass.
- All tests must pass (currently 473 tests).

## Deployment
- Kamal to production (see docs/DEPLOYMENT.md)
- Secrets from 1Password via service account token
- Keep secrets out of git; use Rails credentials and .kamal/secrets
- Docker images: `ghcr.io/workhorse-solutions/covertext` (lowercase required)

## Ralph Autonomous Agent

Ralph is an optional autonomous agent system for implementing multi-story features. It's configured specifically for CoverText conventions.

### When to Use Ralph
- Multi-story features with clear requirements
- Repetitive implementation (migrations, CRUD, tests)
- Features following established patterns
- When you want to focus on planning, not typing

### Ralph Workflow
1. Create PRD in `docs/prd/` (manually or with Amp prd skill)
2. Convert to `scripts/ralph/prd.json` (use Amp ralph skill)
3. Run: `cd scripts/ralph && ./ralph.sh --tool amp 20`
4. Ralph implements stories, updates progress.txt, commits
5. Review commits, run `bin/ci`, merge

### Ralph Configuration
- **Prompt:** `scripts/ralph/prompt.md` (CoverText-customized)
- **PRD Skill:** `scripts/ralph/skill_prd.md` (generates docs/prd/ files)
- **Converter Skill:** `scripts/ralph/skill_ralph.md` (creates prd.json)
- **Progress Log:** `scripts/ralph/progress.txt` (learning log)
- **Documentation:** `scripts/ralph/README.md` (full workflow guide)

Ralph reads AGENTS.md and copilot-instructions.md on every iteration, so updating those files improves Ralph's behavior.

## Common Gotchas
- Always verify existing implementation before adding features (earlier stories may satisfy later ones)
- BillingController must skip subscription check so users can fix billing issues
- Helper methods exist for a reason - use them instead of duplicating query logic
- When PRD specifies new data model, update test expectations to match
- Ralph story sizing: one story = one iteration (too big = runs out of context)
- **Heroicon gem does NOT accept `class:` parameter** - wrap heroicon in `<span class="...">` instead (see View Conventions section)
- **Use ViewComponents for view logic** - don't add helper methods for formatting/display; create a `UI::` component instead (e.g., `UI::PhoneNumberComponent`)

## Known Test Issues
- **Resolved (Feb 2026):** Previously had flaky test failures caused by `db:seed:replant` running
  in CI and polluting WebMock stubs / ENV vars. Fixed by removing the seed CI step.
  All 473 tests now pass consistently.

- **Test environment notes**:
  - WebMock stubs for Stripe API configured in test_helper.rb
  - ENV vars set before Rails loads in test_helper.rb
  - Tests disabled: parallelize(workers: 1) due to historical WebMock issues

## Rails Credentials & Test Environment
- Test environment needs `config/credentials/test.yml.enc` file to exist
- If missing, run: `EDITOR="echo '# Test credentials' >" bin/rails credentials:edit --environment test`
- Stripe initializer and database.yml must gracefully handle missing credentials
- Pattern: `ENV["KEY"] || Rails.application.credentials.dig(:key) rescue nil`
- Set test ENV vars BEFORE `require_relative "../config/environment"` in test_helper.rb

---

## Maintaining This Document

**This is a living document.** All AI agents working on CoverText should:

### Before Starting Work:
1. Read this file completely
2. Read `.github/copilot-instructions.md` for project overview
3. Read `.github/agent-checklist.md` for agent standard operating procedures
4. Check `scripts/ralph/progress.txt` for recent learnings (if using Ralph)

### While Working:
- When you discover a new pattern or solve a tricky issue, note it
- If you find incorrect information here, fix it immediately
- When you encounter a gotcha that cost you time, add it to "Common Gotchas"

### After Completing Work:
1. Update relevant sections with new patterns discovered
2. If using Ralph: Ralph automatically updates `scripts/ralph/progress.txt`
3. If working manually: Update AGENTS.md with new patterns directly (no separate progress log)
4. If you created new conventions (controller patterns, model methods, etc.), document them

### What to Document:
- **Data model relationships** that aren't obvious from code
- **Controller/helper method patterns** that should be reused
- **Testing conventions** discovered through trial and error
- **Deployment/infrastructure gotchas** that caused issues
- **Database migration patterns** that worked well
- **Common mistakes** and their solutions

### Update Template:
When adding new information, use this structure:
```markdown
### [Section Name]
- [Specific pattern/rule]
- Why: [Reasoning or context]
- Example: [Code snippet or file reference]
```

**Goal:** Every agent after you should make fewer mistakes and move faster.
