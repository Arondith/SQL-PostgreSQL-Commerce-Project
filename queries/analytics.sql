-- 1. Current inventory with estimated retail value.
SELECT
    sku,
    name,
    category,
    quantity_on_hand,
    unit_price,
    (quantity_on_hand * unit_price)::NUMERIC(16,2) AS inventory_value
FROM v_inventory_status
ORDER BY inventory_value DESC;


-- 2. Customer lifetime value.
SELECT
    full_name,
    email,
    order_count,
    gross_order_value,
    collected_revenue,
    last_order_at
FROM v_customer_lifetime_value
ORDER BY collected_revenue DESC, order_count DESC;


-- 3. Best-selling products by units and revenue.
SELECT
    p.sku,
    p.name,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.line_total)::NUMERIC(16,2) AS gross_revenue,
    DENSE_RANK() OVER (
        ORDER BY SUM(oi.line_total) DESC
    ) AS revenue_rank
FROM order_items oi
JOIN orders o
    ON o.id = oi.order_id
JOIN products p
    ON p.id = oi.product_id
WHERE o.status <> 'cancelled'
GROUP BY p.id, p.sku, p.name
ORDER BY gross_revenue DESC;


-- 4. Monthly revenue with month-over-month change.
WITH monthly AS (
    SELECT
        date_trunc('month', paid_at)::DATE AS month,
        SUM(amount)::NUMERIC(16,2) AS revenue
    FROM payments
    WHERE status = 'successful'
      AND paid_at IS NOT NULL
    GROUP BY date_trunc('month', paid_at)
),
with_previous AS (
    SELECT
        month,
        revenue,
        LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue
    FROM monthly
)
SELECT
    month,
    revenue,
    previous_month_revenue,
    CASE
        WHEN previous_month_revenue IS NULL OR previous_month_revenue = 0 THEN NULL
        ELSE ROUND(
            ((revenue - previous_month_revenue) / previous_month_revenue) * 100,
            2
        )
    END AS month_over_month_pct
FROM with_previous
ORDER BY month;


-- 5. Order value distribution using PostgreSQL ordered-set aggregates.
SELECT
    COUNT(*) AS orders,
    ROUND(AVG(order_total), 2) AS average_order_value,
    percentile_cont(0.50) WITHIN GROUP (ORDER BY order_total) AS median_order_value,
    percentile_cont(0.90) WITHIN GROUP (ORDER BY order_total) AS p90_order_value
FROM v_order_totals
WHERE status <> 'cancelled';


-- 6. Products approaching low stock.
SELECT
    sku,
    name,
    quantity_on_hand,
    CASE
        WHEN quantity_on_hand <= 5 THEN 'critical'
        WHEN quantity_on_hand <= 10 THEN 'low'
        ELSE 'healthy'
    END AS stock_health
FROM v_inventory_status
ORDER BY quantity_on_hand ASC, sku;


-- 7. Recent inventory ledger with a running balance per product.
SELECT
    p.sku,
    im.occurred_at,
    im.reason,
    im.quantity_delta,
    SUM(im.quantity_delta) OVER (
        PARTITION BY im.product_id
        ORDER BY im.occurred_at, im.id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_quantity
FROM inventory_movements im
JOIN products p
    ON p.id = im.product_id
ORDER BY p.sku, im.occurred_at, im.id;


-- 8. Daily materialized sales summary.
SELECT
    sales_date,
    paid_orders,
    payment_count,
    collected_revenue,
    average_payment
FROM mv_daily_sales
ORDER BY sales_date DESC;
