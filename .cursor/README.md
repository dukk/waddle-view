# Cursor configuration (optional)

This directory contains [Cursor](https://cursor.com) rules, skills, agents, and hooks used by maintainers during development. **You do not need Cursor** to build, test, or run Waddle View.

- **Rules** (`.cursor/rules/`): coding conventions for display, controller, tests, and git hooks.
- **Skills** (`.cursor/skills/`): step-by-step checklists for common tasks.
- **Agents** (`.cursor/agents/`): delegated subagent prompts (QA, build-fix, etc.).
- **Hook state** (`.cursor/hooks/state/`): runtime JSON from QA/security hooks (gitignored). Never commit secrets from these files.

Human contributors should start with [CONTRIBUTING.md](../CONTRIBUTING.md) and [AGENTS.md](../AGENTS.md).
