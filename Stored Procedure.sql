CREATE OR REPLACE PROCEDURE migrate_XXBCM_ORDER_MGT IS
BEGIN
    -- Step 1: Insert into Suppliers Table
    INSERT INTO Suppliers (Supplier_Name, Contact_Name, Address, Contact_Number, Email)
    SELECT DISTINCT
        SUPPLIER_NAME,
        SUPP_CONTACT_NAME,
        SUPP_ADDRESS,
        SUPP_CONTACT_NUMBER,
        SUPP_EMAIL
    FROM XXBCM_ORDER_MGT
    WHERE SUPPLIER_NAME IS NOT NULL;

    DBMS_OUTPUT.PUT_LINE('Inserted ' || SQL%ROWCOUNT || ' rows into Suppliers.');

    -- Step 2: Insert into Orders Table
    INSERT INTO Orders (Order_Ref, Order_Date, Supplier_ID, Order_Total_Amount, Order_Description, Order_Status)
    SELECT
        ORDER_REF,
        TO_DATE(ORDER_DATE, 'DD-MM-YYYY'),  -- Updated date format
        (SELECT Supplier_ID FROM Suppliers WHERE Supplier_Name = XXBCM_ORDER_MGT.SUPPLIER_NAME AND ROWNUM = 1),
        TO_NUMBER(REPLACE(ORDER_TOTAL_AMOUNT, ',', '')),
        ORDER_DESCRIPTION,
        ORDER_STATUS
    FROM XXBCM_ORDER_MGT
    WHERE ORDER_REF IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM Orders WHERE Orders.Order_Ref = XXBCM_ORDER_MGT.ORDER_REF
      );

    DBMS_OUTPUT.PUT_LINE('Inserted ' || SQL%ROWCOUNT || ' rows into Orders.');

    -- Step 3: Insert into Order_Lines Table
    INSERT INTO Order_Lines (Order_ID, Line_Description, Line_Amount)
    SELECT
        (SELECT Order_ID FROM Orders WHERE Order_Ref = XXBCM_ORDER_MGT.ORDER_REF AND ROWNUM = 1),
        ORDER_DESCRIPTION,
        TO_NUMBER(REPLACE(REGEXP_REPLACE(ORDER_LINE_AMOUNT, '[^0-9.,]', ''), ',', ''))
    FROM XXBCM_ORDER_MGT
    WHERE ORDER_LINE_AMOUNT IS NOT NULL;

    DBMS_OUTPUT.PUT_LINE('Inserted ' || SQL%ROWCOUNT || ' rows into Order_Lines.');

    -- Step 4: Insert into Invoices Table
    INSERT INTO Invoices (Invoice_Ref, Invoice_Date, Order_ID, Invoice_Status, Hold_Reason)
    SELECT
        INVOICE_REFERENCE,
        TO_DATE(INVOICE_DATE, 'DD-MM-YYYY'),  -- Updated date format
        (SELECT Order_ID FROM Orders WHERE Order_Ref = XXBCM_ORDER_MGT.ORDER_REF AND ROWNUM = 1),
        INVOICE_STATUS,
        INVOICE_HOLD_REASON
    FROM XXBCM_ORDER_MGT
    WHERE INVOICE_REFERENCE IS NOT NULL;

    DBMS_OUTPUT.PUT_LINE('Inserted ' || SQL%ROWCOUNT || ' rows into Invoices.');

    -- Step 5: Insert into Invoice_Lines Table
    INSERT INTO Invoice_Lines (Invoice_ID, Line_Description, Line_Amount)
    SELECT
        (SELECT Invoice_ID FROM Invoices WHERE Invoice_Ref = XXBCM_ORDER_MGT.INVOICE_REFERENCE AND ROWNUM = 1),
        INVOICE_DESCRIPTION,
        TO_NUMBER(REPLACE(REGEXP_REPLACE(INVOICE_AMOUNT, '[^0-9.,]', ''), ',', ''))
    FROM XXBCM_ORDER_MGT
    WHERE INVOICE_AMOUNT IS NOT NULL;

    DBMS_OUTPUT.PUT_LINE('Inserted ' || SQL%ROWCOUNT || ' rows into Invoice_Lines.');

    -- Step 6: Insert into Payments Table
    INSERT INTO Payments (Invoice_ID, Payment_Date, Payment_Amount, Payment_Description)
    SELECT
        (SELECT Invoice_ID FROM Invoices WHERE Invoice_Ref = XXBCM_ORDER_MGT.INVOICE_REFERENCE AND ROWNUM = 1),
        TO_DATE(INVOICE_DATE, 'DD-MM-YYYY'),  -- Updated date format
        TO_NUMBER(REPLACE(REGEXP_REPLACE(INVOICE_AMOUNT, '[^0-9.,]', ''), ',', '')),
        INVOICE_DESCRIPTION
    FROM XXBCM_ORDER_MGT
    WHERE INVOICE_STATUS = 'Paid';

    DBMS_OUTPUT.PUT_LINE('Inserted ' || SQL%ROWCOUNT || ' rows into Payments.');

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        RAISE;
END migrate_XXBCM_ORDER_MGT;
/

