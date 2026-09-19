# CommerceLedger

**CommerceLedger** is a PostgreSQL-first commerce database portfolio project focused on relational modeling, transactional business rules, inventory accounting, analytical SQL, indexing, and automated database validation.

Rather than being a collection of isolated SQL exercises, this repository behaves like the data layer of a real commerce system.

## What this project demonstrates

- PostgreSQL schema design
- Normalization and relational modeling
- Primary and foreign keys
- CHECK and UNIQUE constraints
- Case-insensitive uniqueness through expression indexes
- PostgreSQL ENUM types
- Generated columns
- Partial and composite indexes
- PL/pgSQL stored functions
- Transaction-safe order creation
- Row locking with `FOR UPDATE`
- Inventory ledger accounting
- Immutable audit-style data
- Triggers
- State-transition enforcement
- Views
- Materialized views
- CTEs
- Window functions
- `LAG`
- `DENSE_RANK`
- running totals
- ordered-set aggregates and percentiles
- Docker
- SQL-based automated tests
- GitHub Actions CI

## Domain

CommerceLedger models:

- customers
- products
- orders
- order items
- payments
- inventory movements

The database handles order creation and inventory changes itself so multi-step operations remain atomic.

## Project structure

```text
db/
  init/
    001_extensions.sql
    002_schema.sql
    003_indexes.sql
    004_functions.sql
    005_triggers.sql
    006_views.sql
    007_seed.sql

queries/
  analytics.sql

tests/
  001_schema_tests.sql
  002_business_rules_tests.sql

docs/
  ERD.md

.github/workflows/
  postgres-ci.yml
```

## Run with Docker

Requirements:

- Docker
- Docker Compose

Start PostgreSQL:

```bash
docker compose up -d
```

Connect with `psql`:

```bash
psql -h localhost -U postgres -d commerceledger
```

Default local password:

```text
postgres
```

To rebuild the initialized database from scratch:

```bash
docker compose down -v
docker compose up -d
```

## Core database functions

### Create an order

```sql
SELECT create_order(
    '10000000-0000-0000-0000-000000000001',
    '[
        {"sku":"KEY-MECH-001","quantity":1},
        {"sku":"HUB-USBC-001","quantity":2}
    ]'::jsonb
);
```

The function:

1. verifies the customer;
2. validates each item;
3. locks the selected product row;
4. checks inventory;
5. snapshots the product price;
6. inserts order items;
7. writes negative inventory-ledger movements;
8. completes everything in one PostgreSQL transaction.

If any step fails, the statement is rolled back.

### Check current inventory

```sql
SELECT *
FROM v_inventory_status
ORDER BY quantity_on_hand;
```

### Record a payment

```sql
SELECT record_payment(
    '<order-id>',
    178.90,
    'provider-reference-001'
);
```

When successful payments cover the full order total, the order automatically moves from `pending` to `paid`.

### Cancel an order

```sql
SELECT cancel_order('<order-id>');
```

Cancellation does not rewrite the original inventory ledger. Instead, PostgreSQL inserts compensating `sale_reversal` movements to preserve an audit trail.

## Enforced order workflow

```text
pending ──> paid ──> shipped ──> completed
   │          │
   └──────────┴──────────────> cancelled
```

Invalid state changes are rejected by a trigger.

## Analytics examples

The repository contains production-style queries for:

- inventory valuation;
- customer lifetime value;
- best-selling products;
- revenue ranking;
- month-over-month revenue growth;
- median and P90 order value;
- low-stock detection;
- inventory running balances;
- materialized daily sales reporting.

Run them with:

```bash
psql -h localhost -U postgres -d commerceledger -f queries/analytics.sql
```

## Testing

The SQL test suite validates both structure and behavior.

It checks:

- expected database objects;
- non-negative seed inventory;
- case-insensitive email uniqueness;
- transactional inventory reduction;
- order totals;
- automatic paid status;
- inventory restoration on cancellation;
- order status-transition enforcement;
- append-only inventory behavior.

Run:

```bash
psql -h localhost -U postgres -d commerceledger -f tests/001_schema_tests.sql
psql -h localhost -U postgres -d commerceledger -f tests/002_business_rules_tests.sql
```

## CI

GitHub Actions starts a clean PostgreSQL service on every push and pull request, then:

1. applies every database migration/init script in order;
2. runs schema tests;
3. runs business-rule tests;
4. executes the analytics query suite.

This ensures the repository is executable and validated rather than only containing static SQL files.

## Portfolio value

CommerceLedger demonstrates SQL skills that are relevant to backend, data, and software-engineering roles:

- relational database design;
- PostgreSQL-specific features;
- transactional consistency;
- concurrency awareness;
- indexing;
- business-rule enforcement;
- analytical querying;
- database testing;
- reproducible environments;
- CI/CD fundamentals.

See [docs/ERD.md](docs/ERD.md) for the data model.
