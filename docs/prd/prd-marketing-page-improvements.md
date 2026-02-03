# PRD: Marketing Page Improvements for Launch

## Introduction

Refine CoverText's public marketing pages to achieve launch clarity, trust, and simplicity. This work focuses exclusively on unauthenticated public pages—no application logic, billing integration, or admin UI changes are included.

The goal is to ensure first-time visitors (independent insurance agency owners) can quickly understand what CoverText does, who it's for, how much it costs, and how to get started.

## Goals

- Present a consistent, professional public-facing experience across all marketing pages
- Communicate transparent, tiered pricing with clear value propositions
- Build trust through honest, non-hyperbolic copy
- Reduce friction for first-time visitors exploring the product

## User Stories

### US-001: Add Global Public Header
**Description:** As a first-time visitor, I want a consistent navigation header so I can easily find login and signup on any public page.

**Status:** ✅ Complete

**Acceptance Criteria:**
- [x] Header appears on homepage and all public marketing pages
- [x] Left side displays "CoverText" wordmark (text-based logo)
- [x] Right side contains "Sign In" link routing to `/login`
- [x] Right side contains primary CTA button ("Get Started") routing to signup flow
- [x] Header is visually lightweight, does not distract from hero content
- [x] No visual overlap or broken layout on mobile viewports

---

### US-002: Replace "Start a Pilot" Language in Signup Flow
**Description:** As a visitor, I want clear CTA language so I understand I can start a free trial without ambiguity.

**Status:** ⚠️ Partially Complete - signup page still has "Pilot" references

**Acceptance Criteria:**
- [x] Marketing page CTAs use "Start Free Trial" or "Get Started"
- [ ] Signup page title changed from "Start Your Pilot" to "Start Your Free Trial"
- [ ] Plan selection removed (tier determined by which CTA was clicked)
- [ ] No public or signup pages contain the word "Pilot"
- [ ] Typecheck/lint passes
- [ ] Verify in browser using dev-browser skill

**Files to update:**
- `app/views/registrations/new.html.erb` - Change heading, remove plan radio buttons
- `app/controllers/registrations_controller.rb` - Accept plan parameter from URL

---

### US-007: Pass Selected Tier from Marketing to Signup
**Description:** As a visitor, when I click "Get Started" on a specific pricing tier, I want to sign up for that tier without having to select it again.

**Status:** ❌ Not Started

**Acceptance Criteria:**
- [ ] Each pricing tier's CTA passes plan identifier (e.g., `?plan=starter`, `?plan=professional`, `?plan=enterprise`) to signup URL
- [ ] Signup page accepts and validates plan parameter
- [ ] Signup page displays selected tier name prominently (e.g., "Start Your Free Trial - Professional Plan")
- [ ] Registration controller uses plan parameter to determine correct Stripe price ID
- [ ] Default to "starter" if no plan parameter provided
- [ ] Typecheck/lint passes
- [ ] Verify in browser using dev-browser skill

**Files to update:**
- `app/views/marketing/index.html.erb` - Add `?plan=X` to pricing CTA URLs
- `app/views/registrations/new.html.erb` - Display selected plan, remove radio buttons
- `app/controllers/registrations_controller.rb` - Read plan param, map to Stripe price ID

---

### US-008: Configure Stripe for 3-Tier Pricing
**Description:** As a system administrator, I want Stripe configured with all 3 pricing tiers so subscriptions can be created for Starter, Professional, and Enterprise plans.

**Status:** ❌ Not Started

**Acceptance Criteria:**
- [ ] Create Stripe Price IDs for:
  - Starter: $49/month ($490/year)
  - Professional: $99/month ($950/year)
  - Enterprise: $199/month ($1990/year)
- [ ] Update `CREDENTIALS_SETUP.md` with new price IDs
- [ ] Update `registrations_controller.rb` to map plan names to correct price IDs
- [ ] Remove or deprecate "pilot" plan references in Stripe
- [ ] Test checkout flow for all 3 tiers in Stripe test mode
- [ ] Document in `STRIPE_SETUP.md`

**Files to update:**
- `app/models/account.rb` - Add migration for `plan_tier` column
- `app/controllers/registrations_controller.rb` - Update `stripe_price_id_for_plan` method, set `plan_tier` on Account creation
- `app/controllers/webhooks/stripe_webhooks_controller.rb` - Map Stripe price ID to tier and update Account's `plan_tier`
- `docs/CREDENTIALS_SETUP.md` - Document new price IDs
- `docs/STRIPE_SETUP.md` - Update setup instructions

