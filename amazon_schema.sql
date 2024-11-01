--Amazon SQL Project

--Category table
CREATE TABLE category (
category_id SERIAL PRIMARY KEY NOT NULL,
category_name VARCHAR(20)
);

-------------------------------------------------------------------------------------------

--Customers table
CREATE TABLE customers (
customer_id SERIAL PRIMARY KEY NOT NULL,
first_name VARCHAR(20),
last_name VARCHAR(20),
state VARCHAR(25),
address VARCHAR(100) DEFAULT ('XXXX')
);


--------------------------------------------------------------------------------------------

--Seller table
CREATE TABLE sellers (
seller_id SERIAL PRIMARY KEY,
seller_name VARCHAR(25),
origin VARCHAR(20)
);


---------------------------------------------------------------------------------------

--Product table
CREATE TABLE products (
product_id SERIAL PRIMARY KEY,
product_name VARCHAR(50),
price NUMERIC(19,2),
cogs NUMERIC(19,2),
category_id INT,
FOREIGN KEY (category_id) REFERENCES category (category_id)
);

INSERT INTO products (product_name, price, cogs, category_id)
SELECT
    'Product ' || s,
    ROUND((random() * 1000)::numeric, 2), -- Random price between 0 and 1000
    ROUND((random() * 500)::numeric, 2), -- Random COGS between 0 and 500
    FLOOR(random() * 6 + 1) -- Random category_id between 1 and 6
FROM generate_series(1, 150) s;


----------------------------------------------------------------------------------------------

--Order table
CREATE TABLE orders (
order_id SERIAL PRIMARY KEY,
order_date DATE,
customer_id INT,
order_status VARCHAR(15),
seller_id INT,
FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
);

SELECT DISTINCT(customer_id) FROM customers ORDER BY customer_id DESC; -- 1to 1000
SELECT DISTINCT(seller_id) FROM sellers ORDER BY seller_id ASC; -- 151 to 200

INSERT INTO orders (order_date, customer_id, order_status, seller_id)
SELECT
    CURRENT_DATE - INTERVAL '1 day' * FLOOR(random() * 365), -- Random order_date within the last year
    FLOOR(random() * 1000 + 1), -- Random customer_id between 1 and 1000
    (ARRAY['pending', 'shipped', 'delivered', 'cancelled'])[FLOOR(random() * 4 + 1)], -- Random order_status
    FLOOR(random() * 50 + 151) -- Random seller_id between 151 and 200
FROM generate_series(1, 200);

SELECT * FROM orders LIMIT 5;


---------------------------------------------------------------------------------------------

--order item table
CREATE TABLE order_items (
order_item_id SERIAL PRIMARY KEY,
order_id INT,
product_id INT,
quantity INT,
price_per_unit NUMERIC(19,2),
FOREIGN KEY (order_id) REFERENCES orders (order_id),
FOREIGN KEY (product_id) REFERENCES products (product_id)
);

INSERT INTO order_items (order_id, product_id, quantity, price_per_unit)
SELECT
    FLOOR(random() * (300 - 101 + 1) + 101), -- Random order_id between 101 and 300
    FLOOR(random() * (45150 - 45001 + 1) + 45001), -- Random product_id between 45001 and 45150
    FLOOR(random() * 10 + 1), -- Random quantity between 1 and 10
    ROUND((random() * 100)::numeric, 2) -- Random price_per_unit between 0 and 100
FROM generate_series(1, 350);

SELECT DISTINCT(order_id) FROM orders ORDER BY order_id ASC; -- 101 to 300
SELECT DISTINCT(product_id) FROM products ORDER BY product_id ASC;-- 45001 to 45150


----------------------------------------------------------------------------------------------

--payment table
CREATE TABLE payment (
payment_id SERIAL PRIMARY KEY,
order_id INT,
payment_date DATE,
payment_status VARCHAR(25),
FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

INSERT INTO payment (order_id, payment_date, payment_status)
SELECT
    FLOOR(random() * (300 - 101 + 1) + 101), -- Random order_id between 101 and 300
    CURRENT_DATE - INTERVAL '1 day' * FLOOR(random() * 365), -- Random payment_date within the last year
    (ARRAY['pending', 'completed', 'failed', 'refunded'])[FLOOR(random() * 4 + 1)] -- Random payment_status
FROM generate_series(1, 200);


------------------------------------------------------------------------------------------------

--shipping table
CREATE TABLE shipping (
shipping_id SERIAL PRIMARY KEY,
order_id INT,
shipping_date DATE,
return_date DATE,
shipping_providers VARCHAR(15),
delivery_status VARCHAR(15),
FOREIGN KEY (order_id) REFERENCES orders (order_id)
);

ALTER TABLE shipping
ALTER COLUMN shipping_providers TYPE VARCHAR(20);

-- Insert random values into shipping table
INSERT INTO shipping (order_id, shipping_date, return_date, shipping_providers, delivery_status)
SELECT
    FLOOR(random() * (300 - 101 + 1) + 101), -- Random order_id between 101 and 300
    CURRENT_DATE - INTERVAL '1 day' * FLOOR(random() * 365), -- Random shipping_date within the last year
    CURRENT_DATE + INTERVAL '1 day' * FLOOR(random() * 30), -- Random return_date within the next 30 days
    (ARRAY['FedEx', 'UPS', 'DHL', 'USPS', 'Amazon Logistics'])[FLOOR(random() * 5 + 1)], -- Random shipping_providers
    (ARRAY['pending', 'shipped', 'delivered', 'returned'])[FLOOR(random() * 4 + 1)] -- Random delivery_status
FROM generate_series(1, 200);


-----------------------------------------------------------------------------------------------

--inventory table
CREATE TABLE inventory (
inventory_id SERIAL PRIMARY KEY,
product_id INT UNIQUE,
stock INT,
warehouse_id INT,
last_stock_date DATE,
FOREIGN KEY (product_id) REFERENCES products(product_id)
);


-------------------------------------------------------------------------------------------------

-- Insert random values into inventory table
INSERT INTO inventory (product_id, stock, warehouse_id, last_stock_date)
SELECT 
    gs.product_id,
    FLOOR(random() * 100 + 1), -- Random stock between 1 and 100
    FLOOR(random() * 10 + 1), -- Random warehouse_id between 1 and 10
    CURRENT_DATE - INTERVAL '1 day' * FLOOR(random() * 365) -- Random last_stock_date within the last year
FROM 
    (SELECT generate_series(45001, 45150) AS product_id) gs; 


