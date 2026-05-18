---
paths:
  - "src/lib/api/**"
  - "lib/api/**"
  - "app/api/**"
  - "**/*.ts"
  - "**/*.tsx"
---

# API Contract Conventions

Use `frontend-api-contracts` when integrating existing backend APIs.

## Rules

- Prefer OpenAPI/generated clients when a backend schema exists.
- Keep generated API code separated from project-owned wrappers.
- Normalize API errors before they reach UI components.
- Validate untrusted responses and inputs where risk justifies it.
- Keep base URLs, auth headers, and credential behavior centralized.
- Document required environment variables.
- Add mocks or tests for critical success and failure states.

## Avoid

- Inline reusable network calls inside components.
- Scattered hardcoded backend URLs.
- Assuming generated TypeScript types prove runtime payload validity.
