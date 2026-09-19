# CommerceLedger Entity Relationship Diagram

```mermaid
erDiagram
    CUSTOMERS ||--o{ ORDERS : places
    ORDERS ||--|{ ORDER_ITEMS : contains
    PRODUCTS ||--o{ ORDER_ITEMS : referenced_by
    ORDERS ||--o{ PAYMENTS : receives
    PRODUCTS ||--o{ INVENTORY_MOVEMENTS : tracks
    ORDERS ||--o{ INVENTORY_MOVEMENTS : causes

    CUSTOMERS {
        uuid id PK
        text email UK
        text full_name
        timestamptz created_at
        timestamptz updated_at
    }

    PRODUCTS {
        uuid id PK
        text sku UK
        text name
        text category
        numeric unit_price
        boolean active
    }

    ORDERS {
        uuid id PK
        uuid customer_id FK
        order_status status
        timestamptz ordered_at
    }

    ORDER_ITEMS {
        bigint id PK
        uuid order_id FK
        uuid product_id FK
        integer quantity
        numeric unit_price
        numeric discount_amount
        numeric line_total
    }

    PAYMENTS {
        uuid id PK
        uuid order_id FK
        numeric amount
        payment_status status
        text provider_reference
        timestamptz paid_at
    }

    INVENTORY_MOVEMENTS {
        bigint id PK
        uuid product_id FK
        integer quantity_delta
        inventory_reason reason
        uuid order_id FK
        timestamptz occurred_at
    }
```

## Design approach

CommerceLedger separates transactional entities from derived reporting objects.

The inventory model uses an **append-only ledger** rather than a mutable stock column. Current stock is derived from `SUM(quantity_delta)`, which makes every change auditable and enables running-balance queries.

Order prices are snapshotted in `order_items.unit_price`. This means historical order totals remain stable even when a product's current price changes.

The API-independent business layer lives inside PostgreSQL through stored functions:

- `create_order()` validates stock and reserves inventory transactionally.
- `record_payment()` records successful payments and promotes fully paid orders.
- `cancel_order()` creates compensating inventory movements rather than rewriting history.
- triggers enforce legal order-state transitions and inventory immutability.

Reporting is exposed through normal views and a materialized daily-sales view so the project demonstrates both transactional and analytical PostgreSQL patterns.
