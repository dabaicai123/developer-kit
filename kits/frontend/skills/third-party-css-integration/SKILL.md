---
name: third-party-css-integration
description: "Integrates copied third-party CSS into React, Next.js, and Tailwind v4 projects without adopting prebuilt UI controls. Use when importing external CSS snippets, porting copied HTML/CSS, wrapping custom-styled controls, or replacing component-library UI with project-owned markup."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Third-Party CSS Integration

Use this skill when a feature starts from copied HTML/CSS, a third-party demo, a CSS marketplace snippet, or a design export that already contains usable styles. The goal is to keep visual fidelity and editability while avoiding dependency on prebuilt UI controls.

## Core Policy

Project-owned markup comes first. Copied CSS is allowed as source material. Prebuilt UI components with baked DOM, state, or theme APIs are not allowed unless the user explicitly requests them and accepts the maintenance cost.

## NOT Rules

- Do NOT install MUI, Ant Design, Chakra, Mantine, Bootstrap JS components, DaisyUI, Flowbite, shadcn/ui components, or similar UI control libraries for buttons, cards, dialogs, forms, menus, tables, tabs, toasts, or layout.
- Do NOT replace copied CSS with a component library just because a similar control exists.
- Do NOT paste third-party CSS globally.
- Do NOT keep broad copied selectors like `button`, `input`, `a`, `div`, `*`, or `body` unless they are scoped under a project namespace.
- Do NOT import remote CDN CSS, external resets, external font CSS, or vendor JavaScript behavior without an explicit reason.
- Do NOT solve copied CSS conflicts with `!important`, broad selectors, or higher-specificity overrides.
- Do NOT preserve hardcoded design values that appear more than once; promote repeated colors, spacing, radii, shadows, and font sizes to Tailwind v4 `@theme` tokens.
- Do NOT convert every copied value into a global token. One-off visual values can stay local.
- Do NOT convert every copied rule to Tailwind utilities in one pass if that slows delivery or risks visual regression.
- Do NOT replace semantic HTML with div-only custom widgets.
- Do NOT use JavaScript to solve styling that CSS can handle with `:has`, `not-*`, `in-*`, `nth-*`, `@starting-style`, container queries, or media queries.
- Do NOT ship copied UI without keyboard, focus-visible, disabled, loading, empty, and error states for interactive controls.

## Integration Workflow

1. **Inventory the copied source**
   - Identify source files, selectors, assets, fonts, keyframes, media queries, container queries, and JavaScript behavior.
   - Separate visual CSS from behavior. Keep behavior in React only when the UI actually needs state.

2. **Scope before editing**
   - Wrap copied CSS under a stable namespace such as `.featureNameRoot` or a CSS Module.
   - Move broad selectors under that namespace before importing the CSS.
   - Keep one entry file per copied surface, for example `feature-name.css` or `FeatureName.module.css`.

3. **Extract repeated values**
   - Promote repeated colors, spacing, radius, shadow, and typography values to `@theme`.
   - Keep one-off values local when they appear only once and are part of the copied visual.
   - Prefer semantic token names: `--color-primary`, `--color-surface`, `--color-border`, not `--color-blue-500`.

4. **Own the markup**
   - Rebuild controls with semantic HTML: `button`, `a`, `input`, `select`, `textarea`, `dialog`, `table`, `fieldset`.
   - Use React components only as project-owned wrappers around semantic markup.
   - Add ARIA only when native semantics are not enough.
   - Headless behavior primitives are acceptable only when they do not bring a visual system and the project CSS owns the styling.

5. **Simplify last**
   - Remove unused copied selectors after the rendered UI is stable.
   - Convert repeated or high-churn CSS to Tailwind utilities when it improves maintainability.
   - Leave low-churn, complex visual effects in scoped CSS if rewriting them would add noise.

## Component Ownership Checklist

- [ ] No new prebuilt UI control library dependency was added.
- [ ] All copied CSS is scoped to a namespace, CSS Module, or feature entry file.
- [ ] Repeated design values are represented as Tailwind v4 `@theme` tokens.
- [ ] One-off visual values are not promoted into noisy global tokens.
- [ ] Native semantic elements are used before custom ARIA widgets.
- [ ] Focus-visible, hover, active, disabled, loading, empty, and error states are present where relevant.
- [ ] The component API is small: explicit props, no speculative variants, no catch-all configuration object.
- [ ] Styling remains directly editable in project files without changing third-party package internals.

## Review Heuristics

Flag a change when it introduces a UI library to avoid writing markup or CSS. Flag copied CSS when selectors are global, token extraction is skipped for repeated values, remote assets are pulled in casually, `!important` is used for conflict resolution, or interaction states are missing. Accept scoped copied CSS when it is simpler, visually faithful, and easier to modify than a Tailwind rewrite.

## Related Skills

- `design-to-code` - Converts copied HTML/CSS and design specs into project-owned components.
- `tailwind-v4` - Defines CSS-first theme tokens and modern CSS variants.
- `web-design-audit` - Checks visual quality, usability, accessibility, and responsive behavior.
- `frontend-code-review` - Reviews dependency, architecture, and maintainability risks.

## Keywords

third-party CSS, copied CSS, external CSS snippet, custom UI controls, no component library, no shadcn, scoped CSS, CSS Module, semantic markup, Tailwind tokens
