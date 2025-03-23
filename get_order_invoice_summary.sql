DECLARE
    result_cursor SYS_REFCURSOR;
    order_ref NUMBER;
    order_period VARCHAR2(20);
    supplier_name VARCHAR2(200);
    order_total_amount VARCHAR2(20);
    order_status VARCHAR2(50);
    invoice_ref VARCHAR2(50);
    invoice_total_amount VARCHAR2(20);
    action VARCHAR2(50);
BEGIN
    -- Enable DBMS_OUTPUT to display results
    DBMS_OUTPUT.ENABLE(buffer_size => NULL);

    -- Call the procedure
    get_order_invoice_summary(result_cursor);

    -- Fetch and display the results
    LOOP
        FETCH result_cursor INTO
            order_ref,
            order_period,
            supplier_name,
            order_total_amount,
            order_status,
            invoice_ref,
            invoice_total_amount,
            action;
        EXIT WHEN result_cursor%NOTFOUND;

        -- Handle NULL values for display
        invoice_ref := NVL(invoice_ref, 'N/A');
        invoice_total_amount := NVL(invoice_total_amount, '0.00');

        -- Display the results (or process them as needed)
        DBMS_OUTPUT.PUT_LINE(
            'Order Reference: ' || order_ref || ', ' ||
            'Order Period: ' || order_period || ', ' ||
            'Supplier Name: ' || supplier_name || ', ' ||
            'Order Total Amount: ' || NVL(order_total_amount, 'N/A') || ', ' ||
            'Order Status: ' || order_status || ', ' ||
            'Invoice Reference: ' || invoice_ref || ', ' ||
            'Invoice Total Amount: ' || invoice_total_amount || ', ' ||
            'Action: ' || action
        );
    END LOOP;

    -- Close the cursor
    CLOSE result_cursor;
END;
/