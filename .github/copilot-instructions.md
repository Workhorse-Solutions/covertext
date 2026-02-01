# CoverText - AI Agent Instructions

**IMPORTANT:** Before starting any work, read [AGENTS.md](../AGENTS.md) for critical codebase patterns, data model conventions, and common gotchas. Update it when you learn new patterns.

## Project Overview
CoverText is a Rails 8 B2B SaaS that provides independent insurance agencies with SMS-based client interaction. The text conversation IS the user interface. This is a multi-tenant system using deterministic logic (no AI/LLMs) with automated fulfillment flows.

## Critical: Phase-Based Development
**This project is built in PHASES.** Each phase must ship cleanly before starting the next. When implementing:
- Touch ONLY code required for the current phase
- Do not implement future phases early
- Add tests required for that phase only
- Stop when tests pass

## Technology Stack & Hard Rules
- **Rails 8** with PostgreSQL
- **Hotwire:** Turbo for page updates; Stimulus ONLY if needed
- **No Node/bundlers:** importmaps-only (see [config/importmap.rb](../config/importmap.rb))
- **Tailwind CSS** via `tailwindcss-rails` gem with DaisyUI
- **ActiveStorage** for documents (insurance cards, etc.)
- **Solid Queue** for background jobs (runs in Puma via `SOLID_QUEUE_IN_PUMA=true`)
- **Solid Cache** and **Solid Cable** for Rails.cache and Action Cable
- **Minitest** for all tests (NO RSpec)
- **ViewComponent** + **Heroicon** for UI components

## DO NOT Add (Yet)
- AI, chatbots, or LLMs
- HawkSoft CRM integration
- Staff inboxes or manual approval workflows
- Complex permission systems
- Over-engineered abstractions

## Development Workflows

### Start Development Server
```bash
bin/dev
```
Runs Puma (port 3000) and Tailwind CSS watcher via Foreman ([Procfile.dev](../Procfile.dev)).

### Run Tests
```bash
bin/rails test              # Run all tests
bin/rails test:system       # Run system tests (optional)
```
Tests use parallel workers (`parallelize(workers: :number_of_processors)` in [test/test_helper.rb](../test/test_helper.rb)).

### Run CI Suite Locally
```bash
bin/ci
```
Runs full CI pipeline: Rubocop, Bundler Audit, Importmap audit, Brakeman, tests, and seed replant ([config/ci.rb](../config/ci.rb)).

### Deploy with Kamal
```bash
kamal deploy
```
Configured via [config/deploy.yml](../config/deploy.yml) using Docker images.

## Code Conventions

### Models
- Inherit from `ApplicationRecord` (see [app/models/application_record.rb](../app/models/application_record.rb))
- Add comprehensive Minitest model tests in `test/models/`

### Controllers
- Inherit from `ApplicationController` (see [app/controllers/application_controller.rb](../app/controllers/application_controller.rb))
- Routes defined in [config/routes.rb](../config/routes.rb)
- Use Turbo for responses when possible

### Views
- Main layout: [app/views/layouts/application.html.erb](../app/views/layouts/application.html.erb)
- Tailwind CSS with DaisyUI theme configured in [app/assets/tailwind/](../app/assets/tailwind/)
- Use ViewComponent for reusable components

### JavaScript
- Stimulus controllers in [app/javascript/controllers/](../app/javascript/controllers/)
- Pin imports via `bin/importmap pin <package>` (see [config/importmap.rb](../config/importmap.rb))
- Example controller: [app/javascript/controllers/hello_controller.js](../app/javascript/controllers/hello_controller.js)

### Background Jobs
- Inherit from `ApplicationJob` (see [app/jobs/application_job.rb](../app/jobs/application_job.rb))
- Use Solid Queue (runs inside Puma in dev/single-server deployments)
- Enqueue non-trivial work asynchronously

### Seeds & Test Data
- Seed file: [db/seeds.rb](../db/seeds.rb)
- Use realistic mock data (no HawkSoft integration yet)
- CI validates seeds can replant in test env

## Multi-Tenancy
Each insurance agency is a tenant. Design models and queries with tenant isolation in mind from Phase 0 onwards.

## When Unclear
Choose the simplest implementation that satisfies the current phase. Leave `# TODO: Phase X` comments for future work.
