CREATE OR REPLACE VIEW v_inventory_status AS
SELECT
    p.id AS product_id,
    p.sku,
    p.name,
    p.category,
    p.unit_price,
    p.active,
    COALESCE(SUM(im.quantity_delta), 0)::BIGINT AS quantity_on_hand,
    MAX(im.occurred_at) AS last_inventory_activity_at
FROM products p
LEFT JOIN inventory_movements im
    ON im.product_id = p.id
GROUP BY
    p.id,
    p.sku,
    p.name,
    p.category,
    p.unit_price,
    p.active;

CREATE OR REPLACE VIEW v_order_totals AS
WITH item_totals AS (
    SELECT
        order_id,
        SUM(line_total)::NUMERIC(14,2) AS order_total
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT
        order_id,
        SUM(amount) FILTER (WHERE status = 'successful')::NUMERIC(14,2) AS paid_total
    FROM payments
    GROUP BY order_id
)
SELECT
    o.id AS order_id,
    o.customer_id,
    o.status,
    o.ordered_at,
    COALESCE(i.order_total, 0)::NUMERIC(14,2) AS order_total,
    COALESCE(p.paid_total, 0)::NUMERIC(14,2) AS paid_total,
    (
        COALESCE(i.order_total, 0) - COALESCE(p.paid_total, 0)
    )::NUMERIC(14,2) AS balance_due
FROM orders o
LEFT JOIN item_totals i
    ON i.order_id = o.id
LEFT JOIN payment_totals p
    ON p.order_id = o.id;

CREATE OR REPLACE VIEW v_customer_lifetime_value AS
SELECT
    c.id AS customer_id,
    c.full_name,
    c.email,
    COUNT(ot.order_id) FILTER (WHERE ot.status <> 'cancelled') AS order_count,
    COALESCE(
        SUM(ot.order_total) FILTER (WHERE ot.status <> 'cancelled'),
        0
    )::NUMERIC(14,2) AS gross_order_value,
    COALESCE(
        SUM(ot.paid_total) FILTER (WHERE ot.status <> 'cancelled'),
        0
    )::NUMERIC(14,2) AS collected_revenue,
    MAX(ot.ordered_at) FILTER (WHERE ot.status <> 'cancelled') AS last_order_at
FROM customers c
LEFT JOIN v_order_totals ot
    ON ot.customer_id = c.id
GROUP BY c.id, c.full_name, c.email;

CREATE MATERIALIZED VIEW mv_daily_sales AS
SELECT
    p.paid_at::DATE AS sales_date,
    COUNT(DISTINCT p.order_id) AS paid_orders,
    COUNT(*) AS payment_count,
    SUM(p.amount)::NUMERIC(16,2) AS collected_revenue,
    AVG(p.amount)::NUMERIC(14,2) AS average_payment
FROM payments p
WHERE p.status = 'successful'
  AND p.paid_at IS NOT NULL
GROUP BY p.paid_at::DATE
WITH DATA;

CREATE UNIQUE INDEX mv_daily_sales_date_uq
    ON mv_daily_sales (sales_date);

CREATE OR REPLACE FUNCTION refresh_analytics()
RETURNS VOID
LANGUAGE sql
AS $$
    REFRESH MATERIALIZED VIEW mv_daily_sales;
$$;
