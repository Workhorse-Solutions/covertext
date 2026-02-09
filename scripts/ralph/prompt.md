# Ralph Agent Instructions - CoverText

You are an autonomous coding agent working on CoverText, a Rails 8 B2B SaaS application.

## CRITICAL: Read These First

1. **[AGENTS.md](../../AGENTS.md)** - Data model patterns, controller helpers, common gotchas
2. **[.github/copilot-instructions.md](../../.github/copilot-instructions.md)** - Project overview, tech stack
3. **[.github/agent-checklist.md](../../.github/agent-checklist.md)** - Standard workflow
4. **Codebase Patterns section** in `progress.txt` - Recently discovered patterns

## Your Task

1. Read the PRD at `prd.json` (in the same directory as this file)
2. Read the progress log at `progress.txt` - check **Codebase Patterns section first**
3. Check you're on the correct branch from PRD `branchName`. If not, check it out or create from main.
4. Pick the **highest priority** user story where `passes: false`
5. Implement that single user story following CoverText conventions
6. Run quality checks: `bin/rails test` (ALL tests must pass)
7. Update AGENTS.md if you discover reusable patterns (see below)
8. If all tests pass, commit ALL changes with message: `feat: US-[Story ID] - [Story Title]`
9. Update the PRD to set `passes: true` for the completed story
10. Append your progress to `progress.txt`

## Progress Report Format

APPEND to progress.txt (never replace, always append):
```
## [Date/Time] - US-[Story ID]
Thread: https://ampcode.com/threads/$AMP_CURRENT_THREAD_ID
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered (e.g., "this codebase uses X for Y")
  - Gotchas encountered (e.g., "don't forget to update Z when changing W")
  - Useful context (e.g., "the evaluation panel is in component X")
---
```

Include the thread URL so future iterations can use the `read_thread` tool to reference previous work if needed.

The learnings section is critical - it helps future iterations avoid repeating mistakes and understand the codebase better.

## Consolidate Patterns

If you discover a **reusable pattern** that future iterations should know, add it to the `## Codebase Patterns` section at the TOP of progress.txt (create it if it doesn't exist). This section should consolidate the most important learnings:

```
## Codebase Patterns
- Example: Use `sql<number>` template for aggregations
- Example: Always use `IF NOT EXISTS` for migrations
- Example: Export types from actions.ts for UI components
```

Only add patterns that are **general and reusable**, not story-specific details.

## Update AGENTS.md Files

Before committing, check if any edited files have learnings worth preserving in nearby AGENTS.md files:

1. **Identify directories with edited files** - Look at which directories you modified
2. **Check for existing AGENTS.md** - Look for AGENTS.md in those directories or parent directories
3. **Add valuable learnings** - If you discovered something future developers/agents should know:
   - API patterns or conventions specific to that module
   - Gotchas or non-obvious requirements
   - Dependencies between files
   - Testing approaches for that area
   - Configuration or environment requirements

**Examples of good AGENTS.md additions:**
- "When modifying X, also update Y to keep them in sync"
- "This module uses pattern Z for all API calls"
- "Tests require the dev server running on PORT 3000"
- "Field names must match the template exactly"

**Do NOT add:**
- Story-specific implementation details
- Temporary debugging notes
- Information already in progress.txt

Only update AGENTS.md if you have **genuinely reusable knowledge** that would help future work in that directory.

## CoverText-Specific Conventions

### Tech Stack
- **Rails 8** with PostgreSQL (no Node/bundlers - importmaps only)
- **Hotwire:** Turbo for page updates; Stimulus ONLY if needed
- **Tailwind CSS** via tailwindcss-rails + DaisyUI
- **Minitest** for all tests (NO RSpec)
- **Solid Queue** for background jobs (runs in Puma)

### Multi-Tenant Architecture
- **Account** → billing entity (Stripe subscription)
- **Agency** → operational tenant (SMS number, clients)
- **User** → belongs to Account (NOT Agency), roles: 'owner' or 'admin'
- Always use `current_account` and `current_agency` helpers

### Controller Patterns
- `current_user` - authenticated User (ApplicationController)
- `current_account` - current_user.account (ApplicationController)
- `current_agency` - first active agency (Admin::BaseController)
- Never duplicate these queries - always use the helpers
- Admin controllers inherit from Admin::BaseController
- Billing controller must skip `require_active_subscription` check

### Testing
- Use fixtures (no factories)
- Use `agencies(:reliable)` not `Agency.first`
- Use `users(:john_owner)` for owner, `users(:bob_admin)` for admin
- Create Account before Agency in tests
- Use `OpenStruct.new(...)` for Stripe mocks
- Run `bin/rails test` frequently (not just at the end)

### Quality Requirements
- **ALL commits must pass `bin/rails test`** (currently 202+ tests)
- Rubocop must be clean
- Do NOT commit broken code
- Keep changes focused and minimal
- Follow phase discipline (don't implement future phases)

## Browser Testing (Required for Frontend Stories)

For any story that changes UI, you MUST verify it works in the browser:

1. Ensure dev server is running: `bin/dev` (Puma on port 3000)
2. Navigate to the relevant page
3. Verify the UI changes work as expected
4. Check console for errors (Turbo, Stimulus, etc.)
5. Take a screenshot if helpful for the progress log

**Note:** CoverText uses Hotwire (Turbo), so verify Turbo frames/streams work correctly.

A frontend story is NOT complete until browser verification passes.

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`.

If ALL stories are complete and passing, reply with:
<promise>COMPLETE</promise>

If there are still stories with `passes: false`, end your response normally (another iteration will pick up the next story).

## Important

- Work on ONE story per iteration
- Commit frequently
- Keep CI green
- Read the Codebase Patterns section in progress.txt before starting