---

### US-003: Refine Hero and Marketing Copy
**Description:** As a visitor, I want clear, professional copy so I quickly understand what CoverText does.

**Status:** ✅ Complete

**Acceptance Criteria:**
- [x] Hero subheadline is readable and confidence-building
- [x] Tone is professional and insurance-appropriate (no hype, no jargon)
- [x] No new features are implied beyond current product behavior
- [x] Existing feature explanations preserved unless clearly improved

---

### US-004: Refine "What CoverText Does NOT Do" Section
**Description:** As a visitor, I want to understand product boundaries so I have realistic expectations.

**Status:** ✅ Complete

**Acceptance Criteria:**
- [x] Section remains visible on homepage
- [x] Language is unambiguous and non-technical
- [x] Clear distinction between CoverText billing (subscription) vs. agency client billing/payments
- [x] No over-promising or confusion about capabilities

---

### US-005: Add Consistent Footer Navigation
**Description:** As a visitor, I want footer links so I can access legal pages and contact information without scrolling to top.

**Status:** ✅ Complete (Note: "Log in" link not in footer, but in header)

**Acceptance Criteria:**
- [x] Footer includes "Contact" link (mailto)
- [x] Footer includes "Privacy Policy" link
- [x] Footer includes "Terms of Service" link
- [x] All footer links function correctly
- [x] Footer appears on all public pages

---

### US-006: Refine Compliance/Trust Language
**Description:** As a visitor, I want to trust that CoverText handles SMS responsibly without seeing overclaimed certifications.

**Status:** ✅ Complete

**Acceptance Criteria:**
- [x] Existing compliance section retained
- [x] No claims of certification or legal guarantees
- [x] Messaging conveys "built with SMS compliance in mind" without over-promising
- [x] Tone remains professional and appropriately cautious

---

## Functional Requirements

- **FR-001:** ✅ Add a global header component to all public marketing pages with CoverText wordmark (left), "Sign In" link (right), and "Get Started" button (right)
- **FR-002:** ⚠️ Replace remaining instances of "Pilot" language in signup flow with "Free Trial" terminology
- **FR-003:** ✅ Display 3-tier pricing (Starter $49, Professional $99, Enterprise $199) with monthly/yearly toggle, clear feature differentiation, and "Save 20%" annual discount
- **FR-004:** ✅ Refine hero subheadline and marketing copy for clarity, professionalism, and accuracy
- **FR-005:** ✅ Update "What CoverText Does NOT Do" section to clarify billing terminology and maintain explicit product boundaries
- **FR-006:** ✅ Add footer navigation with "Contact", "Privacy Policy", and "Terms of Service" links on all public pages
- **FR-007:** ✅ Adjust compliance/trust language to avoid legal overclaims while maintaining professional credibility
- **FR-008:** ❌ Pass selected pricing tier from marketing page CTAs to signup flow via URL parameter
- **FR-009:** ❌ Update signup page to display selected tier and remove manual plan selection
- **FR-010:** ❌ Configure Stripe with 3 pricing tiers (Starter/Professional/Enterprise) and map to subscription creation flow

## Non-Goals (Out of Scope)

- No demo scheduling flow or contact forms (Enterprise uses "Contact Sales" placeholder)
- No testimontier enforcement beyond Stripe subscription (honor system for limits)
- No graphic logo design work (text wordmark only)
- No major visual redesign—reuse existing Tailwind/DaisyUI components
- No billing admin UI changes (can update post-launch)s where appropriate)
- No backend pricing tier enforcement (billing logic remains single-tier for now)
- No graphic logo design work (text wordmark only)
- No major visual redesign—reuse existing Tailwind/DaisyUI components

## Design Considerations

- Reuse existing Tailwind CSS and DaisyUI component system
- Text-based "CoverText" wordmark is sufficient (no graphic logo)
- Mobile responsiveness required for all changes
- Header is visually lightweight with sticky positioning
- Maintain existing page layout structure
- Pricing components (UI::PricingCardComponent, UI::PricingSectionComponent) support rich styling options

## Technical Considerations

