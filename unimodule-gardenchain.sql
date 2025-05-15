SET SERVEROUTPUT ON;    --Enables the usage of utilising and storing functions and procedures.
--Dropping off all sequences
DROP SEQUENCE customer_seq;
DROP SEQUENCE product_seq;
DROP SEQUENCE transaction_seq;
DROP SEQUENCE prodtype_seq;

--Initialising sequences (incrementing values to adhere to Company request for ease-of-access) --Compound key not necessary for a sequence
CREATE SEQUENCE customer_seq 
    MINVALUE 1
    START WITH 1
    INCREMENT BY 1;

CREATE SEQUENCE product_seq
    MINVALUE 1
    START WITH 1
    INCREMENT BY 1;

CREATE SEQUENCE transaction_seq
    MINVALUE 1
    START WITH 1
    INCREMENT BY 1;

CREATE SEQUENCE prodtype_seq
    MINVALUE 1
    START WITH 1
    INCREMENT BY 1;


--Dropping Tables in reverse order
DROP TABLE transaction CASCADE CONSTRAINTS;
DROP TABLE Store_Stock CASCADE CONSTRAINTS;
DROP TABLE product CASCADE CONSTRAINTS;
DROP TABLE product_type CASCADE CONSTRAINTS;
DROP TABLE customer CASCADE CONSTRAINTS;
DROP TABLE bank_branch CASCADE CONSTRAINTS;

--Creating Tables       
CREATE TABLE bank_branch(
    b_sortcode CHAR(6) NOT NULL PRIMARY KEY,
    b_name VARCHAR2(30) NOT NULL,
    b_street VARCHAR2(30) NOT NULL,
    b_town VARCHAR2(25),
    b_postcode VARCHAR2(8) NOT NULL
    );

CREATE TABLE customer(
    customer_id NUMBER(5) NOT NULL PRIMARY KEY,
    c_surname VARCHAR2(15) NOT NULL,
    c_forename VARCHAR2(15) NOT NULL,
    c_street VARCHAR2(25) NOT NULL,
    c_town VARCHAR2(25),
    c_postcode VARCHAR2(8) NOT NULL,
    c_telno VARCHAR2(13), --telno is 13 characters incase of +44 format
    date_of_birth DATE NOT NULL,    --Enforcing an age limit
    account_num VARCHAR2(8) NOT NULL,
    b_sortcode CHAR(6) NOT NULL,
    FOREIGN KEY (b_sortcode) REFERENCES bank_branch(b_sortcode)
    );

CREATE TABLE product_type(
    type_id NUMBER(3) NOT NULL PRIMARY KEY,
    type_name VARCHAR2(15) NOT NULL); 

--Allowing for GBP will require decimal precision of 4, with 2 values allowed on the right side of the decimal point
CREATE TABLE product(
    product_id NUMBER(6) NOT NULL PRIMARY KEY,
    prod_name VARCHAR2(20) NOT NULL,
    prod_type NUMBER(3) NOT NULL,
    prod_cost DECIMAL(4,2) NOT NULL,
    prod_desc VARCHAR2(255) NOT NULL,
    FOREIGN KEY (prod_type) REFERENCES product_type(type_id));

CREATE TABLE store_stock(
    store_id NUMBER(4) NOT NULL, --Unique is required for the constraints to allow for customer_order table to exist
    product_id NUMBER(6) NOT NULL,  
    stock NUMBER(5) NOT NULL,   --Value for quantity of items, vary of 5 as they may reach 10000 of smaller items, such as seed packets distributed to all stores in future
    Stock_check DATE NOT NULL,  --Using Sysdate procedure will allow for the stockcheck to timestamp the last time it has been updated. (once transaction)
    PRIMARY KEY (store_id, product_id), --The store can only have 1 of each product type, therefore a compound key is useful
    FOREIGN KEY (product_id) REFERENCES product(product_id)
    );

CREATE TABLE customer_transaction(
    order_num NUMBER(6) NOT NULL,
    customer_id NUMBER(5) NOT NULL,
    store_id NUMBER(4) NOT NULL,
    product_id NUMBER(6) NOT NULL, 
    order_date DATE NOT NULL,
    PRIMARY KEY(order_num),
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
    FOREIGN KEY (store_id, product_id) REFERENCES store_stock(store_id, product_id)
    );

