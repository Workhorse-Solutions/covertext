# AI Agent Workflow Checklist

Use this checklist for every work session to ensure consistency and knowledge capture.

## Before Starting Work

- [ ] Read [AGENTS.md](../AGENTS.md) completely
- [ ] Read [.github/copilot-instructions.md](copilot-instructions.md) for project context
- [ ] Check `scripts/ralph/progress.txt` for recent learnings (if using Ralph)
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
- [ ] If using Ralph: progress automatically tracked in `scripts/ralph/progress.txt`
- [ ] If working manually: Document learnings directly in AGENTS.md
- [ ] Commit with clear message describing what and why
- [ ] Push changes

## Before Handing Off

- [ ] All tests passing (check CI)
- [ ] Documentation updated (AGENTS.md)
- [ ] No outstanding TODOs that block current phase
- [ ] Leave clear notes about any incomplete work

---

**Remember:** Every update you make to AGENTS.md makes the next agent's job easier. Pay it forward!
