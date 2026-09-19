\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_customer_id UUID;
    v_product_id UUID;
    v_order_id UUID;
    v_pending_order UUID;
    v_stock BIGINT;
    v_total NUMERIC(14,2);
    v_status order_status;
BEGIN
    INSERT INTO customers (email, full_name)
    VALUES ('ci-test@example.com', 'CI Test Customer')
    RETURNING id INTO v_customer_id;

    INSERT INTO products (sku, name, category, unit_price)
    VALUES ('CI-SKU-001', 'CI Test Product', 'Testing', 20.00)
    RETURNING id INTO v_product_id;

    INSERT INTO inventory_movements (
        product_id,
        quantity_delta,
        reason,
        note
    )
    VALUES (
        v_product_id,
        10,
        'opening_stock',
        'CI test opening stock'
    );

    IF get_stock(v_product_id) <> 10 THEN
        RAISE EXCEPTION 'Expected opening stock of 10';
    END IF;

    v_order_id := create_order(
        v_customer_id,
        '[{"sku":"CI-SKU-001","quantity":3}]'::JSONB
    );

    v_stock := get_stock(v_product_id);

    IF v_stock <> 7 THEN
        RAISE EXCEPTION 'Expected stock 7 after order, got %', v_stock;
    END IF;

    SELECT order_total
    INTO v_total
    FROM v_order_totals
    WHERE order_id = v_order_id;

    IF v_total <> 60.00 THEN
        RAISE EXCEPTION 'Expected order total 60.00, got %', v_total;
    END IF;

    PERFORM record_payment(v_order_id, v_total, 'ci-payment');

    SELECT status
    INTO v_status
    FROM orders
    WHERE id = v_order_id;

    IF v_status <> 'paid' THEN
        RAISE EXCEPTION 'Expected paid status, got %', v_status;
    END IF;

    PERFORM cancel_order(v_order_id);

    IF get_stock(v_product_id) <> 10 THEN
        RAISE EXCEPTION 'Cancellation did not restore inventory';
    END IF;

    SELECT status
    INTO v_status
    FROM orders
    WHERE id = v_order_id;

    IF v_status <> 'cancelled' THEN
        RAISE EXCEPTION 'Expected cancelled status, got %', v_status;
    END IF;

    v_pending_order := create_order(
        v_customer_id,
        '[{"sku":"CI-SKU-001","quantity":1}]'::JSONB
    );

    BEGIN
        UPDATE orders
        SET status = 'completed'
        WHERE id = v_pending_order;

        RAISE EXCEPTION 'Invalid order status transition was accepted';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM = 'Invalid order status transition was accepted' THEN
                RAISE;
            END IF;
    END;

    BEGIN
        UPDATE inventory_movements
        SET note = 'illegal mutation'
        WHERE product_id = v_product_id
        LIMIT 1;

        RAISE EXCEPTION 'Inventory ledger mutation was accepted';
    EXCEPTION
        WHEN syntax_error THEN
            NULL;
    END;
END;
$$;

ROLLBACK;

-- PostgreSQL UPDATE has no LIMIT. Test immutability with a separate transaction block.
BEGIN;

DO $$
DECLARE
    v_movement_id BIGINT;
BEGIN
    SELECT id
    INTO v_movement_id
    FROM inventory_movements
    ORDER BY id
    LIMIT 1;

    BEGIN
        UPDATE inventory_movements
        SET note = 'illegal mutation'
        WHERE id = v_movement_id;

        RAISE EXCEPTION 'Inventory ledger mutation was accepted';
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLERRM = 'Inventory ledger mutation was accepted' THEN
                RAISE;
            END IF;
    END;
END;
$$;

ROLLBACK;

SELECT 'business rule tests passed' AS result;
