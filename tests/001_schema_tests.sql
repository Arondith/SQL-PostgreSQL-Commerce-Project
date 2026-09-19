\set ON_ERROR_STOP on

DO $$
DECLARE
    v_table_count INTEGER;
    v_negative_inventory INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN (
          'customers',
          'products',
          'orders',
          'order_items',
          'payments',
          'inventory_movements'
      );

    IF v_table_count <> 6 THEN
        RAISE EXCEPTION 'Expected 6 core tables, found %', v_table_count;
    END IF;

    SELECT COUNT(*)
    INTO v_negative_inventory
    FROM v_inventory_status
    WHERE quantity_on_hand < 0;

    IF v_negative_inventory <> 0 THEN
        RAISE EXCEPTION 'Seed data contains negative inventory';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND indexname = 'customers_email_lower_uq'
    ) THEN
        RAISE EXCEPTION 'Case-insensitive customer email index is missing';
    END IF;
END;
$$;

DO $$
BEGIN
    BEGIN
        INSERT INTO customers (email, full_name)
        VALUES ('ALEx@example.com', 'Duplicate Alex');

        RAISE EXCEPTION 'Case-insensitive email uniqueness was not enforced';
    EXCEPTION
        WHEN unique_violation THEN
            NULL;
    END;
END;
$$;

SELECT 'schema tests passed' AS result;