--Declaring usable Trigger: Restricting the age to 18+ 
CREATE OR REPLACE TRIGGER age_restriction
    BEFORE INSERT ON customer
    FOR EACH ROW
DECLARE
    invalid_age EXCEPTION;
BEGIN   
    IF MONTHS_BETWEEN(SYSDATE, :new.date_of_birth) / 12 < 18 THEN   
    --Enforces age limit based on MONTHS_BETWEEN function / year. SYSDATE allows for consistent functionality as opposed to a hard-coded date.
    --Calculate the quantity of months between date of birth and today, then divide by the year.
        RAISE invalid_age;
    END IF;
EXCEPTION   
    WHEN invalid_age THEN
        RAISE_APPLICATION_ERROR(-20001, 'You are too young to become a customer.');
END;
/

--Ensure stock cannot be entered (and stockcheck) after current timestamp 
CREATE OR REPLACE TRIGGER date_limit_stock
BEFORE INSERT ON STORE_STOCK
FOR EACH ROW
DECLARE
    valid_date BOOLEAN := true;    
    incorrect_date EXCEPTION; 
    --Declare boolean value for true/false if after SYSDATE
BEGIN   
    IF :NEW.Stock_check > sysdate THEN
        valid_date := FALSE;
    END IF;

    IF NOT valid_date THEN
        RAISE incorrect_date;
    END IF;
EXCEPTION
    WHEN incorrect_date THEN
        RAISE_APPLICATION_ERROR(-20022, 'You have entered a date beyond the current date.');
END;
/

--Ensure stock cannot be entered (and stockcheck) after current timestamp 
CREATE OR REPLACE TRIGGER date_limit_transac
BEFORE INSERT ON transaction
FOR EACH ROW
DECLARE
    valid_date BOOLEAN := true;    
    incorrect_date EXCEPTION; 
    --Declare boolean value for true/false if after SYSDATE
BEGIN   
    IF :NEW.order_date > sysdate THEN
        valid_date := FALSE;
    END IF;

    IF NOT valid_date THEN
        RAISE incorrect_date;
    END IF;
EXCEPTION
    WHEN incorrect_date THEN
        RAISE_APPLICATION_ERROR(-20023, 'You have entered a date beyond the current date.');
END;
/

CREATE OR REPLACE TRIGGER valid_stock
    BEFORE INSERT OR UPDATE ON transaction
    FOR EACH ROW
DECLARE
    invalid_stock EXCEPTION;    --Declaring an invalid exception
    check_stock store_stock.stock%TYPE;
BEGIN  
    SELECT stock into check_stock   --Selecting the stock from a specific store for specific item
    FROM STORE_STOCK
    WHERE store_id = :new.store_id
    AND product_id = :new.product_id;

    IF check_stock <= 0 THEN --Checks if stock value is <= 0 (including from a transaction), cause application error
        RAISE invalid_stock;    
    END IF;
EXCEPTION
    WHEN invalid_stock THEN 
        RAISE_APPLICATION_ERROR(-20002, 'There is insufficient stock for this purchase, many apologies'); 
    WHEN NO_DATA_FOUND THEN          --When no rows are found
        RAISE_APPLICATION_ERROR(-20003, 'No matching record found');
END;
/

--Insertion Queries (Bank Details)
INSERT INTO bank_branch VALUES ('403505' ,'HSBC Bank', '110 Gray Street', 'Newcastle Upon Tyne', 'NE16JG');
INSERT INTO bank_branch VALUES ('306040', 'Lloyds Bank', '102 Grey Street', 'Newcastle Upon Tyne', 'NE16AG');
INSERT INTO bank_branch VALUES ('050623', 'Yorkshire Bank', '131-135 Northumberland Street', 'Newcastle Upon Tyne', 'NE17AG'  );
INSERT INTO bank_branch VALUES ('403421', 'Barclays Bank', '49-51 Northumberland Street', 'Newcastle Upon Tyne', 'NE17AF');
INSERT INTO bank_branch VALUES ('105121', 'Lloyds Bank', '171 Shields Road', 'Newcastle Upon Tyne', 'NE61HN' );
INSERT INTO bank_branch VALUES ('089022', 'The Co-Operative Bank Plc', '5-6 Fawcett St', 'Sunderland', 'SR11RF');