CREATE OR REPLACE PROCEDURE get_order_invoice_summary(p_result OUT SYS_REFCURSOR)
IS
BEGIN
    OPEN p_result FOR
        SELECT
            -- Order Reference: Exclude prefix PO and return only numeric value
            TO_NUMBER(REGEXP_REPLACE(o.Order_Ref, '[^0-9]', '')) AS Order_Reference,

            -- Order Period: Format as MON-YYYY
            TO_CHAR(o.Order_Date, 'MON-YYYY') AS Order_Period,

            -- Supplier Name: First character in each word to uppercase and the rest to lowercase
            INITCAP(s.Supplier_Name) AS Supplier_Name,

            -- Order Total Amount: Format as "99,999,990.00" (handle NULL values)
            TO_CHAR(NVL(o.Order_Total_Amount, 0), '99,999,990.00') AS Order_Total_Amount,

            -- Order Status: As per record
            o.Order_Status,

            -- Invoice Reference: As per record (handle NULL values)
            NVL(i.Invoice_Ref, 'N/A') AS Invoice_Reference,

            -- Invoice Total Amount: Sum of Line_Amount from Invoice_Lines, formatted as "99,999,990.00"
            TO_CHAR(NVL(SUM(il.Line_Amount), 0), '99,999,990.00') AS Invoice_Total_Amount,

            -- Action: Determine based on invoice statuses
            CASE
                WHEN NOT EXISTS (
                    SELECT 1
                    FROM Invoices inv
                    WHERE inv.Order_ID = o.Order_ID
                      AND inv.Invoice_Status <> 'Paid'
                ) THEN 'OK'
                WHEN EXISTS (
                    SELECT 1
                    FROM Invoices inv
                    WHERE inv.Order_ID = o.Order_ID
                      AND inv.Invoice_Status = 'Pending'
                ) THEN 'To follow up'
                WHEN EXISTS (
                    SELECT 1
                    FROM Invoices inv
                    WHERE inv.Order_ID = o.Order_ID
                      AND inv.Invoice_Status IS NULL
                ) THEN 'To verify'
                ELSE 'To verify'
            END AS Action
        FROM
            Orders o
            JOIN Suppliers s ON o.Supplier_ID = s.Supplier_ID
            LEFT JOIN Invoices i ON o.Order_ID = i.Order_ID
            LEFT JOIN Invoice_Lines il ON i.Invoice_ID = il.Invoice_ID
        GROUP BY
            o.Order_Ref,
            o.Order_Date,
            s.Supplier_Name,
            o.Order_Total_Amount,
            o.Order_Status,
            i.Invoice_Ref,
            o.Order_ID
        ORDER BY
            o.Order_Date DESC;
