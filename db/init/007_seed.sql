INSERT INTO customers (id, email, full_name)
VALUES
    ('10000000-0000-0000-0000-000000000001', 'alex@example.com', 'Alex Rivera'),
    ('10000000-0000-0000-0000-000000000002', 'jamie@example.com', 'Jamie Chen');

INSERT INTO products (
    id,
    sku,
    name,
    category,
    unit_price
)
VALUES
    (
        '20000000-0000-0000-0000-000000000001',
        'KEY-MECH-001',
        'Mechanical Keyboard',
        'Peripherals',
        79.90
    ),
    (
        '20000000-0000-0000-0000-000000000002',
        'HUB-USBC-001',
        'USB-C Hub',
        'Accessories',
        49.50
    ),
    (
        '20000000-0000-0000-0000-000000000003',
        'CAM-1080-001',
        '1080p Webcam',
        'Peripherals',
        64.00
    ),
    (
        '20000000-0000-0000-0000-000000000004',
        'STAND-LAP-001',
        'Laptop Stand',
        'Accessories',
        35.00
    );

INSERT INTO inventory_movements (
    product_id,
    quantity_delta,
    reason,
    note
)
VALUES
    (
        '20000000-0000-0000-0000-000000000001',
        25,
        'opening_stock',
        'Seed inventory'
    ),
    (
        '20000000-0000-0000-0000-000000000002',
        40,
        'opening_stock',
        'Seed inventory'
    ),
    (
        '20000000-0000-0000-0000-000000000003',
        18,
        'opening_stock',
        'Seed inventory'
    ),
    (
        '20000000-0000-0000-0000-000000000004',
        30,
        'opening_stock',
        'Seed inventory'
    );

DO $$
DECLARE
    v_order_id UUID;
    v_total NUMERIC(14,2);
BEGIN
    v_order_id := create_order(
        '10000000-0000-0000-0000-000000000001',
        '[
            {"sku": "KEY-MECH-001", "quantity": 1},
            {"sku": "HUB-USBC-001", "quantity": 2}
        ]'::JSONB
    );

    SELECT order_total
    INTO v_total
    FROM v_order_totals
    WHERE order_id = v_order_id;

    PERFORM record_payment(v_order_id, v_total, 'seed-payment-001');
END;
$$;

SELECT refresh_analytics();
