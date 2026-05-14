---
paths:
  - "**/*.css"
  - "**/*.module.css"
  - "**/*.tsx"
  - "**/*.jsx"
  - "package.json"
---

# Rule: Third-Party CSS and Project-Owned UI

Use project-owned semantic markup plus scoped CSS. Copied third-party CSS is acceptable source material; prebuilt UI control libraries are not the default solution.

## Guidelines

1. **Own the UI markup** - implement buttons, cards, dialogs, forms, menus, tabs, tables, and layout with project components around native HTML elements. Do not introduce MUI, Ant Design, Chakra, Mantine, Bootstrap JS components, DaisyUI, Flowbite, shadcn/ui components, or similar UI control libraries unless explicitly requested.

2. **Scope copied CSS immediately** - place copied CSS in a feature CSS file or CSS Module and scope selectors under a feature root. Never leave broad copied selectors (`button`, `input`, `a`, `div`, `*`, `body`) unscoped.

3. **Extract repeated design values** - repeated colors, spacing, radii, shadows, and type values belong in Tailwind v4 `@theme` tokens. Keep one-off visual effects local when conversion would add complexity.

4. **Prefer CSS-native behavior** - use `:has`, `not-*`, `in-*`, `nth-*`, container queries, media queries, and `@starting-style` before adding JavaScript for purely visual state.

5. **Preserve usability states** - every interactive copied control needs focus-visible, hover, active, disabled, loading, empty, and error states where relevant. Do not ship visual-only controls that fail keyboard use.

6. **Keep APIs small** - expose explicit props for real variation. Do not add catch-all config objects, speculative variants, or class overrides that can replace required base styles.

## Anti-Patterns

- Installing a UI control library to avoid adapting copied CSS.
- Replacing a copied design with a library default component that is harder to customize.
- Global copied selectors that leak into the rest of the app.
- Remote CDN CSS, external reset CSS, external font CSS, or vendor JavaScript copied without review.
- `!important` or broad selectors used to overpower copied CSS conflicts.
- Converting all copied CSS to Tailwind utilities before confirming visual fidelity.
- Keeping repeated hardcoded values instead of promoting them to `@theme`.
- JavaScript-driven hover/open/position styles that CSS can handle.
- Wrapper components whose only purpose is to hide third-party package APIs.
