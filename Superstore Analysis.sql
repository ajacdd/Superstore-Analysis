-- Create a database for superstore data
CREATE DATABASE superstore;

-- Create an "orders" table, "returns" table, and "people" table
CREATE TABLE superstore.orders (
	row_id INT,
	order_id VARCHAR(20),
	order_date DATE,
	ship_date DATE,
	ship_mode VARCHAR(20),
	customer_id VARCHAR(10),
	customer_name VARCHAR(30),
	segment VARCHAR(20),
	country VARCHAR(20),
	city VARCHAR(20),
	state VARCHAR(20),
	postal_code VARCHAR(10),
	region VARCHAR(10),
	product_id VARCHAR(20),
	category VARCHAR(20),
	subcategory VARCHAR(20),
	product_name VARCHAR(130),
	sales DECIMAL(10,2),
	quantity DECIMAL(5,0),
	discount DECIMAL(5,2),
	profit DECIMAL(10,2)
);

CREATE TABLE superstore.returns (
	returned VARCHAR(3),
	order_id VARCHAR(20)
	);

CREATE TABLE superstore.people (
	person VARCHAR(20),
	region VARCHAR(10)
);

-- Find duplicate values in the "orders" table.
SELECT
	customer_name, COUNT(customer_name),
	order_date, COUNT(order_date),
	order_id, COUNT(order_id),
	customer_id, COUNT(customer_id),
	product_id, COUNT(product_id),
	sales, COUNT(sales),
	discount, COUNT(discount),
	quantity, COUNT(quantity)
FROM
	superstore.orders
GROUP BY
	customer_name, order_date, order_id, customer_id, product_id, sales, discount, quantity
HAVING
	COUNT(customer_name) > 1 
	AND COUNT(order_date) > 1 
	AND COUNT(order_id) > 1 
	AND COUNT(customer_id) > 1 
	AND COUNT(product_id) > 1 
	AND COUNT(sales) > 1 
	AND COUNT(discount) > 1 
	AND COUNT(quantity) > 1;

/*
There appears to be 1 exact duplicate entry across all columns for customer "Laurel Beltran" (row_id 3406 and 3407).
For the purposes of this project, I will assume that this is an error and will delete the second entry.
However, in a real-life business situation, I'd first want to check with the Order Management Team to confirm before removing from the dataset.
*/
DELETE FROM superstore.orders
WHERE row_id = 3407;

-- Update the 'orders' table schema to add an "order_year" column by extracting the year from order_date. This will allow for easier filtering by year. 
ALTER TABLE superstore.orders
ADD COLUMN order_year INT AFTER order_id;

UPDATE superstore.orders
SET order_year = YEAR(order_date);

-- What is the yearly total sales, profit, and YOY percent variance?
WITH yearly_totals AS 
	(SELECT order_year, SUM(sales) AS total_sales, SUM(profit) AS total_profit
	FROM superstore.orders
	GROUP BY 1
	ORDER BY 1)

SELECT
	order_year, total_sales, total_profit,
	(total_sales/LAG(total_sales) OVER(ORDER BY order_year) - 1)*100 AS yoy_sales_perc_var,
    (total_profit/LAG(total_profit) OVER(ORDER BY order_year) - 1)*100 AS yoy_profit_perc_var
FROM yearly_totals;

-- What is the total sales, average sales, and percent of total sales for each category?
SELECT
	category, SUM(sales) AS total_sales, AVG(sales) AS avg_sales,
	SUM(sales)/(SELECT SUM(sales) FROM superstore.orders)*100 AS perc_of_total
FROM 	superstore.orders
GROUP BY 1
ORDER BY 2 DESC;

-- Which subcategories have the highest and lowest total profit overall?
(
	SELECT subcategory, SUM(profit) AS total_profit
	FROM superstore.orders
	GROUP BY 1
	ORDER BY 2 DESC
	LIMIT 1
)
UNION
(
	SELECT subcategory, SUM(profit) AS total_profit
	FROM superstore.orders
	GROUP BY 1
	ORDER BY 2 ASC
	LIMIT 1
);

-- Which customer segments generated the most and least profits?
SELECT segment, SUM(profit) AS total_profit
FROM superstore.orders
GROUP BY 1
ORDER BY 2 DESC;

-- What are the top 3 spending customers?
SELECT *
FROM 
	(SELECT customer_id, customer_name, SUM(sales) AS total_spend,
		DENSE_RANK() OVER(ORDER BY SUM(sales) DESC) AS top_rank_customers
	FROM superstore.orders
	GROUP BY 1, 2) AS t1
WHERE top_rank_customers <= 3;

-- How many orders were placed compared to orders returned each year?
SELECT
	order_year,
    COUNT(DISTINCT o.order_id) AS num_orders_placed, 
    COUNT(DISTINCT r.order_id) AS num_orders_returned,
    COUNT(DISTINCT r.order_id)/COUNT(DISTINCT o.order_id)*100 AS perc_returned
FROM superstore.orders o
LEFT JOIN superstore.returns r ON o.order_id = r.order_id
GROUP BY 1
ORDER BY 1;

-- What is the total sales, value of returned orders, and net sales by region along with the associated regional salesperson?
SELECT
	o.region, p.person, SUM(sales) AS total_sales,
	SUM(CASE WHEN r.returned = 'Yes' THEN sales END) AS total_return_value,
    SUM(sales)-SUM(CASE WHEN r.returned = 'Yes' THEN sales END) AS net_sales,
    SUM(CASE WHEN r.returned = 'Yes' THEN sales END)/SUM(sales)*100 AS percent_of_total_sales_returned
FROM superstore.orders o
LEFT JOIN superstore.returns r ON o.order_id = r.order_id
LEFT JOIN superstore.people p ON o.region = p.region
GROUP BY 1, 2
ORDER BY net_sales DESC;

-- How many orders shipped 7+ days after the order date? 
WITH long_orders AS
	(SELECT order_year, order_id, product_id, order_date, ship_date, DATEDIFF(ship_date, order_date) AS order_to_ship_time
    FROM superstore.orders)
    
SELECT
    (SELECT COUNT(DISTINCT order_id) FROM superstore.orders) AS total_orders,
    COUNT(DISTINCT order_id) AS num_long_orders,
    COUNT(DISTINCT order_id)/(SELECT COUNT(DISTINCT order_id) FROM superstore.orders)*100 AS perc_long_orders
FROM long_orders
WHERE order_to_ship_time >= 7;

