---
paths:
  - "app/**/*.ts"
  - "app/**/*.tsx"
  - "src/**/*.ts"
  - "src/**/*.tsx"
  - "lib/supabase/**"
  - "proxy.ts"
---

# Next.js Supabase Conventions

Use `nextjs-supabase-template` for Supabase project setup and auth/session
boundaries.

## Rules

- Keep browser and server Supabase clients separate.
- Create Supabase server clients per request; do not store them in module-global
  state.
- Keep session refresh/protected-route logic in the project proxy or equivalent
  auth boundary.
- Put only publishable/anon values in `NEXT_PUBLIC_*` variables.
- Never expose service-role keys to client code.
- Document required Supabase env vars in `.env.example` and `AGENTS.md`.

## Avoid

- Mixing Supabase session logic into unrelated UI components.
- Hardcoding Supabase URLs or keys in source files.