--Insertion Queries (Customer) Banking information is added to each customer as each customer is only allowed 1 bank account.
INSERT INTO Customer VALUES
(customer_seq.nextval, 'Jenkins','Melanie', 'Rochester Avenue', 'Newcastle Upon Tyne', 'NE42RH', '07495813315', '18-JUL-1990', '91510495', '403505');
INSERT INTO customer VALUES
(customer_seq.nextval, 'Harrison','Gilbert', 'Gateshead Road', 'Gateshead', 'NE72FA', '07405961472', '30-MAR-2005', '81051285', '306040');
INSERT INTO customer VALUES
(customer_seq.nextval, 'Barnett','Celeste', 'Pilgrim Street' ,'Newcastle Upon Tyne', 'NE12FX', '01914059256','05-JUN-2001', '18505928', '403421');
INSERT INTO customer VALUES
(customer_seq.nextval, 'Ford','Vincent', 'Newcastle Road', 'Sunderland', 'SR17RS', '01948510295', '25-DEC-1985', '18505928', '105121');
INSERT INTO customer VALUES
(customer_seq.nextval, 'Booker','Buck', 'Roker Boulevard', 'Sunderland', 'SR62RH', '07401958273', '18-JUL-2003' , '15861285', '105121' );
INSERT INTO customer VALUES
(customer_seq.nextval, 'Wolfe', 'Ruben', 'City Centre Road', 'Newcastle Upon Tyne', 'NE26BN', '+447159402854', '11-APR-2001', '68015816', '089022');

--Insertion Queries (Product type)
INSERT INTO product_type VALUES (PRODTYPE_SEQ.nextval, 'Tool');
INSERT INTO product_type VALUES (PRODTYPE_SEQ.nextval, 'Plant');
INSERT INTO product_type VALUES (PRODTYPE_SEQ.nextval, 'Seed');
INSERT INTO product_type VALUES (PRODTYPE_SEQ.nextval, 'Sapling');
INSERT INTO product_type VALUES (PRODTYPE_SEQ.nextval, 'Garden Stones');
INSERT INTO product_type VALUES (PRODTYPE_SEQ.nextval, 'Flower');

--Insertion Queries (Product)
INSERT INTO product VALUES (PRODUCT_SEQ.nextval, 'Tomato', 3, 5, 'Plentiful Tomatoes ready to be planted!');
INSERT INTO product VALUES (PRODUCT_SEQ.nextval, 'Allium', 6, 8, 'A blossoming Flower.');
INSERT INTO product VALUES (PRODUCT_SEQ.nextval, 'Oak', 4, 24.99, 'Pave way to a sustainable future, plant an Oak Sapling Today!');
INSERT INTO product VALUES (PRODUCT_SEQ.nextval, 'Lily', 6, 3.99, 'A flower that can lay elegantly on water.');
INSERT INTO product VALUES (PRODUCT_SEQ.nextval, 'Shears', 1, 14.99, 'A tool useful for shearing Sheep.');
INSERT INTO product VALUES (PRODUCT_SEQ.nextval, 'Trowel', 1, 8, 'A tool useful for plotting small holes for planting seeds.');

--Insertion Queries(StoreStock)
INSERT INTO store_Stock values (1, 3, 15, '8-JUN-18'); 
INSERT INTO store_Stock values (1, 2, 6, '15-JUN-18'); 
INSERT INTO store_Stock values (2, 4, 1, '21-JUN-18'); 
INSERT INTO store_Stock values (3, 6, 4, '16-JUN-18'); 
INSERT INTO store_Stock values (4, 6, 50, '28-JUN-18'); 
INSERT INTO store_Stock values (3, 4, 1, '28-JUN-18'); 


INSERT INTO customer_transaction (order_num, customer_id, store_id, product_id, order_date) 
values (TRANSACTION_SEQ.nextval, 1, 3, 6, '12-MAR-2023' );

INSERT INTO customer_transaction (order_num, customer_id, store_id, product_id, order_date) 
values (TRANSACTION_SEQ.nextval, 4, 1, 2, '15-JUN-2023' );

INSERT INTO customer_transaction (order_num, customer_id, store_id, product_id, order_date) 
values (TRANSACTION_SEQ.nextval, 5, 1, 2, '13-APR-2024' );

INSERT INTO customer_transaction (order_num, customer_id, store_id, product_id, order_date) 
values (TRANSACTION_SEQ.nextval, 2, 4, 6, '13-APR-2024' );

