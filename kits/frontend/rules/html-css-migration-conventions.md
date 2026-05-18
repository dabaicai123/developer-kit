---
paths:
  - "temp/**"
  - "app/**/*.tsx"
  - "src/**/*.tsx"
  - "components/**/*.tsx"
  - "**/*.css"
---

# HTML/CSS Migration Conventions

Use `html-css-nextjs-migration` when moving native HTML/CSS into Next.js.

## Rules

- Inspect the full source directory before editing implementation files.
- Extract repeated colors, spacing, typography, radius, and shadows into design
  tokens or the project's existing token layer.
- Build shared components before rebuilding pages.
- Keep page files focused on composition, route data, and layout.
- Add or update `AGENTS.md` when architecture changes.
- Add or update the development-only design system preview page.
- Preserve source visual behavior at mobile, tablet, and desktop breakpoints.

## Avoid

- Pasting whole HTML pages as one-off JSX.
- Creating duplicate components when an existing component can be extended.
- Leaving broad copied CSS selectors unscoped.