- Marketing page changes are frontend/view-only (ERB templates, ViewComponents)
- No database migrations required for marketing pages
- No controller or model changes for marketing pages
- Shared header/footer exist in application.html.erb layout
- Routes for login and signup already exist
- Pricing display uses CSS `group-has-[[value=yearly]:checked]` selectors for toggle functionality
- ViewComponents follow established patterns (UI::CardComponent, UI::SectionComponent, etc.)

## Success Metrics

- First-time visitors understand what CoverText does, who it's for, how much it costs, and how to get started within 10 seconds
- Public pages feel trustworthy to insurance agency owners
- Clear understanding of 3 pricing tiers and when to choose each
- No confusion about "Pilot" vs "Free Trial" language
- Visitors can click a pricing tier's CTA and sign up for that specific tier without re-selecting
- Stripe subscription created with correct price ID for selected tier

## Implementation Notes

### Tier Selection Flow
1. User clicks "Get Started" on Professional tier pricing card
2. Marketing page redirects to `/signup?plan=professional`
3. Signup page reads plan parameter, displays "Start Your Free Trial - Professional Plan"
4. On form submit, registration controller maps "professional" → Stripe price ID for Professional tier
5. Stripe subscription created, user redirected to admin dashboard

### Stripe Price ID Mapping
```ruby
# app/controllers/registrations_controller.rb
def stripe_price_id_for_plan(plan)
  case plan
  when "starter"
    Rails.application.credentials.dig(:stripe, :starter_price_id)
  when "professional"
    Rails.application.credentials.dig(:stripe, :professional_price_id)
  when "enterprise"
    Rails.application.credentials.dig(:stripe, :enterprise_price_id)
  else
    Rails.application.credentials.dig(:stripe, :starter_price_id) # default
  end
end
```

### Stripe Configuration Required
Create products and prices in Stripe dashboard or via API:
- **Starter Plan:** $49/month (price_starter_monthly) and $490/year (price_starter_yearly)
- **Professional Plan:** $99/month (price_pro_monthly) and $950/year (price_pro_yearly)
- **Enterprise Plan:** $199/month (price_ent_monthly) and $1990/year (price_ent_yearly)

Store price IDs in Rails credentials:
```yaml
stripe:
  starter_price_id: price_xxx
  professional_price_id: price_xxx
  enterprise_price_id: price_xxx
```

Note: Marketing page toggle shows monthly/yearly prices, but Stripe integration currently uses monthly pricing only. Annual billing can be added in a future iteration.

### Tier Storage and Feature Gating
The backend needs to know subscription tier for feature gating:

**Two approaches to tier determination:**

**Option A: Query Stripe API on-demand** (no migration needed)
- Use existing `stripe_subscription_id` to query Stripe: `Stripe::Subscription.retrieve(account.stripe_subscription_id)`
- Read `subscription.items.data[0].price.id` from response
- Map price ID → tier using reverse lookup of stored price IDs
- **Pros:** No new database column, always accurate, handles plan changes automatically
- **Cons:** API call on every request that checks features (latency, rate limits, external dependency)
- **Use case:** Simple apps with infrequent feature checks

**Option B: Store tier locally in Account** (recommended)
- Migration: `add_column :accounts, :plan_tier, :string, default: "starter"`
- Set during signup from plan parameter
- Update via Stripe webhooks when subscription changes
- **Pros:** Fast lookups (no API calls), works offline for feature checks
- **Cons:** Requires migration, must keep in sync via webhooks
- **Use case:** Production apps with frequent feature checks (e.g., every request)

**Recommended approach: Option B** - Store `plan_tier` locally and keep it in sync via Stripe webhooks. This avoids API calls on every request where feature gating is checked.

Implementation flow:
1. **Signup:** Set `account.plan_tier` based on selected plan parameter
2. **Stripe checkout:** Create subscription with correct price ID for tier
3. **Webhooks:** Map Stripe price ID → tier and update `account.plan_tier`
   - `subscription.created`, `subscription.updated`: Read price ID, determine tier, update `plan_tier`
4. **Feature checks:** `current_account.plan_tier` for instant lookups

Example tier-based features:
- **Starter:** 1 active agency, basic SMS features
- **Professional:** 3 active agencies, priority card delivery, custom branding
- **Enterprise:** Unlimited agencies, API access, dedicated support, priority everything

**Note:** Feature gating implementation (permission checks, limits enforcement) will be a separate PRD after marketing launch. This PRD only covers tier selection and storage.
- Do we need to enforce tier limits in backend logic, or keep it honor-system for now?
