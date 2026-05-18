---
paths:
  - "app/**/*.tsx"
  - "src/**/*.ts"
  - "src/**/*.tsx"
  - "components/**/*.tsx"
  - "lib/api/**"
---

# TanStack Query Conventions

Use `tanstack-query` for client-owned server state.

## Rules

- Configure a stable `QueryClientProvider` once near the app root.
- Keep query functions in API-layer files, not inline in UI components.
- Use array query keys and include every result-affecting parameter.
- Use `useMutation` for writes and invalidate or update the narrowest affected
  cache keys.
- Handle loading, error, empty, success, and mutation pending states.
- Use infinite queries only for load-more or infinite-scroll experiences.

## Avoid

- Raw `useEffect + fetch` for reusable server state.
- Mirroring server data in Zustand, context, or local state.
- Returning raw backend errors directly to UI components.
