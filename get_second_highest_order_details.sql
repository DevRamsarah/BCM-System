DECLARE
    result_cursor SYS_REFCURSOR;
    order_ref NUMBER;
    order_date VARCHAR2(50);
    supplier_name VARCHAR2(200);
    order_total_amount VARCHAR2(20);
    order_status VARCHAR2(50);
    invoice_references VARCHAR2(1000);
BEGIN
    -- Call the function
    result_cursor := get_second_highest_order_details;

    -- Fetch and display the results
    LOOP
        FETCH result_cursor INTO
            order_ref,
            order_date,
            supplier_name,
            order_total_amount,
            order_status,
            invoice_references;
        EXIT WHEN result_cursor%NOTFOUND;

        -- Display the results (or process them as needed)
        DBMS_OUTPUT.PUT_LINE(
            'Order Reference: ' || order_ref || ', ' ||
            'Order Date: ' || order_date || ', ' ||
            'Supplier Name: ' || supplier_name || ', ' ||
            'Order Total Amount: ' || order_total_amount || ', ' ||
            'Order Status: ' || order_status || ', ' ||
            'Invoice References: ' || invoice_references
        );
    END LOOP;

    -- Close the cursor
    CLOSE result_cursor;
END;
/