END get_order_invoice_summary;
/

CREATE OR REPLACE FUNCTION get_second_highest_order_details
RETURN SYS_REFCURSOR
IS
    result_cursor SYS_REFCURSOR;
BEGIN
    OPEN result_cursor FOR
        WITH ranked_orders AS (
            SELECT
                o.Order_ID,  -- Include Order_ID
                o.Order_Ref,
                o.Order_Date,
                s.Supplier_Name,
                o.Order_Total_Amount,
                o.Order_Status,
                ROW_NUMBER() OVER (ORDER BY o.Order_Total_Amount DESC) AS rn
            FROM
                Orders o
                JOIN Suppliers s ON o.Supplier_ID = s.Supplier_ID
        ),
        second_highest_order AS (
            SELECT
                Order_ID,  -- Include Order_ID
                Order_Ref,
                Order_Date,
                Supplier_Name,
                Order_Total_Amount,
                Order_Status
            FROM
                ranked_orders
            WHERE
                rn = 2
        )
        SELECT
            -- Order Reference: Exclude prefix PO and return only numeric value
            TO_NUMBER(REGEXP_REPLACE(o.Order_Ref, '[^0-9]', '')) AS Order_Reference,

            -- Order Date: Format as "Month DD, YYYY"
            TO_CHAR(o.Order_Date, 'Month DD, YYYY') AS Order_Date,

            -- Supplier Name: In upper case
            UPPER(o.Supplier_Name) AS Supplier_Name,

            -- Order Total Amount: Format as "99,999,990.00" (handle NULL values)
            TO_CHAR(NVL(o.Order_Total_Amount, 0), '99,999,990.00') AS Order_Total_Amount,

            -- Order Status: As per record
            o.Order_Status,

            -- Invoice References: Pipe-delimited list of invoice references
            (SELECT LISTAGG(i.Invoice_Ref, '|') WITHIN GROUP (ORDER BY i.Invoice_Ref)
             FROM Invoices i
             WHERE i.Order_ID = o.Order_ID) AS Invoice_References
        FROM
            second_highest_order o;

    RETURN result_cursor;
END get_second_highest_order_details;
/

CREATE OR REPLACE PROCEDURE Get_Supplier_Order_Summary IS
BEGIN
    FOR rec IN (
        SELECT 
            s.Supplier_Name,
            s.Contact_Name,
            REGEXP_REPLACE(REGEXP_SUBSTR(s.Contact_Number, '[^,]+', 1, 1), '(\d{4})(\d{4})', '\1-\2') AS Contact_No_1,
            REGEXP_REPLACE(REGEXP_SUBSTR(s.Contact_Number, '[^,]+', 1, 2), '(\d{4})(\d{4})', '\1-\2') AS Contact_No_2,
            COUNT(o.Order_ID) AS Total_Orders,
            TO_CHAR(SUM(o.Order_Total_Amount), '99,999,990.00') AS Order_Total_Amount
        FROM 
            Suppliers s
        JOIN 
            Orders o ON s.Supplier_ID = o.Supplier_ID
        WHERE 
            o.Order_Date BETWEEN TO_DATE('01-01-2022', 'DD-MM-YYYY') AND TO_DATE('31-08-2022', 'DD-MM-YYYY')
        GROUP BY 
            s.Supplier_Name, s.Contact_Name, s.Contact_Number
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            'Supplier Name: ' || rec.Supplier_Name || ', ' ||
            'Supplier Contact Name: ' || rec.Contact_Name || ', ' ||
            'Supplier Contact No. 1: ' || rec.Contact_No_1 || ', ' ||
            'Supplier Contact No. 2: ' || rec.Contact_No_2 || ', ' ||
            'Total Orders: ' || rec.Total_Orders || ', ' ||
            'Order Total Amount: ' || rec.Order_Total_Amount
        );
    END LOOP;
END Get_Supplier_Order_Summary;
/