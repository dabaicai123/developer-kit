---
name: ddd-event-driven
description: "Domain-driven event architecture for Spring Boot: domain events, aggregate event collection, event sourcing, CQRS projections, outbox, snapshotting, and COLA integration. Use when designing domain events inside DDD/COLA or event-sourced models."
version: "1.2.0"
type: skill
parameters:
  - name: event_complexity
    description: "simple_events, aggregate_events, or event_sourcing"
    type: enum
    values: ["simple_events", "aggregate_events", "event_sourcing"]
    required: false
  - name: use_outbox
    description: "Whether to use the outbox pattern for reliable delivery"
    type: boolean
    required: false
    default: true
---

# DDD Event-Driven Architecture

## Load Policy

Use this quick decision guide first. Load `references/full-guide.md` only when generating aggregate event base classes, event-sourcing examples, projection handlers, outbox schemas, or detailed COLA event integration.

## When To Use

Use for domain events inside a DDD/COLA model, event-sourced aggregates, CQRS read-model projections, or outbox-backed domain event publication.

Do not use this for simple inter-service messaging without domain semantics. For transport-specific messaging, load `spring-kafka`, `spring-boot-amqp`, or Spring Cloud Alibaba/RocketMQ guidance.

## Event Model Decision

| Model | Use when |
| --- | --- |
| `simple_events` | A write use case only needs to notify other modules/services after state changes. |
| `aggregate_events` | Aggregates collect one or more events during business operations. |
| `event_sourcing` | Aggregate state must be rebuilt from an event log, audit history is the source of truth, or temporal queries are required. |

Default to the simplest model that satisfies the business requirement.

## Event Design Rules

- Events are facts that already happened; use past-tense names such as `OrderPlacedEvent`.
- Use immutable records/classes and include event ID, occurred time, and correlation ID.
- Payloads contain essential data only. Do not include passwords, tokens, large blobs, or full mutable entities.
- Event schema changes must be additive. Breaking changes require a new event type or topic.
- Consumers must be idempotent and deduplicate by event ID when messages can be retried.

## Publishing Rules

- Domain logic registers or returns events; infrastructure transport is not called from domain objects.
- Publish only after the aggregate state is persisted.
- For in-process events, use `@TransactionalEventListener(phase = AFTER_COMMIT)`.
- For broker delivery, persist to an outbox table in the same transaction and relay asynchronously.
- Do not publish broker messages directly inside a DB transaction.

## COLA Integration

- Event DTOs shared with other services live in `client/dto/event`.
- Domain-only event contracts may live in `domain`.
- CmdExe is the normal write-path publisher/orchestrator.
- Simple COLA events do not require an `AggregateRoot` base class.
- Aggregate events or event sourcing may introduce `AggregateRoot` in domain while keeping COLA module boundaries from `ddd-cola`.

## Related Skills

- `ddd-cola`: module layout, CmdExe/QryExe, Gateway pattern.
- `spring-boot-transaction-management`: after-commit and outbox transaction rules.
- `spring-boot-event-driven-patterns`: Spring event implementation details.
- `spring-kafka` and `spring-boot-amqp`: message broker specifics.

