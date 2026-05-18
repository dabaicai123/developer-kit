---
paths:
  - "app/**"
  - "src/**"
  - "components/**"
  - "tests/**"
  - "e2e/**"
  - "AGENTS.md"
---

# Frontend Quality Gates

Use `frontend-quality-gates` before handoff.

## Rules

- Run available lint, typecheck, test, and build commands.
- Verify responsive behavior for changed pages.
- Check loading, error, empty, success, and mutation states for API-backed UI.
- Check keyboard access and visible focus states for interactive controls.
- Add or update smoke tests for critical migrated or API-backed flows.
- Document skipped checks and environment blockers.

## Avoid

- Treating build success as visual verification.
- Shipping UI without error and empty states.
- Leaving `AGENTS.md` stale after architecture changes.
