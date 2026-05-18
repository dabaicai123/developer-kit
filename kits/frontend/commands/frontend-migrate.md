---
name: frontend-migrate
description: "Migrate native HTML/CSS from temp/ into the current Next.js frontend"
argument-hint: "<source directory, default temp/>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

# Frontend Migration

Migrate a native HTML/CSS frontend into the current Next.js project.

## Use Skills

- `html-css-nextjs-migration`
- `nextjs-supabase-template`
- `tanstack-query`
- `frontend-api-contracts`
- `frontend-quality-gates`

## Workflow

1. Inspect the source directory, defaulting to `temp/`.
2. Extract design tokens, reusable components, routes, assets, and behavior.
3. Preserve Supabase project structure and auth/session files.
4. Rebuild pages from reusable components.
5. Add or update `AGENTS.md`.
6. Add or update the development-only design system preview route.
7. Wire API-backed sections through API contracts and TanStack Query.
8. Run available quality gates and report checks.

## Output

End with:

- Files changed.
- Routes migrated.
- Components/design tokens created.
- API contracts or mocks added.
- Checks run and remaining risks.
