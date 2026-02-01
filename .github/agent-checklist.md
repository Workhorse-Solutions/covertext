# AI Agent Workflow Checklist

Use this checklist for every work session to ensure consistency and knowledge capture.

## Before Starting Work

- [ ] Read [AGENTS.md](../AGENTS.md) completely
- [ ] Read [.github/copilot-instructions.md](copilot-instructions.md) for project context
- [ ] Review recent entries in [tasks/progress.txt](../tasks/progress.txt)
- [ ] Check current CI status (tests passing? rubocop clean?)
- [ ] Identify which Phase this work belongs to

## During Work

- [ ] Follow phase discipline (don't implement future phases)
- [ ] Use existing helper methods (don't duplicate logic)
- [ ] Write tests for new functionality
- [ ] Run `bin/rails test` frequently
- [ ] Note any patterns or gotchas you discover
- [ ] If you find outdated info in AGENTS.md, fix it immediately

## After Completing Work

- [ ] Run `bin/ci` (must be green)
- [ ] Update AGENTS.md with any new patterns discovered
- [ ] Add entry to tasks/progress.txt with:
  - User story number (if applicable)
  - What was implemented
  - Key learnings for future iterations
  - Files changed
- [ ] Commit with clear message describing what and why
- [ ] Push changes

## Before Handing Off

- [ ] All tests passing (check CI)
- [ ] Documentation updated (AGENTS.md, progress.txt)
- [ ] No outstanding TODOs that block current phase
- [ ] Leave clear notes about any incomplete work

---

**Remember:** Every update you make to AGENTS.md makes the next agent's job easier. Pay it forward!
