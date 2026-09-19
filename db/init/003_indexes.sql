CREATE UNIQUE INDEX customers_email_lower_uq
    ON customers (lower(email));

CREATE INDEX orders_customer_ordered_idx
    ON orders (customer_id, ordered_at DESC);

CREATE INDEX orders_status_ordered_idx
    ON orders (status, ordered_at DESC);

CREATE INDEX order_items_product_idx
    ON order_items (product_id);

CREATE INDEX payments_order_status_idx
    ON payments (order_id, status);

CREATE INDEX inventory_product_time_idx
    ON inventory_movements (product_id, occurred_at DESC);

CREATE INDEX inventory_order_idx
    ON inventory_movements (order_id)
    WHERE order_id IS NOT NULL;
