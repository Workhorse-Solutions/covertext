# CoverText Agent Guide

## Context
- CoverText is a Rails 8 B2B SaaS for SMS-based insurance client service.
- The text conversation is the primary UI.
- Deterministic logic only (no AI/LLMs).
- Multi-tenant: each agency is a tenant.

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

## Do Not Add (Yet)
- AI, chatbots, or LLMs.
- HawkSoft CRM integration.
- Staff inboxes or manual approval workflows.
- Complex permission systems or over-engineered abstractions.

## Local Development
```bash
bin/setup
bin/dev
```

## Testing
```bash
bin/rails test
bin/rails test:system
bin/ci
```

## CI Expectations
- CI should be green before merging.
- Keep security tools (Brakeman, bundler-audit, importmap audit) up to date.

## Deployment
- Kamal (see docs/DEPLOYMENT.md).
- Keep secrets out of git; use Rails credentials and .kamal/secrets.

## Notes
- Use realistic mock data (no HawkSoft yet).
- Favor simple, explicit implementations.
- Leave TODOs for later phases when needed.
