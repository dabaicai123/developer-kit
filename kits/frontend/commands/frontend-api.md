---
name: frontend-api
description: "Integrate existing backend APIs into the frontend with TanStack Query"
argument-hint: "<API feature or endpoint description>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

# Frontend API Integration

Implement API-backed frontend behavior against an existing backend.

## Use Skills

- `frontend-api-contracts`
- `tanstack-query`
- `nextjs-supabase-template`
- `frontend-quality-gates`

## Workflow

1. Identify the backend contract source and required environment variables.
2. Create or update API-layer client functions outside UI components.
3. Define stable query keys and TanStack Query hooks/options.
4. Implement loading, error, empty, success, and mutation states.
5. Add mocks or smoke tests when the flow is critical.
6. Run available checks and document skipped runtime checks.

## Output

End with:

- Endpoints integrated.
- Query keys and invalidation behavior.
- Error handling and validation approach.
- Checks run and remaining risks.
