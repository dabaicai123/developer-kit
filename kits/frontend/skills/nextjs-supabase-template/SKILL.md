---
name: nextjs-supabase-template
description: "Scaffolds a Next.js App Router frontend from the official Vercel with-supabase example, including Supabase Auth, @supabase/ssr cookie sessions, shadcn/ui components, Tailwind styling, and environment setup. Use when creating a Next.js + Supabase starter, auth template, SaaS frontend shell, or with-supabase project."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Next.js Supabase Template

Use this skill to create or adapt a frontend project based on the official
latest `vercel/next.js` `examples/with-supabase` starter.

## Workflow

### 1. Scaffold from the Latest Official Example

Run `create-next-app@latest` so the scaffold uses the latest published
generator and the current official `with-supabase` example:

```bash
npx create-next-app@latest --example with-supabase my-app
```

Package-manager variants:

```bash
npm create next-app@latest -- --example with-supabase my-app
pnpm create next-app@latest --example with-supabase my-app
yarn create next-app --example with-supabase my-app
```

If the target directory already exists, inspect it first. Generate into a new
directory unless the user explicitly asks to merge or replace files.

### 2. Configure Supabase

Create `.env.local` from `.env.example` and set:

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
```

Use the Supabase publishable key when available. A legacy anon key can be used
with the same variable name during migration. Never put a service-role key in a
browser-exposed `NEXT_PUBLIC_*` variable.

### 3. Preserve Auth Boundaries

After generation, inspect the current scaffold and keep its Supabase auth files
together unless deliberately redesigning auth. In the current official example,
the important boundaries are:

- `lib/supabase/client.ts` creates the browser client.
- `lib/supabase/server.ts` creates a per-request server client from cookies.
- `lib/supabase/proxy.ts` refreshes sessions and protects private routes.
- `proxy.ts` wires the Next.js Proxy matcher to Supabase session refresh.
- `app/auth/confirm/route.ts` handles email confirmation token exchange.

Do not move `createServerClient` into module-global state. Create a new Supabase
server client for each request or server function.

### 4. Avoid Remote Font Build Dependencies

The official example may import Google fonts through `next/font/google`, such as
`Geist` in `app/layout.tsx`. In restricted network environments, production
builds can fail while fetching fonts from Google. This is a build-time network
failure, not a Supabase configuration problem.

After scaffolding, inspect the generated layout and replace remote Google font
usage with a system font stack before running `npm run build`:

- Remove `next/font/google` imports and font initialization.
- Remove `font.variable`, `font.className`, or similar generated font references
  from the root layout.
- Define the app font in CSS with a local system stack, for example
  `font-family: Arial, Helvetica, sans-serif;`, or keep the existing project
  Tailwind/CSS pattern if it already defines a system stack.

Do not add another remote font provider unless the user explicitly accepts a
network-dependent build.

### 5. Adapt the UI

The template includes shadcn/ui-style primitives under `components/ui`, auth
forms, a protected route, and Tailwind styling. Keep the auth flow working
before replacing the marketing/tutorial content.

For larger UI changes, also use:

- `html-css-nextjs-migration` when migrating a native HTML/CSS frontend into
  the Supabase-enabled project shell.
- `tanstack-query` when authenticated client components consume backend APIs.
- `frontend-api-contracts` when documenting backend contracts, auth headers,
  environment variables, and response validation.
- `frontend-quality-gates` when verifying auth pages, protected routes, and
  release readiness.

### 6. Verify

Install dependencies and run the standard checks from the scaffolded project:

```bash
npm install
npm run lint
npm run build
```

If Supabase environment variables are unavailable, document that runtime auth
verification was skipped and still run static checks.
