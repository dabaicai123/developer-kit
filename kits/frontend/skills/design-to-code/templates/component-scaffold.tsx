interface ComponentProps {
  /** Primary content displayed by the component */
  children: React.ReactNode
  /** Additional CSS classes — extends, never overrides, base styles */
  className?: string
  // Add component-specific props here
}

/**
 * ComponentName — [one-line description of purpose]
 *
 * Server Component by default. Add "use client" directive at the top
 * ONLY if the component needs useState, useEffect, or event handlers.
 *
 * @example
 * <ComponentName>Content here</ComponentName>
 */
export default function ComponentName({ children, className }: ComponentProps) {
  return (
    <div
      className={[
        // Base styles — always applied
        "bg-[--color-surface-elevated]",
        "border border-[--color-border]",
        "rounded-[--radius-lg]",
        "p-[--spacing-6]",
        // Responsive variants — mobile-first
        // "md:p-[--spacing-8]",
        // Conditional/interactive styles — only if needed
        // "hover:bg-[--color-surface-subtle]",
        // "focus-visible:ring-2 focus-visible:ring-[--color-primary]",
        // User className — merged last so it can extend base styles
        className,
      ].filter(Boolean).join(" ")}
      // ARIA attributes — add as needed
      // role="region"
      // aria-label="Descriptive label"
    >
      {children}
    </div>
  )
}

// --- CLIENT COMPONENT TEMPLATE ---
// Uncomment below and add "use client" at file top when interactivity is needed

/*
"use client"

import { useState } from "react"

interface InteractiveComponentProps {
  /** Initial state value */
  initialValue?: boolean
  /** Callback when state changes */
  onToggle?: (value: boolean) => void
  children: React.ReactNode
  className?: string
}

export default function InteractiveComponent({
  initialValue = false,
  onToggle,
  children,
  className,
}: InteractiveComponentProps) {
  const [isOpen, setIsOpen] = useState(initialValue)

  return (
    <div
      className={[
        "bg-[--color-surface-elevated]",
        "border border-[--color-border]",
        "rounded-[--radius-lg]",
        className,
      ].filter(Boolean).join(" ")}
    >
      <button
        onClick={() => {
          const next = !isOpen
          setIsOpen(next)
          onToggle?.(next)
        }}
        className={[
          "flex items-center justify-between",
          "w-full p-[--spacing-4]",
          "text-[--font-size-body]",
          "font-[--font-weight-medium]",
          "text-[--color-text]",
          "hover:bg-[--color-surface-subtle]",
          "focus-visible:ring-2 focus-visible:ring-[--color-primary]",
          "rounded-[--radius-md]",
        ].filter(Boolean).join(" ")}
        aria-expanded={isOpen}
        aria-controls="content-panel"
      >
        {children}
        <svg
          className={[
            "w-5 h-5 text-[--color-text-muted]",
            "transition-transform",
            isOpen ? "rotate-180" : "",
          ].filter(Boolean).join(" ")}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      <div
        id="content-panel"
        className={isOpen ? "block p-[--spacing-4]" : "hidden"}
        role="region"
        aria-label="Content section"
      >
        {/* Toggle content here */}
      </div>
    </div>
  )
}
*/

// --- VARIANT COMPONENT TEMPLATE ---
// Use when the same structure needs different visual styles

/*
interface VariantComponentProps {
  /** Visual style variant */
  variant?: "default" | "primary" | "secondary"
  /** Size variant */
  size?: "sm" | "md" | "lg"
  children: React.ReactNode
  className?: string
}

const variantStyles: Record<string, string> = {
  default: "bg-[--color-surface-elevated] text-[--color-text] border border-[--color-border]",
  primary: "bg-[--color-primary] text-[--color-surface-elevated] hover:bg-[--color-primary-hover]",
  secondary: "bg-[--color-surface-elevated] text-[--color-primary] border border-[--color-primary] hover:bg-[--color-primary-light]",
}

const sizeStyles: Record<string, string> = {
  sm: "px-[--spacing-2] py-[--spacing-1] text-[--font-size-caption]",
  md: "px-[--spacing-4] py-[--spacing-2] text-[--font-size-body]",
  lg: "px-[--spacing-8] py-[--spacing-3] text-[--font-size-body-large]",
}

export default function VariantComponent({
  variant = "default",
  size = "md",
  children,
  className,
}: VariantComponentProps) {
  return (
    <div
      className={[
        "rounded-[--radius-md]",
        "font-[--font-weight-medium]",
        variantStyles[variant],
        sizeStyles[size],
        className,
      ].filter(Boolean).join(" ")}
    >
      {children}
    </div>
  )
}
*/