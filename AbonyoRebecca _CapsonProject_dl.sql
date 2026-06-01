DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS city;

-- 1. Create City Table (Base Table)
CREATE TABLE city (
    city_id INT PRIMARY KEY,
    city_name VARCHAR(100) NOT NULL,
    population INT,
    estimated_rent NUMERIC(10, 2),
    city_rank INT
);

-- 2. Create Customers Table (References City)
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(150) NOT NULL,
    city_id INT,
    CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES city(city_id) ON DELETE SET NULL
);

-- 3. Create Products Table (Base Table)
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    price NUMERIC(10, 2) NOT NULL
);

-- 4. Create Sales Table (References Products and Customers)
CREATE TABLE sales (
    sale_id INT PRIMARY KEY,
    sale_date DATE NOT NULL,
    product_id INT,
    customer_id INT,
    total NUMERIC(10, 2) NOT NULL,
    rating INT,
    CONSTRAINT fk_product FOREIGN KEY (product_id) REFERENCES products(product_id) ON DELETE SET NULL,
    CONSTRAINT fk_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE SET NULL
);


SELECT * FROM city;
SELECT * FROM customers;
SELECT * FROM products;
SELECT * FROM sales;


-- ====================================================================
-- Question 1: Coffee Consumer Estimate
-- Calculates 25% of each city's population to find the estimated 
-- number of coffee consumers (in millions), sorted highest to lowest.
-- ====================================================================
SELECT 
    city_name,
    ROUND((population * 0.25) / 1000000.0, 2) AS estimated_coffee_consumers_millions    
FROM city
ORDER BY estimated_coffee_consumers_millions DESC;


-- ====================================================================
-- Question 2: Total Revenue - Q4 2023
-- Calculates total revenue per city specifically from October to December 2023,
-- ordered from the highest earning city to the lowest.
-- ====================================================================
SELECT 
    c.city_name,
    SUM(s.total) AS total_revenue
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c ON cust.city_id = c.city_id
WHERE s.sale_date BETWEEN '2023-10-01' AND '2023-12-31'
GROUP BY c.city_name
ORDER BY total_revenue DESC;


-- ====================================================================
-- Question 3: Sales Volume by Product
-- Computes the total units sold for each coffee product.
-- Since total price matches single order values, COUNT reflects total units.
-- ====================================================================
SELECT 
    p.product_name,
    COUNT(s.sale_id) AS units_sold
FROM sales s
JOIN products p ON s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY units_sold DESC;


-- ====================================================================
-- Question 4: Average Sales per Customer by City
-- Calculates total revenue, unique customer counts, and the average 
-- lifetime spending amount per customer across different cities.
-- ====================================================================
SELECT 
    c.city_name,
    SUM(s.total) AS total_revenue,
    COUNT(DISTINCT s.customer_id) AS unique_customers,
    ROUND(SUM(s.total) / COUNT(DISTINCT s.customer_id), 2) AS avg_sales_per_customer
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c ON cust.city_id = c.city_id
GROUP BY c.city_name
ORDER BY total_revenue DESC;


-- ====================================================================
-- Question 5: Current Customers vs. Estimated Coffee Consumers
-- Implements a CTE to find the estimated target consumer size vs. 
-- actual registered customers currently captured in our sales database.
-- ====================================================================
WITH city_coffee_consumers AS (
    SELECT 
        city_id,
        city_name,
        ROUND((population * 0.25) / 1000000.0, 2) AS estimated_consumers_millions
    FROM city
)
SELECT 
    ccc.city_name,
    ccc.estimated_consumers_millions,
    COUNT(DISTINCT s.customer_id) AS unique_customers
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city_coffee_consumers ccc ON cust.city_id = ccc.city_id
GROUP BY ccc.city_name, ccc.estimated_consumers_millions
ORDER BY unique_customers DESC;


-- ====================================================================
-- Question 6: Top 3 Products per City
-- Utilizes the DENSE_RANK() window function to identify the top 3 best-selling
-- products based on order volumes within every unique city.
-- ====================================================================
WITH ranked_products AS (
    SELECT 
        c.city_name,
        p.product_name,
        COUNT(s.sale_id) AS units_sold,
        DENSE_RANK() OVER(PARTITION BY c.city_name ORDER BY COUNT(s.sale_id) DESC) as rank
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    JOIN customers cust ON s.customer_id = cust.customer_id
    JOIN city c ON cust.city_id = c.city_id
    GROUP BY c.city_name, p.product_name
)
SELECT 
    city_name,
    product_name,
    units_sold
