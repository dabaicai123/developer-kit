---
name: frontend-verify
description: "Run frontend quality gates for migrated pages and API-backed UI"
argument-hint: "<route or feature scope>"
allowed-tools: Read, Bash, Glob, Grep
model: inherit
---

# Frontend Verification

Verify frontend work before handoff.

## Use Skills

- `frontend-quality-gates`
- `html-css-nextjs-migration`
- `tanstack-query`
- `frontend-api-contracts`

## Workflow

1. Inspect changed files and affected routes.
2. Run available lint, typecheck, test, and build commands.
3. Check migrated UI against source or design system preview.
4. Verify API-backed loading, error, empty, success, and mutation states.
5. Check accessibility basics.
6. Report findings, checks run, skipped checks, and residual risks.
