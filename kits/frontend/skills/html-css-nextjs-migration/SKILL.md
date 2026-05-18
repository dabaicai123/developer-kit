---
name: html-css-nextjs-migration
description: "Migrates a native HTML/CSS frontend directory such as temp/ into an existing Next.js project as a reusable design system and component architecture. Use when porting static HTML, CSS, assets, pages, layouts, interactions, or a temp/ prototype into maintainable Next.js React components with AGENTS.md guidance and a development-only design system preview page."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# HTML/CSS to Next.js Migration

Use this skill when the user provides a directory such as `temp/` containing
native HTML, CSS, images, and scripts, and asks to migrate it into the current
Next.js project while preserving visual fidelity and creating a maintainable
frontend component system.

## Primary Goal

Recreate the `temp/` frontend inside the current Next.js project with matching
visuals, layout, spacing, colors, typography, responsive behavior, and common
interaction states. Do not merely paste static markup into a page. Convert the
source into reusable React components, design tokens, and clear project
conventions.

## Workflow

### 1. Inventory the Source

Inspect the full `temp/` tree before editing the Next.js project:

- HTML pages, shared layout fragments, navigation, repeated sections, forms,
  cards, tables, modals, and empty/error states.
- CSS files, reset rules, variables, selectors, animations, media queries,
  container queries, and pseudo-class states.
- Assets, fonts, icons, images, background media, and relative URL references.
- JavaScript behavior, including menus, tabs, accordions, form interactions,
  sliders, filters, and scroll effects.

Record the page map and reusable UI patterns in notes before implementing.

### 2. Extract the Design System

Promote repeated visual values to project-owned tokens:

- Colors: background, surface, primary, secondary, text, muted text, border,
  focus, success, warning, danger, overlays.
- Typography: font families, font sizes, line heights, weights, labels,
  captions, headings, display text.
- Spacing: layout gutters, section padding, stack gaps, inline gaps, form gaps.
- Radius, shadows, borders, z-index layers, transitions, and motion durations.
- Breakpoints and responsive layout rules.

For Tailwind v4 projects, prefer `@theme` tokens in `app/globals.css`. For
projects using CSS Modules or plain CSS, create a small token layer that matches
the existing project style. Keep one-off values local instead of creating noisy
global tokens.

### 3. Plan the Component Architecture

Map repeated source patterns to reusable components before building pages:

- `Button`, `Card`, `Input`, `Textarea`, `Select`, `Checkbox`, `Badge`.
- `Navigation`, `Header`, `Footer`, `Sidebar`, `Breadcrumbs`.
- `PageShell`, `Section`, `Container`, `Grid`, `Stack`.
- Domain-specific components extracted from repeated page sections.

Prefer extending existing project components with `props`, `variant`,
`size`, `className`, or composition before creating a new component. Create a
new component only when existing components cannot express the source design
cleanly.

Keep component APIs small and concrete. Avoid speculative variants that are not
needed by migrated pages.

### 4. Migrate Pages

Implement pages using the new design system instead of duplicating raw styles:

1. Build shared layout and shell components first.
2. Build core UI primitives and verify states: hover, active, focus-visible,
   disabled, loading, selected, open/closed, error, and empty.
3. Migrate each page from `temp/` into the matching Next.js route.
4. Preserve semantic HTML: use native buttons, links, labels, inputs, lists,
   headings, tables, and landmarks before custom ARIA widgets.
5. Port only necessary JavaScript behavior into React client components.
6. Move assets into the project's existing asset convention, usually `public/`
   for static files or colocated imports if the project already does that.

Do not import remote CDN CSS or scripts unless the user explicitly requires it.
Scope copied CSS under project-owned selectors, CSS Modules, or component files
before simplifying it.

### 5. Add AGENTS.md

Create or update `AGENTS.md` at the project root. Include these sections:

- Project overview: what was migrated from `temp/` and the target frontend
  stack.
- Frontend directory structure: pages/routes, components, design system,
  styles, assets, and tests.
- Design system architecture: token locations, primitive components, layout
  components, domain components, and styling approach.
- Component reuse rules:
  - Always check existing components before building a new one.
  - Prefer extending existing components through `props`, `variant`, `size`,
    `className`, or composition.
  - Add a new component only when existing components cannot meet the need.
  - Keep page files focused on composition, data loading, and route concerns.
- Development notes: responsive requirements, accessibility states, asset
  conventions, visual verification steps, and how to update the design system.

Keep `AGENTS.md` practical and project-specific. Do not include generic React
tutorial content.

### 6. Add a Development-Only Design System Preview

Create a route that is only available in development, for example
`app/dev/design-system/page.tsx` or `app/__design-system/page.tsx`.

Requirements:

- Pure frontend rendering is acceptable and preferred for interactive previews.
- Hide or block the route outside development with `notFound()` or an equivalent
  guard.
- Show the core tokens and components: colors, typography, spacing examples,
  buttons, cards, form controls, navigation, layout grids, and common states.
- Use the same components that production pages use. The preview must not define
  separate demo-only controls that drift from real UI.
- Keep preview copy concise. The page is for visual inspection, not marketing.

### 7. Verify Fidelity and Maintainability

Run static checks and inspect the result visually:

- Run the project's existing lint, typecheck, test, and build commands when
  available.
- Start the dev server and compare migrated pages against the source HTML at
  desktop and mobile breakpoints.
- Check spacing, text wrapping, image sizing, hover/focus states, sticky/fixed
  elements, and responsive navigation.
- Confirm page files reuse components and do not contain repeated style blocks.
- Confirm `AGENTS.md` accurately reflects the final architecture.

If exact visual parity conflicts with maintainability, preserve visible behavior
first, then isolate any complex copied CSS behind a scoped component or module
with a short comment explaining why.

## Related Skills

- `nextjs-supabase-template` for initializing or maintaining the Supabase
  Auth-enabled Next.js shell.
- `tanstack-query` for API-backed client state after the UI is migrated.
- `frontend-api-contracts` for backend API contracts, generated clients, and
  response validation.
- `frontend-quality-gates` for visual, responsive, accessibility, and build
  verification after migration.

## Completion Checklist

- [ ] `temp/` source structure and repeated patterns were inspected.
- [ ] Design tokens or equivalent style variables were created.
- [ ] Shared UI and layout components were extracted.
- [ ] Pages were rebuilt from components, not pasted as one-off markup.
- [ ] `AGENTS.md` documents architecture and reuse rules.
- [ ] Development-only design system preview page exists.
- [ ] Checks were run or skipped with a concrete reason.
- [ ] Visual parity was reviewed at relevant breakpoints.
