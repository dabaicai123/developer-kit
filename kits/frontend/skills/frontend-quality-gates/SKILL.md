---
name: frontend-quality-gates
description: "Defines delivery quality gates for Next.js frontend projects: TypeScript strictness, lint/build checks, visual review, responsive verification, accessibility basics, loading/error/empty states, Playwright smoke tests, and release readiness. Use before shipping migrated pages, API-backed UI, Supabase flows, or frontend features."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Frontend Quality Gates

Use this skill before considering frontend work complete. It is intentionally
small and strict: verify the app builds, renders, handles API states, and stays
usable across breakpoints.

## Required Checks

Run the checks already present in the project. Common commands:

```bash
npm run lint
npm run typecheck
npm run test
npm run build
```

If a command does not exist, do not invent a large toolchain during a feature
task. Report the missing command and run the available checks.

## Visual and Responsive Review

For pages migrated from HTML/CSS or template sources:

- Compare source and Next.js output at mobile, tablet, and desktop widths.
- Check spacing, typography, colors, shadows, borders, radius, and image crop.
- Verify text does not overflow buttons, cards, navigation, or form fields.
- Verify sticky/fixed headers, sidebars, modals, and menus do not overlap
  content.
- Confirm hover, active, focus-visible, disabled, selected, loading, error, and
  empty states.

Use the design system preview page from `html-css-nextjs-migration` to inspect
tokens and shared components.

## API-Backed UI States

Every API-backed view must handle:

- Initial loading.
- Background refetching when relevant.
- Error with retry or recovery path.
- Empty state.
- Success state.
- Mutation pending, success, and failure.

Use `tanstack-query` for client-owned server state and
`frontend-api-contracts` for API contract boundaries.

## Accessibility Basics

Check the basics without turning every task into a full audit:

- Use semantic HTML before ARIA.
- Inputs have labels or accessible names.
- Buttons and links have distinct roles and visible focus states.
- Keyboard users can operate menus, dialogs, tabs, forms, and navigation.
- Images have useful `alt` text or empty `alt` when decorative.
- Color is not the only signal for errors or status.

## Smoke Tests

Add or update Playwright smoke tests for critical flows:

- App renders the main route without runtime errors.
- Supabase auth pages render and show validation states.
- API-backed list/detail pages handle mocked success and error responses.
- Important forms can submit or show validation feedback.

Prefer a small smoke suite over broad brittle tests.

## Release Readiness

Before final response or handoff:

- Confirm what checks were run.
- Name any checks that could not run and why.
- Confirm known environment requirements, especially Supabase and backend API
  variables.
- Confirm there are no unrelated file changes.
- Update `AGENTS.md` when architecture, commands, or quality gates change.

## Completion Checklist

- [ ] Available lint/type/test/build checks were run.
- [ ] Visual review covered relevant breakpoints.
- [ ] API-backed states are implemented.
- [ ] Basic accessibility was checked.
- [ ] Critical smoke tests exist or the gap is documented.
- [ ] Handoff includes commands run and remaining risks.
