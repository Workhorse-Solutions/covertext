PROJECT CONTEXT – READ FIRST

You are helping build a new Rails 8 B2B SaaS product called CoverText.

CoverText provides independent insurance agencies with a dedicated SMS phone number
that clients can text to request insurance information.

The text conversation is the user interface.

For now, the product:
- Is multi-tenant (each agency is a tenant)
- Uses deterministic logic (no AI/LLMs)
- Uses mock data instead of HawkSoft
- Automates fulfillment (no staff interaction)

SUPPORTED CLIENT FLOWS (eventually):
1) Insurance card request (automated MMS delivery)
2) Policy expiration lookup (automated text response)
3) Unsupported / absurd requests (graceful handling + menu)

STACK & RULES
-------------
- Rails 8
- PostgreSQL
- Hotwire (Turbo; Stimulus only if needed)
- importmaps-only (no Node, no bundlers)
- ActiveStorage for documents
- Background jobs for non-trivial work
- Minitest for all tests (no RSpec)

IMPORTANT: This project is built in PHASES.
Each phase is intentionally small and must ship cleanly before the next phase.

DO NOT:
- Add AI, chatbots, or LLMs
- Add HawkSoft integration yet
- Add staff inboxes or manual approval
- Add complex permission systems
- Overengineer abstractions

PHASE DEFINITIONS
-----------------
Phase 0 – Data Model Foundation
- Models, migrations, associations, validations
- ActiveStorage setup
- Seed data with realistic mock records
- Minitest coverage for validations + uniqueness
- NO webhooks, NO jobs, NO conversation logic

Phase 1 – SMS plumbing (inbound/outbound skeleton)
Phase 2 – Conversation session state machine
Phase 3 – Intent routing + menu fallback
Phase 4 – Insurance card fulfillment (MMS)
Phase 5 – Policy expiration flow
Phase 6 – Admin dashboard (read-only)
Phase 7 – Hardening & polish
Phase M1 – Marketing & Monetization ✅ COMPLETE
- Public marketing homepage
- Self-serve agency signup with Stripe
- Subscription management & billing page
- Plan gating (active subscription + live_enabled flag)

## Documentation

- **[Stripe Setup](docs/STRIPE_SETUP.md)** - Stripe integration and configuration
- **[Credentials Setup](docs/CREDENTIALS_SETUP.md)** - Rails credentials configuration guide
- **[Deployment](docs/DEPLOYMENT.md)** - Kamal deployment instructions
- **[Environment Variables](docs/ENV_VARS.md)** - Environment variable reference

## Getting Started

### Development
```bash
bin/setup  # Install dependencies and setup database
bin/dev    # Start development server (Rails + Tailwind CSS watcher)
```

### Access the Application
- **Marketing Homepage**: http://localhost:3000/
- **Signup**: http://localhost:3000/signup
- **Admin Login**: http://localhost:3000/login
  - Email: john@reliableinsurance.example
  - Password: password123

### Testing
```bash
bin/rails test              # Run all tests
bin/rails test:system       # Run system tests (optional)
bin/ci                      # Run full CI suite locally
```

## Deployment

This application is configured for deployment using Kamal.

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment instructions.

## Contributing

When I say “Implement Phase X only” you must:
- Touch only the code required for that phase
- Not implement future phases early
- Add tests required for that phase
- Stop when tests are passing

If anything is unclear, choose the simplest implementation
that satisfies the current phase and leave TODOs for later phases.

Acknowledge this context before writing any code.
