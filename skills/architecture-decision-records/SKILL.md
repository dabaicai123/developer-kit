---
name: architecture-decision-records
description: "Architecture Decision Records (ADR) for creating, maintaining, and managing architectural decisions. Use when making significant architectural decisions, documenting technology choices, or recording design trade-offs."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Architecture Decision Records

Patterns for creating, maintaining, and managing Architecture Decision Records (ADRs).

## When to use this skill

- Making significant architectural decisions
- Documenting technology choices
- Recording design trade-offs
- Onboarding new team members to historical decisions
- Establishing decision-making processes

## Do not use this skill when

- You only need to document small implementation details
- The change is a minor patch or routine maintenance
- There is no architectural decision to capture

## Instructions

1. Capture the decision context, constraints, and drivers.
2. Document considered options with tradeoffs.
3. Record the decision, rationale, and consequences.
4. Link related ADRs and update status over time.

## Core Concepts

### What is an ADR?

An Architecture Decision Record captures:
- **Context**: Why we needed to make a decision
- **Decision**: What we decided
- **Consequences**: What happens as a result

### When to Write an ADR

| Write ADR | Skip ADR |
|-----------|----------|
| New framework adoption | Minor version upgrades |
| Database technology choice | Bug fixes |
| API design patterns | Implementation details |
| Security architecture | Routine maintenance |
| Integration patterns | Configuration changes |

### ADR Lifecycle

```
Proposed → Accepted → Deprecated → Superseded
              ↓
           Rejected
```

### Choosing a Template

| Template | Use When |
|----------|----------|
| Standard (MADR) | Significant technology choices, architecture pattern decisions |
| Lightweight | Smaller decisions, technology adoption within a team |
| Y-Statement | Quick decision documentation, decision log entries |
| Deprecation | Superseding previous decisions, technology migration |
| RFC Style | Complex decisions requiring broad input, experimental proposals |

See [adr-templates.md](references/adr-templates.md) for full template content.

## ADR Management

### Directory Structure

```
docs/
├── adr/
│   ├── README.md           # Index and guidelines
│   ├── template.md         # Team's ADR template
│   ├── 0001-use-postgresql.md
│   ├── 0002-caching-strategy.md
│   ├── 0003-mongodb-user-profiles.md  # [DEPRECATED]
│   └── 0020-deprecate-mongodb.md      # Supersedes 0003
```

### Automation (adr-tools)

```bash
adr init docs/adr
adr new "Use PostgreSQL as Primary Database"
adr new -s 3 "Deprecate MongoDB in Favor of PostgreSQL"   # supersede ADR 3
adr generate toc > docs/adr/README.md
```

## Review Process

| Stage | Checklist |
|-------|-----------|
| Before Submission | Context explains problem, all viable options considered, pros/cons balanced, consequences documented, related ADRs linked |
| During Review | At least 2 senior engineers reviewed, affected teams consulted, security and cost implications considered, reversibility assessed |
| After Acceptance | ADR index updated, team notified, implementation tickets created, related documentation updated |

## Best Practices

- **Write ADRs early** — before implementation starts
- **Keep them short** — 1-2 pages maximum
- **Be honest about trade-offs** — include real cons
- **Link related decisions** — build decision graph
- **Update status** — deprecate when superseded
- **Don't change accepted ADRs** — write new ones to supersede
- **Don't skip context** — future readers need background
- **Don't hide failures** — rejected decisions are valuable

## References

- [adr-templates.md](references/adr-templates.md) — 5 ADR templates (Standard, Lightweight, Y-Statement, Deprecation, RFC)
- [Documenting Architecture Decisions (Michael Nygard)](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [MADR Template](https://adr.github.io/madr/)
- [ADR GitHub Organization](https://adr.github.io/)
- [adr-tools](https://github.com/npryce/adr-tools)

## Related Skills

- `ddd-cola` — COLA architecture decisions and layer structure conventions