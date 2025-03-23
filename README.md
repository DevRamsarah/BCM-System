# BCM-System
Tools Used

Database: Oracle Database (for SQL and PL/SQL scripts).

SQL Client: VS Code (Oracle SQL Developer Extension for VSCode)

Scripting Language: PL/SQL for stored procedures and functions.

Error Handling: PL/SQL exception handling (‘EXCEPTION’ block).

Performance Optimization: Use of indexes, proper joins, and efficient SQL queries.

Assumptions

Data Integrity
   - The ‘XXBCM_ORDER_MGT’ table is populated with valid data.
   - Dates are in the format ‘DD-MM-YYYY’.
   - Contact numbers are stored as strings and may contain multiple numbers separated by commas.
   - Amounts are stored as strings with commas (e.g., ‘10,000’).


Error Handling:
   - Invalid dates or amounts will be handled gracefully.
   - Missing or null values will not cause the script to fail.

Performance:
   - Indexes are created on frequently queried columns (e.g., ‘ORDER_REF’, ‘SUPPLIER_NAME’, ‘INVOICE_REFERENCE’).
   - Large datasets are handled efficiently by avoiding unnecessary loops or nested queries.
   - 
 
Solution & Output

Task 1: Create Tables ‘XXBCM_ORDER_MGT’ by executing the script ‘DB_Prequisite.sql’.

Task 2: Create the tables: Suppliers, Orders, Order_Lines, Invoices, Invoice_Lines, Payments by executing the script ‘Table Schema.sql’.

Before the following tasks, execute the script ‘Stored Procedure.sql’ first.

Task 3: Migrate data from ‘XXBCM_ORDER_MGT’ to the normalized tables by executing the script ‘migrate_XXBCM_ORDER_MGT.sql’.

Task 4: Generate list of distinct invoices and their total amount by executing the script ‘get_order_invoice_summary.sql’.

Output: get_order_invoice_summaryOutput.txt

Task 5: Return the SECOND (2nd) highest Order Total Amount by executing the script ‘get_second_highest_order_details.sql’.

Output: get_second_highest_order_detailsOutput.txt

Task 6: List all suppliers with their respective number of orders and total amount ordered from them between the period of 01 January 2022 and 31 August 2022 by executing the script ‘Get_Supplier_Order_Summary.sql’.

Output: Get_Supplier_Order_SummaryOutput.txt
