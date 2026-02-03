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
- [ ] Plan selection changed from "Pilot - $49/month" to match marketing tier names
- [ ] No public or signup pages contain the word "Pilot"
- [ ] Typecheck/lint passes
- [ ] Verify in browser using dev-browser skill

**Files to update:**
- `app/views/registrations/new.html.erb` - Change heading and plan naming
- `app/controllers/registrations_controller.rb` - Update plan_name logic if needed

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

## Non-Goals (Out of Scope)

- No demo scheduling flow or contact forms (Enterprise uses "Contact Sales" placeholder)
- No testimonials or case studies
- No AI/LLM messaging or features
- No changes to logged-in admin UI (except removing "Pilot" references where appropriate)
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
- Consistent CTA language across all touchpoints

## Open Questions

- Should we update billing admin UI to remove "Pilot" plan references?
- Should signup flow present all 3 pricing tiers or default to Starter?
- Do we need to enforce tier limits in backend logic, or keep it honor-system for now?
