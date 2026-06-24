# System Architecture & Database Spec

## Overview

Describe the project architecture, runtime boundaries, storage model, and
security model. Requirements work must not proceed by guessing these decisions.

## Application Topology

- Frontend runtime:
- Backend runtime:
- API gateway or edge layer:
- Background workers:
- External services:
- Local development entrypoints:
- Production deployment shape:

## Module Boundaries

- UI modules:
- Domain modules:
- Application/service modules:
- Infrastructure modules:
- Shared libraries:
- Forbidden dependencies:

## Frontend Architecture

- Routing:
- Rendering mode:
- State management:
- Form handling:
- Data fetching:
- Error handling:
- Design system source:

## Backend Architecture

- API style:
- Request validation:
- Auth/session model:
- Domain service boundaries:
- Background jobs:
- File/object storage:
- Observability:

## API Surface

| Route or RPC | Owner | Input | Output | Auth | Side Effects |
| --- | --- | --- | --- | --- | --- |
| `<decision-required>` | `<owner>` | `<schema>` | `<schema>` | `<rule>` | `<effect>` |

## Database Model

| Entity | Purpose | Key Fields | Relationships | Constraints |
| --- | --- | --- | --- | --- |
| `<decision-required>` | `<purpose>` | `<fields>` | `<relations>` | `<constraints>` |

## Permissions & Security

- User roles:
- Permission checks:
- Data isolation:
- Secret handling:
- Audit logging:
- Abuse cases:

## Integration Boundaries

- Third-party APIs:
- Webhooks:
- Queues:
- Email/SMS/push:
- Payments:
- Analytics:

## Operational Constraints

- Performance constraints:
- Availability expectations:
- Migration rules:
- Backup/restore:
- Feature flag rules:
- Rollback constraints:

## Architecture Do's and Don'ts

- Do keep module ownership explicit.
- Do name persistence and side effects before implementation.
- Do update this spec when a feature changes architecture.
- Don't create new APIs, tables, queues, or permissions without recording them here.
- Don't let frontend components bypass declared service or data-flow boundaries.