FROM ranked_products
WHERE rank <= 3
ORDER BY city_name, rank;


-- ====================================================================
-- Question 7: Unique Customers per City
-- Counts the precise number of unique customers who made at least 
-- one coffee transaction within their respective city.
-- ====================================================================
SELECT 
    c.city_name,
    COUNT(DISTINCT s.customer_id) AS unique_customer_count
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c ON cust.city_id = c.city_id
GROUP BY c.city_name
ORDER BY unique_customer_count DESC;


-- ====================================================================
-- Question 8: Average Sale vs. Average Rent per Customer
-- Evaluates real-estate cost efficiency per customer by dividing the monthly
-- estimated location rent by the number of active city customers.
-- ====================================================================
SELECT 
    c.city_name,
    ROUND(SUM(s.total) / COUNT(DISTINCT s.customer_id), 2) AS avg_sale_per_customer,
    ROUND(c.estimated_rent / COUNT(DISTINCT s.customer_id), 2) AS avg_rent_per_customer
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c ON cust.city_id = c.city_id
GROUP BY c.city_name, c.estimated_rent
ORDER BY avg_sale_per_customer DESC;


-- ====================================================================
-- Question 9: Month-on-Month Sales Growth
-- Applies the LAG() window function to calculate month-on-month percentage 
-- sales variations for each city, omitting the initial baseline months.
-- ====================================================================
WITH monthly_sales AS (
    SELECT 
        c.city_name,
        EXTRACT(YEAR FROM s.sale_date) AS year,
        EXTRACT(MONTH FROM s.sale_date) AS month,
        SUM(s.total) AS total_sales
    FROM sales s
    JOIN customers cust ON s.customer_id = cust.customer_id
    JOIN city c ON cust.city_id = c.city_id
    GROUP BY c.city_name, EXTRACT(YEAR FROM s.sale_date), EXTRACT(MONTH FROM s.sale_date)
),
lagged_sales AS (
    SELECT 
        city_name,
        year,
        month,
        total_sales,
        LAG(total_sales) OVER (PARTITION BY city_name ORDER BY year, month) AS prev_month_sales
    FROM monthly_sales
)
SELECT 
    city_name,
    year,
    month,
    total_sales,
    prev_month_sales,
    ROUND(((total_sales - prev_month_sales) / prev_month_sales) * 100, 2) AS mom_growth_percentage
FROM lagged_sales
WHERE prev_month_sales IS NOT NULL
ORDER BY city_name, year, month;


-- ====================================================================
-- Question 10: Market Potential Summary
-- Assembles a consolidated overview table containing all strategic metrics 
-- needed to justify expansion into new markets.
-- ====================================================================
SELECT 
    c.city_name,
    SUM(s.total) AS total_revenue,
    c.estimated_rent,
    COUNT(DISTINCT s.customer_id) AS total_customers,
    ROUND((c.population * 0.25) / 1000000.0, 2) AS estimated_consumers_millions,
    ROUND(SUM(s.total) / COUNT(DISTINCT s.customer_id), 2) AS avg_sale_per_customer,
    ROUND(c.estimated_rent / COUNT(DISTINCT s.customer_id), 2) AS avg_rent_per_customer
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c ON cust.city_id = c.city_id
GROUP BY c.city_name, c.estimated_rent, c.population
ORDER BY total_revenue DESC;

--=====================Bonus Questions=================================================
-- Bonus Q1: Average Product Rating per City
SELECT c.city_name, ROUND(AVG(s.rating), 2) AS average_customer_rating
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c ON cust.city_id = c.city_id
GROUP BY c.city_name
ORDER BY average_customer_rating DESC;

-- Bonus Q2: Top 5 VIP Customers
SELECT cust.customer_id, cust.customer_name, c.city_name, SUM(s.total) AS total_spent
FROM sales s
JOIN customers cust ON s.customer_id = cust.customer_id
JOIN city c ON cust.city_id = c.city_id
GROUP BY cust.customer_id, cust.customer_name, c.city_name
ORDER BY total_spent DESC
LIMIT 5;

-- Bonus Q3: Monthly Revenue Seasonality
SELECT EXTRACT(MONTH FROM sale_date) AS sales_month, SUM(total) AS overall_revenue
FROM sales
GROUP BY EXTRACT(MONTH FROM sale_date)
ORDER BY overall_revenue DESC;