INSERT INTO customer_transaction (order_num, customer_id, store_id, product_id, order_date) 
values (TRANSACTION_SEQ.nextval, 3, 4, 6, '15-APR-2024' );

INSERT INTO customer_transaction (order_num, customer_id, store_id, product_id, order_date) 
values (TRANSACTION_SEQ.nextval, 3, 3, 6, '18-APR-2024' );

--Procedure for purchasing a single item (with quantity) at a specific store.
CREATE OR REPLACE PROCEDURE purchase(
    inp_customer TRANSACTION.CUSTOMER_ID%TYPE,
    inp_store_id STORE_STOCK.STORE_ID%TYPE, --Setting input parameters
    inp_product_id STORE_STOCK.PRODUCT_ID%TYPE)
AS
    existing_stock STORE_STOCK.STOCK%TYPE;
    customer_id CUSTOMER.CUSTOMER_ID%TYPE;
    no_customer EXCEPTION;
    stock_issue EXCEPTION;
    product_name PRODUCT.PROD_NAME%TYPE;
    product_price PRODUCT.PROD_COST%TYPE;
    total_cost NUMBER;  --Number provides the correct value in this scenario, decimal rounds it
    this_prod_type PRODUCT.PROD_TYPE%TYPE;
    
BEGIN --Selection query for the stock, product name and price. Store
    SELECT s.stock, p.prod_name, p.prod_cost, p.prod_type  --type_name refers to the product type table while the rest is product and store_stock
    INTO existing_stock, product_name, product_price, this_prod_type
    FROM STORE_STOCK s  --S is store stock
    JOIN product p ON s.product_id = p.product_id   --JOIN to access the product name, Price of correct product in the store table (Foreign Key)
    WHERE s.store_id = inp_store_id AND s.product_id = inp_product_id;

    SELECT customer_id INTO customer_id --Accessing an existing customer
    FROM customer
    WHERE customer_id = inp_customer;

        IF customer_id IS NULL THEN     --Raise error if no customer found
            raise no_customer;
        END IF;

    IF existing_stock <=0 THEN --Checks if the value is 0 (less than 1 not permitted)
        RAISE stock_issue;
    END IF;

    UPDATE store_stock
    SET stock = stock - 1
    WHERE store_id = inp_store_id AND product_id = inp_product_id;
            
    --Insertion query to Transaction table and success message
    INSERT INTO customer_transaction (order_num, customer_id, store_id, product_id, order_date) 
    VALUES (TRANSACTION_SEQ.nextval, inp_customer, inp_store_id, inp_product_id, SYSDATE);
    DBMS_OUTPUT.PUT_LINE('The purchase has been successful, you have paid £' || product_price || ' for ' || product_name || ' type ' || this_prod_type || ' at store ' || inp_store_id);

EXCEPTION   --Mulitple exceptions declared
    WHEN no_customer THEN --Error raised for not accessing the customer
        RAISE_APPLICATION_ERROR(-20004, 'Purchase Unsuccessful, No customer of this id found.');
    WHEN stock_issue THEN
        RAISE_APPLICATION_ERROR(-20006, 'Insufficient stock for the purchase.');
    WHEN OTHERS THEN   
        RAISE_APPLICATION_ERROR(-20007, 'An error has occured with processing the purchase.');
END;
/

CREATE OR REPLACE PROCEDURE transaction_report(
    init_date customer_transaction.order_date%TYPE,
    end_date customer_transaction.order_date%TYPE)
AS
    check_found BOOLEAN := FALSE;   --Boolean variable to check for 0 transactions    
BEGIN
    DBMS_OUTPUT.PUT_LINE('Transaction Report');
    FOR rec IN (       --Creating a record variable for the for-loop
        SELECT t.order_date, p.prod_name, p.prod_cost
        FROM transaction t
        JOIN product p ON t.product_id = p.product_id  --Accesses the Product name through JOIN of product relevance between tables
        WHERE t.order_date BETWEEN init_date AND end_date)

    LOOP    --Looping the output for relaying all orders BETWEEN the dates stored under the rec variable.
        DBMS_OUTPUT.PUT_LINE('Order Date: ' || rec.order_date || ', Product Name: ' || rec.prod_name ||', Cost: £' || rec.prod_cost);     --Accesses the values through the rec variable (rec.)
        check_found := TRUE;  --Sets the boolean condition to true
    END LOOP;

    --False boolean condition returns text that there were no purchases
    IF NOT check_found THEN
        DBMS_OUTPUT.PUT_LINE('There are no found transactions between the selected dates.');
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20008, 'There has been an issue with the procedure, many apologies');
END;
/

