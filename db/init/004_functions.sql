CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION get_stock(p_product_id UUID)
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT COALESCE(SUM(quantity_delta), 0)::BIGINT
    FROM inventory_movements
    WHERE product_id = p_product_id;
$$;

CREATE OR REPLACE FUNCTION create_order(
    p_customer_id UUID,
    p_items JSONB
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id UUID;
    v_item JSONB;
    v_product_id UUID;
    v_price NUMERIC(12,2);
    v_quantity INTEGER;
    v_available BIGINT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM customers WHERE id = p_customer_id) THEN
        RAISE EXCEPTION 'Customer % does not exist', p_customer_id;
    END IF;

    IF jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'Order items must be a non-empty JSON array';
    END IF;

    INSERT INTO orders (customer_id)
    VALUES (p_customer_id)
    RETURNING id INTO v_order_id;

    FOR v_item IN
        SELECT value FROM jsonb_array_elements(p_items)
    LOOP
        IF NOT (v_item ? 'sku') OR NOT (v_item ? 'quantity') THEN
            RAISE EXCEPTION 'Each item requires sku and quantity';
        END IF;

        BEGIN
            v_quantity := (v_item ->> 'quantity')::INTEGER;
        EXCEPTION WHEN invalid_text_representation THEN
            RAISE EXCEPTION 'Quantity must be an integer';
        END;

        IF v_quantity <= 0 THEN
            RAISE EXCEPTION 'Quantity must be greater than zero';
        END IF;

        SELECT id, unit_price
        INTO v_product_id, v_price
        FROM products
        WHERE sku = v_item ->> 'sku'
          AND active = TRUE
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Active product with SKU % does not exist', v_item ->> 'sku';
        END IF;

        v_available := get_stock(v_product_id);

        IF v_available < v_quantity THEN
            RAISE EXCEPTION
                'Insufficient stock for SKU %. Available: %, requested: %',
                v_item ->> 'sku', v_available, v_quantity;
        END IF;

        INSERT INTO order_items (
            order_id,
            product_id,
            quantity,
            unit_price
        )
        VALUES (
            v_order_id,
            v_product_id,
            v_quantity,
            v_price
        );

        INSERT INTO inventory_movements (
            product_id,
            quantity_delta,
            reason,
            order_id,
            note
        )
        VALUES (
            v_product_id,
            -v_quantity,
            'sale',
            v_order_id,
            'Reserved by create_order()'
        );
    END LOOP;

    RETURN v_order_id;
END;
$$;

CREATE OR REPLACE FUNCTION record_payment(
    p_order_id UUID,
    p_amount NUMERIC(14,2),
    p_provider_reference TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_payment_id UUID;
    v_order_total NUMERIC(14,2);
    v_paid_total NUMERIC(14,2);
    v_status order_status;
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero';
    END IF;

    SELECT status
    INTO v_status
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % does not exist', p_order_id;
    END IF;

    IF v_status IN ('cancelled', 'completed') THEN
        RAISE EXCEPTION 'Cannot record payment for an order in % status', v_status;
    END IF;

    SELECT COALESCE(SUM(line_total), 0)
    INTO v_order_total
    FROM order_items
    WHERE order_id = p_order_id;

    INSERT INTO payments (
        order_id,
        amount,
        status,
        provider_reference,
        paid_at
    )
    VALUES (
        p_order_id,
        p_amount,
        'successful',
        p_provider_reference,
        now()
    )
    RETURNING id INTO v_payment_id;

    SELECT COALESCE(SUM(amount), 0)
    INTO v_paid_total
    FROM payments
    WHERE order_id = p_order_id
      AND status = 'successful';

    IF v_paid_total >= v_order_total AND v_order_total > 0 THEN
        UPDATE orders
        SET status = 'paid'
        WHERE id = p_order_id
          AND status = 'pending';
    END IF;

    RETURN v_payment_id;
END;
$$;

CREATE OR REPLACE FUNCTION cancel_order(p_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_status order_status;
BEGIN
    SELECT status
    INTO v_status
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order % does not exist', p_order_id;
    END IF;

    IF v_status IN ('shipped', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'Order in % status cannot be cancelled', v_status;
    END IF;

    INSERT INTO inventory_movements (
        product_id,
        quantity_delta,
        reason,
        order_id,
        note
    )
    SELECT
        product_id,
        quantity,
        'sale_reversal',
        p_order_id,
        'Inventory restored by cancel_order()'
    FROM order_items
    WHERE order_id = p_order_id;

    UPDATE orders
    SET status = 'cancelled'
    WHERE id = p_order_id;
END;
$$;
