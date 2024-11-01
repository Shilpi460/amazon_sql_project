# amazon_sql_project

## **Project Overview**

I have worked on analyzing a dataset of an amazon-like e-commerce platform. This project involves extensive querying of customer behaviour, product performance, and sales trends using postgresSQL. Through this project, I have tackled various  SQL problems, including revenue analysis, customer segmentation, and inventory management.

The project also focuses on data cleaning, handling null values, and solving real-world business problem using structured queries.

An ERD diagram is included to visually represent the database schema and relationships between tables.

## **Database Setup & Design**

### **Schema Structure**
-- The database contain **8 tables**: 'customers','sellers','products','orders','order_items','inventory','payments' and 'shipping'.
-- These tables are designed with **primary keys**, **foreign key constraints**, and proper indexing to maintain data integrity and optimize query performance.
-- You can find the SQL script for setting up the database schema [here](https://github.com/Shilpi460/amazon_sql_project/blob/main/amazon_schema.sql)

---

### **Constraints**
- Referential integrity is enforced using foreign keys.
- Default values and data types are applied where necessary to maintain consistency.
- Uniqueness is guaranteed for fields like 'product_id', 'order_id',  and 'customer_id'.

---

## **Task: Data Cleaning**

I cleaned dataset by:
- Removing duplicates: Duplicates in the customer and order tables were identified and removed.
- Handling misisng values: Null values in critical fields (e.g. customer address, payment status) were either filled with default values or handled using appropriate methods.

---

## **Identifying Business Problems**

Key business problems identified:
1. Top selling products: Top 10 products by total sales values;

```sql
SELECT
p.product_id,p.product_name, subquery.quantity, subquery.total_price
FROM products p
JOIN 
(SELECT 
product_id, SUM(quantity) AS quantity,
SUM(price_per_unit * quantity) AS total_price 
FROM order_items
GROUP BY product_id
ORDER BY total_price DESC
LIMIT 10) AS subquery
ON p.product_id = subquery.product_id;
```

2. Revenue by category: Calculate total revenue generated by each product category;

```sql
SELECT category_name, total_revenue, ROUND(total_revenue*100/SUM(total_revenue) OVER (),2) AS revenue_by_category
FROM
(SELECT category_name, SUM(price_per_unit * quantity) AS total_revenue
FROM
(SELECT * FROM order_items JOIN 	
(SELECT * FROM products JOIN category USING (category_id)) USING (product_id))
AS subquery
GROUP BY category_name) AS subquery;
```

3. Average order value (AOV): Compute the average order value for each customer;

```sql
SELECT customer_id, CONCAT(first_name,' ',last_name), total_orders, average_order_value
FROM customers RIGHT JOIN
(SELECT 
	customer_id, COUNT(order_id) AS total_orders, SUM(total_price) AS total_revenue,
	ROUND(SUM(total_price)/COUNT(order_id),2) AS average_order_value
FROM
(SELECT customer_id, order_id, quantity * price_per_unit AS total_price
FROM
(SELECT * FROM order_items
JOIN 
(SELECT * FROM customers
JOIN orders USING (customer_id)) USING (order_id)
AS subquery1))
AS subquery2 
GROUP BY customer_id
HAVING COUNT(order_id)>5) USING (customer_id);
```

4. Monthly sales trend: Query monthly total sales over the past year;

```sql
SELECT 
month, year, sales_current_month, last_month_sale,
ROUND((sales_current_month-last_month_sale)*100/last_month_sale,2) AS growth_percentage
FROM
(SELECT
	month, year, sales_current_month,
	LAG(sales_current_month,1) OVER(ORDER BY year, month) AS last_month_sale
FROM
(SELECT
	EXTRACT(MONTH FROM order_date) AS month,
	EXTRACT(YEAR FROM order_date) AS year,
	SUM(total_sales) AS sales_current_month
FROM
(SELECT order_date, quantity * price_per_unit AS total_sales
FROM
(SELECT * FROM orders 
JOIN order_items USING (order_id) 
WHERE order_date > CURRENT_DATE - INTERVAL '1 year')) As subquery
GROUP BY month, year
ORDER BY year, month ASC) AS subquery2) AS subquery3;
```

5. Customers with no puchases: Find the customer who have registered but never placed an order;

```sql
SELECT customer_id, CONCAT(first_name, last_name), state, address, reg_date - CURRENT() AS no_of_days_registered
FROM customers
WHERE customer_id NOT IN (
 SELECT DISTINCT customer_id FROM orders);
```

6. Best selling categories by state: Identify the best-selling product category for each state;

```sql
WITH ranking_table
AS
(SELECT category_id, category_name,state, COUNT(order_id), SUM(quantity*price_per_unit) AS total_sales,
RANK() OVER(PARTITION BY state ORDER BY COUNT(order_id) DESC) AS rank_by_state
FROM
(SELECT * FROM customers
JOIN
((SELECT * FROM orders
JOIN
(SELECT * FROM order_items
JOIN
(SELECT * FROM category 
JOIN products USING (category_id)) USING (product_id)) USING (order_id))) USING (customer_id))
GROUP BY state,category_id, category_name
ORDER BY state,COUNT(order_id) DESC)

SELECT * FROM ranking_table WHERE rank_by_state = 1;
```

7. Customer lifetime value (CLTV): Calculate the total value of orders placed by each customer over the lifetime;

```sql
SELECT c1.customer_id, CONCAT(c1.first_name, ' ',c1.last_name) AS full_name, c2.total_sales, c2.rank
FROM customers c1
JOIN
(SELECT customer_id, COALESCE(SUM(quantity*price_per_unit),0) AS total_sales,
DENSE_RANK() OVER(ORDER BY COALESCE(SUM(quantity*price_per_unit),0) DESC) AS rank
FROM
(SELECT * FROM customers
LEFT JOIN 
(SELECT * FROM orders
JOIN order_items USING (order_id)) USING (customer_id))
GROUP BY customer_id) AS c2 ON c1.customer_id = c2.customer_id;
```

8. Inventory stock alert: Query product with stock levels below a certain threshold (e.g. less than 10 units);

```sql
SELECT warehouse_id, last_stock_date, stock FROM inventory
JOIN products USING (product_id)
WHERE stock <10;
```

9. Shipping delays: Identify the orders where the shipping is later than 7 days after the order date;
   
```sql
SELECT CONCAT(first_name,' ',last_name),order_id, order_date, order_status,seller_name, shipping_providers
FROM
(SELECT * FROM customers
JOIN
(SELECT * FROM sellers
JOIN 
(SELECT * FROM orders
JOIN shipping USING (order_id)
WHERE shipping_date - order_date > 7) USING (seller_id)) USING (customer_id));
```

10. Payment success rate: Calculate the percentage of successful payments across all orders;

```sql
SELECT payment_status,COUNT(*),
ROUND(COUNT(*)::numeric/(SELECT COUNT(*) FROM payment)::numeric * 100,2) AS per_total
FROM payment
GROUP BY payment_status;
```

11. Top performing sellers: Find the top 5 sellers based on the total sales value;

```sql
WITH top_sellers
AS
(SELECT se.seller_id,se.seller_name,SUM(oi.quantity*oi.price_per_unit)
FROM sellers se
JOIN orders o ON se.seller_id = o.seller_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY se.seller_id, se.seller_name
ORDER BY SUM(oi.quantity*oi.price_per_unit) DESC
LIMIT 5),

sellers_report
AS
(SELECT 
	o.seller_id,
	ts.seller_name,
	o.order_status,
	COUNT(*) AS total_orders
FROM orders o
JOIN top_sellers ts USING(seller_id)
WHERE order_status NOT IN ('shipped','pending')
GROUP BY 1, 2, 3
)

SELECT
	seller_id,
	seller_name,
	SUM(CASE WHEN order_status = 'delivered' THEN total_orders ELSE 0 END) AS completed_orders,
	SUM(CASE WHEN order_status = 'cancelled' THEN total_orders ELSE 0 END) AS cancelled_orders,
	SUM(total_orders) AS total_orders,
	ROUND(SUM(CASE WHEN order_status = 'delivered' THEN total_orders ELSE 0 END)::numeric/SUM(total_orders)::numeric * 100,2) AS successful_order_percentage
FROM sellers_report
GROUP BY 1, 2;
```

12. Product profit margin: Calculate the profit margin for each product (difference between price and cost of goods sold);

```sql
SELECT p.product_id, p.product_name, SUM(o.price_per_unit-p.cogs) AS profit,
ROUND(SUM(o.price_per_unit-p.cogs)/SUM(o.price_per_unit)*100,2) AS profit_margin,
RANK() OVER(ORDER BY SUM(o.price_per_unit-p.cogs)/SUM(o.price_per_unit) DESC)
FROM products p
JOIN order_items o USING (product_id)
GROUP BY 1,2;
```

13. Most returned products: Query the top 10 products by the number of returns;
    
```sql
--- Assuming cancelled and returns are same here
SELECT p.product_id, p.product_name, COUNT(*) AS total_orders, 
SUM(CASE WHEN o.order_status = 'cancelled' THEN 1 ELSE 0 END) AS total_returns,
ROUND(SUM(CASE WHEN o.order_status = 'cancelled' THEN 1 ELSE 0 END)::numeric/COUNT(*)::numeric*100,2) AS return_percentage
FROM order_items oe
JOIN products p USING (product_id)
JOIN orders o USING (order_id)
GROUP BY 1,2
ORDER BY 5 DESC;
```

14. Inactive sellers: Identify the sellers who haven't made any sales in the last 6 months;

```sql
WITH inactive_sellers
AS
(SELECT * FROM sellers
WHERE seller_id IN
(SELECT DISTINCT seller_id
FROM orders
WHERE CURRENT_DATE - order_date > 180))
SELECT seller_id,MAX(order_date),SUM(quantity*price_per_unit) AS total_sales
FROM order_items oe
JOIN orders o USING(order_id)
JOIN inactive_sellers i_s USING (seller_id)
GROUP BY 1;
```

15. Identify customers into returning or new: If the customer has done more than 5 return categorize them as returning otherwise new;

```sql
SELECT 
full_name,
total_orders,
total_returns,
CASE
	WHEN total_returns > 5 THEN 'returning' ELSE 'new'
	END AS cx_category
FROM
(SELECT 
CONCAT(first_name,' ',last_name) AS full_name,
COUNT(o.order_id) AS total_orders,
SUM(CASE WHEN order_status = 'cancelled' THEN 1 ELSE 0 END)::numeric AS total_returns
FROM customers c
JOIN orders o USING (customer_id)
GROUP BY 1);
```

16. Top 5 customers by orders in each state : Identify the top 5 customers with the highest number of orders and total sales for each customer;

```sql
SELECT * FROM
(SELECT 
	state, 
	CONCAT(c.first_name,' ', c.last_name) AS full_name,
	COUNT(o.order_id) AS total_orders,
	SUM(oi.quantity * oi.price_per_unit) AS total_sales,
	DENSE_RANK() OVER(PARTITION BY state ORDER BY COUNT(o.order_id) DESC) AS rank
FROM customers c
JOIN orders o USING (customer_id)
JOIN order_items oi USING (order_id)
GROUP BY 1,2)
WHERE rank <=5;
```

17. Revenue by shipping provider: Calculate the total revenue handled by each shipping provider;

```sql
SELECT 
	shipping_providers,
	COUNT(o.order_id) AS total_orders,
	SUM(oi.quantity * oi.price_per_unit) AS total_revenue,
	AVG(s.shipping_date - s.delivery_date) AS num_of_days --if delivery date is present in the table
FROM shipping s
JOIN orders o USING (order_id)
JOIN order_items oi USING (order_id)
GROUP BY 1;
```

18. Top 10 product with highest decreasing revenue compare to last year (2023) and current_year(2024);

```sql
WITH last_year_sales
AS
(SELECT p.product_id, p.product_name, SUM(oi.quantity*oi.price_per_unit) AS total_sales
FROM order_items oi
JOIN orders o USING (order_id)
JOIN products p USING (product_id)
WHERE EXTRACT(YEAR FROM order_date) = '2023'
GROUP BY 1,2),

current_year_sales
AS
(SELECT p.product_id, p.product_name, SUM(oi.quantity*oi.price_per_unit) AS total_sales
FROM order_items oi
JOIN orders o USING (order_id)
JOIN products p USING (product_id)
WHERE EXTRACT(YEAR FROM order_date) = '2024'
GROUP BY 1,2)

SELECT 
	cs.product_id,
	ls.total_sales AS last_year_revenue,
	cs.total_sales AS current_year_revenue,
	ls.total_sales - cs.total_sales AS rev_diff,
	ROUND((cs.total_sales-ls.total_sales)::numeric/ls.total_sales::numeric * 100,2) AS revenue_dec_ratio
FROM last_year_sales ls
JOIN current_year_sales cs
ON ls.product_id = cs.product_id
WHERE 
	ls.total_sales > cs.total_sales
ORDER BY 5 DESC
LIMIT 10;
```

18.Final task: Create a function as soon as the product is sold the same quantity should recuced from inventory table, after adding any sales records it should update the stock in the inventory table based on product and qty purchased;

```sql
CREATE OR REPLACE PROCEDURE add_sales
(
p_order_id INT,
p_customer_id INT,
p_seller_id INT,
p_order_item_id INT,
p_product_id INT,
p_quantity INT
)
LANGUAGE plpgsql
AS $$

DECLARE 
-- all variable
	v_count INT;
	v_price FLOAT;
BEGIN
-- all your code and logic

	SELECT price INTO v_price FROM products WHERE product_id = p_product_id;
	SELECT 
		COUNT(*) 
		INTO v_count
	FROM inventory
	WHERE 
		product_id = p_product_id
		AND
		stock = p_quantity;
	
	IF v_count > 0 THEN
		INSERT INTO orders (order_id, order_date, customer_id, seller_id)
		VALUES 
		(p_order_id, CURRENT_DATE, p_customer_id, p_seller_id);
	
		INSERT INTO order_items (order_item_id, order_id, product_id, quantity, price_per_unit)
		VALUES
		(p_order_item_id,p_order_id,p_product_id,p_quantity,v_price);

		UPDATE inventory
		SET stock = stock - p_quantity
		WHERE product_id = p_product_id;

		RAISE NOTICE 'Product sale has been added and inventory is updated';

	ELSE
		RAISE NOTICE 'Product is not available';
	END IF;
END
$$
```

---

## **Solving Business Problems**

### Solution Implemented:
- **Restock Predictions**: By forecasting product demand based on past sales, I optimized restcoking cycles, minimizing stockouts.
- **Product Performance**: Indentified high-return and optimized their sales strategies, such as product bundling and pricing adjustments.
- **Shipping Optimization**: Analyzed shipping times and delivery providers to recommend better logistics strategies and improve customer satisfaction.
- **Customer Segmentation**: Conducted RFM analysis to target marketing efforts towards "At-risk" customers, improving retention and loyalty.

---

## **Objective**

The primary objective of this project is to showcase SQL proficiency through complex queries that address real-world e-commerce business challenges. The analysis covers various aspects of e-commerce operations, including:
- Customer behaviour
- Sales trends
- Inventory management
- Payment and shipping analysis
- Forecasting and product performance

---

## **Learning Outcomes**

This project enabled me:
- Design and implement a normalized database schema.
- Clean and pre process real-world datasets for analysis.
- Use advanced SQL techniques, including window functions, subqueries and joins.
- Conduct in-depth business analysis using SQL.
- Optimize query performance and handle large datasets efficiently.

---

## **Conclusion**

This advanced SQL project successfully demonstrates my ability to solve real-world e-commerce problem with structured queries. From improving retention to operational efficiency, this project provides valuable insights into operational challenges and solutions.

By completing this project, I have gained a deeper understanding of how SQL can be used to tackle complex data problems and derive business decision making.

## **Entity Relationship Diagram (ERD)**
![ERD](https://github.com/Shilpi460/amazon_sql_project/blob/main/Screenshot%202024-10-22%20180532.png)