--Creating the procedure to transfer stock between stores
CREATE OR REPLACE PROCEDURE transfer_stock(
    source_store STORE_STOCK.STORE_ID%TYPE,
    dest_store STORE_STOCK.STORE_ID%TYPE,
    prod_id STORE_STOCK.PRODUCT_ID%TYPE,
    quantity STORE_STOCK.STOCK%TYPE)
AS
    available_stock STORE_STOCK.STOCK%TYPE;
    same_store EXCEPTION;
    insufficient_stock EXCEPTION;
BEGIN
    --Ensure the same store isnt entered: The purpose is to transfer across stores
    IF source_store = dest_store THEN
        RAISE same_store;
    END IF;

    --Selecting the stock value and placing into available_stock for specific item 
    SELECT stock INTO available_stock
    FROM store_stock
    WHERE product_id = prod_id
    AND store_id = source_store;

    --Integrity: Raise exception if there is not enough stock to transfer
    IF available_stock < quantity THEN
        RAISE insufficient_stock;
    END IF;

    --Updating the value of the source (- amount)
    UPDATE store_stock
    SET stock = stock - quantity
    WHERE product_id = prod_id 
    AND store_id = source_store;

    --Updating the value of the source (+ amount)
    UPDATE store_stock
    SET stock = stock + quantity
    WHERE product_id = prod_id 
    AND store_id = dest_store;
    
    DBMS_OUTPUT.PUT_LINE('You have transferred ' || quantity || ' of product ' || prod_id || ' to store ' || dest_store);

EXCEPTION
    WHEN insufficient_stock THEN   
        RAISE_APPLICATION_ERROR(-20009, 'There is insufficient stock for the transfer');
    WHEN same_store THEN
        RAISE_APPLICATION_ERROR(-20010, 'You cannot transfer stock to the same store');
    WHEN OTHERS THEN
        ROLLBACK;   --If a different error occurs, then rollback the DB to preserve integrity and functionality.
        RAISE;
END; 
/

-------------------TESTING PL/SQL SECTION-----------------------------------------------------------
--Testing age_restriction 1 for an < 18 user 
INSERT INTO customer VALUES(customer_seq.nextval, 'Cooper', 'Shannon', 'Jesmond', 'Newcastle Upon Tyne' , 'NE24BX', '07056422254', '15-APR-2010', '62012376', '403505');

--Testing inserting after current date 
INSERT INTO store_stock VALUES (2, 5, 2, '24-MAR-2025');

--Testing Purchase Procedure 1, 2, 3:
SELECT stock FROM store_stock WHERE store_id = 1 AND product_id = 3;
EXECUTE purchase(4, 1, 3);  
SELECT stock FROM store_stock WHERE store_id = 1 AND product_id = 3; 

EXECUTE purchase(1, 1, 3);  
--Raises Application error: Not enough quantity
EXECUTE purchase(1, 2, 4);   
--OTHER Exception accessed
EXECUTE purchase(1, 3, 6);

--Last product of that store
EXECUTE purchase(1, 2, 4);

--Unsuccessful purchase
EXECUTE purchase(1, 2, 4);

EXECUTE purchase(4, 1, 2);
EXECUTE purchase(5, 1, 2);

--Error: raise incorrect customer (no customer 15)
EXECUTE purchase(15, 1, 2);

--Testing transac_report Procedure 1, 2, 3:
EXECUTE transaction_report('14-MAY-2024', SYSDATE); --current date tests ideal as SYSDATE timestamps a purchase
EXECUTE transaction_report('14-MAY-2023', '18-MAY-2023');
EXECUTE transaction_report('12-MAR-2023', '15-APR-2023');
--Calling procedure Stock Report (raising application error)

--Testing transfer_stock procedure
--Store 4 transferring to store 3 product 6 of quantity 4.
EXECUTE transfer_stock(4, 3 , 6, 4);

--Error Call: Store 3 cannot send 10 quantity of product 6      
EXECUTE transfer_stock(3, 4 , 6, 10);      

--Raise call: same_store
EXECUTE transfer_stock(3, 3 , 6, 10);    
EXECUTE transfer_stock(15, 3 , 6, 10); 

--The Big Commit()
COMMIT;
