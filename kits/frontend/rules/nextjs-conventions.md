---
paths:
  - "app/**/*.tsx"
  - "app/**/*.ts"
---

# Rule: Next.js Conventions

Enforce consistent Next.js App Router patterns. For detailed patterns, use `nextjs-app-router` and `react-best-practices` skills.

## Guidelines

1. **Follow file conventions** — `page.tsx` for routes, `layout.tsx` for wrappers, `loading.tsx` for Suspense fallbacks, `error.tsx` for error boundaries, `not-found.tsx` for 404s, `route.ts` for API endpoints. Each file has a single, well-defined purpose.

2. **Fetch data in server components** — use `async/await` directly in server components and `generateStaticParams` for static generation. Server components can access databases, APIs, and file systems without client-side fetch calls.

3. **Add `loading.tsx` and `error.tsx`** — every route segment with async data must have a `loading.tsx` Suspense fallback and an `error.tsx` boundary. Never leave users staring at a blank page during fetches or on errors.

4. **Use `generateMetadata` for SEO** — export `generateMetadata` or `metadata` from `page.tsx` for dynamic or static metadata. Never render `<title>` or `<meta>` tags manually in layout/page components.

5. **Use `next/image` and `next/font`** — always use `next/image` with proper `width`/`height` or `fill` for optimized image loading. Always use `next/font` for fonts to eliminate layout shift and external network requests.

6. **Use Server Actions for forms** — define server actions with `'use server'` directive for form submissions and mutations. Server Actions handle progressive enhancement and work without JavaScript.

7. **Use async params in Next.js 15+** — route params and searchParams are now Promises. Always `await params` and `await searchParams` in page and layout components.

## Anti-Patterns

- Client-side `fetch` when server component can access data directly — prefer server-side data fetching
- Missing `loading.tsx` or `error.tsx` for routes with async data — always provide Suspense and error boundaries
- Raw `<img>` tags instead of `next/image` — always use the Image component for optimization
- Raw font imports via `<link>` or CSS `@import` instead of `next/font` — always use the font module
- Synchronous access to `params` in Next.js 15+ — always `await` params and searchParams
- Manual `<title>` or `<meta>` tags — use `generateMetadata` or `metadata` export
- `'use client'` on page components — pages should be server components by default