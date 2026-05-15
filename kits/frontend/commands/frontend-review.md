---
name: frontend-review
description: "Review frontend code for quality, performance, accessibility, architecture, and pattern compliance"
argument-hint: "<file path or feature description>"
allowed-tools: Read, Bash, Glob, Grep
model: inherit
---

# Frontend Code Review

Review frontend code for quality, performance, accessibility, architecture, and pattern compliance.

This command is review-only: report findings and concrete fixes, but do not modify files unless the user explicitly asks for a separate implementation pass.

## Review Checklist

Organized by severity: **Must-fix** (broken/inaccessible) -> **Should-fix** (non-compliant) -> **Nice-to-have** (improvement).

### Performance (Must-fix)

- [ ] Client-side fetch where server component can access data - move to server component
- [ ] Missing route-level `loading.tsx` or local `<Suspense>` for async UI - add the fallback at the right boundary
- [ ] Missing `error.tsx` or feature-level error boundary where failures should be contained - add deliberate containment
- [ ] Raw `<img>` tags - replace with `next/image`
- [ ] External font imports - replace with `next/font`
- [ ] Sync params access in Next.js 15+ - add `await` for params/searchParams

### Performance (Should-fix)

- [ ] Unnecessary `'use client'` - remove when no client features needed
- [ ] Large bundle imports - use dynamic imports for heavy modules
- [ ] Missing `generateMetadata` for SEO - add metadata exports

### Performance (Nice-to-have)

- [ ] Premature memoization - remove `React.memo`/`useMemo` unless profiling shows need

### Accessibility (Must-fix)

- [ ] Missing ARIA labels on icon-only buttons - add `aria-label`
- [ ] Missing keyboard accessibility on interactive elements - add keyboard handlers
- [ ] Missing alt text on images - add descriptive `alt` or `alt=""` for decorative
- [ ] Color contrast below WCAG AA (4.5:1) - adjust colors

### Accessibility (Should-fix)

- [ ] Missing focus management for modals/dialogs - add focus trap
- [ ] Missing form labels - associate labels with inputs
- [ ] Missing `aria-expanded` on collapsible elements - add state attributes

### Architecture (Should-fix)

- [ ] Boolean flag state (`isLoading`, `isError`) - use discriminated unions
- [ ] Prop drilling beyond 2 levels - use context or composition
- [ ] Configuration props over composition - use compound components
- [ ] Missing Zod validation at API/form boundaries - add schemas
- [ ] Duplicate TypeScript interfaces alongside Zod schemas - derive via `z.infer`

### TypeScript (Should-fix)

- [ ] `React.FC` usage - replace with plain function signatures and explicit props parameter
- [ ] Implicit `any` event types - add explicit handler types
- [ ] Generic `useRef<HTMLElement>` - use specific element types
- [ ] `as Type` assertions that mask source-type problems - narrow the source type, validate runtime data with Zod, or use `satisfies` / `as const satisfies` for compile-time shape checks

### Tailwind (Should-fix)

- [ ] Hardcoded color utilities (`bg-blue-500`) - use semantic tokens
- [ ] Color-specific tokens (`--color-blue-500`) - rename to semantic
- [ ] New v4 tokens added to `tailwind.config.js` - move tokens to CSS `@theme`; keep JS config only for legacy `@config` compatibility
- [ ] Desktop-first responsive (`max-sm:`) - switch to mobile-first
- [ ] `tv()` overuse on single-variant components - use plain class strings

### Tailwind (Nice-to-have)

- [ ] Missing `@starting-style` for entry transitions - add CSS transition-from-zero
- [ ] Non-OKLCH colors in `@theme` - convert for perceptual uniformity

### Third-Party CSS / UI Ownership (Should-fix)

- [ ] New prebuilt UI control library dependency - remove unless explicitly requested
- [ ] Prebuilt UI control library used for standard UI - replace with project-owned semantic markup unless explicitly requested
- [ ] Copied CSS left as broad global selectors - scope under a feature root or CSS Module
- [ ] Remote CDN CSS, external reset CSS, external font CSS, or vendor JavaScript imported casually - remove or justify explicitly
- [ ] `!important`, broad selectors, or higher-specificity overrides used for copied CSS conflicts - fix the scope or cascade
- [ ] Repeated copied values not promoted to `@theme` - extract semantic tokens
- [ ] JavaScript used for purely visual styling state - prefer CSS-native selectors, Tailwind v4 variants, or `@starting-style`
- [ ] Copied interactive controls missing focus-visible, disabled, loading, empty, or error states - add usability states

## Review Output Format

For each issue, report:
- **Category & severity**: Performance-Must-fix / Accessibility-Should-fix / etc.
- **File & location**: Where the issue occurs
- **Issue**: What is wrong
- **Fix**: Concrete code change to resolve it

## Skills Integration

| Review Area | Skill |
|-------------|-------|
| Code review | `frontend-code-review` |
| React patterns | `react-best-practices` |
| Design audit | `web-design-audit` |
| TypeScript | `typescript-react` |
| Copied CSS integration | `third-party-css-integration` |
