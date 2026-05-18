---
name: frontend-api-contracts
description: "Defines frontend API contracts for Next.js projects that consume existing backend services: OpenAPI/Swagger client generation, typed fetch clients, Zod runtime validation, error envelopes, auth headers, environment variables, mocks, and contract-change workflow. Use when connecting a frontend to REST APIs, generated clients, backend endpoints, or external service contracts."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Frontend API Contracts

Use this skill when a Next.js frontend consumes an existing backend API. The
goal is a stable API boundary: typed requests, validated responses, predictable
errors, and a clear path when backend contracts change.

## Contract Source

Prefer contract-first integration in this order:

1. OpenAPI/Swagger schema from the backend.
2. Generated TypeScript client from OpenAPI.
3. Hand-written typed client when no schema exists.
4. Temporary mock contract when the backend is not ready.

If the backend exposes OpenAPI, use a generator such as Orval,
`openapi-typescript`, or `openapi-fetch`. Commit generated code only if the
project already commits generated artifacts; otherwise document the generation
command in `package.json`.

## API Layer Shape

Keep API code out of React components. Use a small layered structure:

```text
src/lib/api/
  client.ts          # base fetch, headers, error parsing
  errors.ts          # normalized error types
  schemas.ts         # Zod schemas for hand-written contracts
  query-keys.ts      # TanStack Query keys
  <domain>.api.ts    # endpoint functions
  <domain>.queries.ts # TanStack Query options/hooks
```

For generated clients, keep generated files in a clearly named folder such as
`src/lib/api/generated/` and write thin project-owned wrappers around them.

## Runtime Validation

Validate data at untrusted boundaries:

- Backend API responses.
- Form input before mutation calls.
- URL params and search params.
- Webhook-like or external service payloads.
- Local storage/session storage data.

Use Zod for hand-written API clients. Generated OpenAPI types improve compile
time safety, but they do not validate runtime payloads unless the generator or
wrapper adds validation.

## Error Model

Normalize backend errors before they reach UI components.

Required fields:

- `status`: HTTP status or equivalent transport status.
- `code`: stable backend error code when available.
- `message`: safe user-facing or fallback message.
- `details`: optional structured validation details.
- `requestId`: optional trace ID from headers or response body.

Components should render normalized errors, not raw `Response`, Axios errors,
or unknown thrown values.

## Auth and Environment

Define API base URLs and auth behavior once:

- Store backend base URLs in environment variables.
- Never expose server-only secrets through `NEXT_PUBLIC_*`.
- Use Supabase session, cookies, or backend-issued tokens according to the
  project auth model.
- Prefer a Next.js Route Handler or proxy when the browser must not see a
  backend URL, token, or header.
- Keep CORS and credential behavior explicit.

Document required variables in `.env.example` and `AGENTS.md`.

## TanStack Query Integration

Use `tanstack-query` for server state in Client Components:

- Query keys must include every parameter that affects the response.
- Query functions call API-layer functions, not inline `fetch`.
- Mutations call API-layer functions and invalidate or update the narrowest
  affected cache keys.
- Pagination and infinite queries must match backend cursor/offset semantics.

Do not duplicate server state in Zustand, React context, or local component
state.

## Mocks and Contract Testing

Use mocks to unblock frontend work and prevent regressions:

- Prefer MSW for browser-like API mocking in tests and local demos.
- Keep mock payloads close to schemas or generated types.
- Add tests for loading, error, empty, and success states.
- Add one smoke test for critical API-backed user journeys.

When backend contracts change, update the schema/generated client first, then
fix compile errors and validation failures.

## Completion Checklist

- [ ] API contract source is identified.
- [ ] API client boundary exists and components do not inline network logic.
- [ ] Responses and inputs are typed and validated where needed.
- [ ] Error model is normalized.
- [ ] Auth headers, cookies, and environment variables are documented.
- [ ] TanStack Query keys and invalidation are defined.
- [ ] Mocks or tests cover critical API states.
