



############################################################################
   SECTION A - SALES & GROWTH
############################################################################


-- =============================================================================
-- Q1. What is the monthly revenue, order count, AOV and month-over-month growth?
-- =============================================================================

WITH monthly_sales AS (
    SELECT
        purchase_month,
        COUNT(*) AS orders,
        SUM(items_value) AS revenue
    FROM gold.fact_orders
    WHERE is_valid_sale = 1
      AND purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY purchase_month
)

SELECT
    purchase_month,
    orders,
    revenue,
    ROUND(revenue / NULLIF(orders, 0), 2) AS avg_order_value,
    ROUND(
        100.0 * (
            revenue - LAG(revenue) OVER (ORDER BY purchase_month)
        ) / NULLIF(
            LAG(revenue) OVER (ORDER BY purchase_month),
            0
        ),
        1
    ) AS mom_growth_pct
FROM monthly_sales
ORDER BY purchase_month;

GO


-- =============================================================================
-- Q2. Q2. How does each month compare with the same month last year (YoY)?
-- =============================================================================

WITH monthly_revenue AS (
    SELECT
        purchase_month,
        SUM(items_value) AS revenue
    FROM gold.fact_orders
    WHERE is_valid_sale = 1
    GROUP BY purchase_month
)

SELECT
    current_month.purchase_month,
    current_month.revenue,
    previous_year.revenue AS revenue_same_month_last_year,
    ROUND( 100.0 * ( current_month.revenue - previous_year.revenue ) / NULLIF(previous_year.revenue, 0) , 1 ) AS yoy_growth_pct
FROM monthly_revenue AS current_month
JOIN monthly_revenue AS previous_year
    ON previous_year.purchase_month =
       DATEADD(YEAR, -1, current_month.purchase_month)
WHERE current_month.purchase_month <= '2018-08-01'
ORDER BY current_month.purchase_month;

GO


-- =============================================================================
-- Q3. What share of orders end in each status (order funnel)?
-- =============================================================================

SELECT
    order_status,
    COUNT(*) AS orders,
    ROUND( 100.0 * COUNT(*) / SUM(COUNT(*)) OVER () , 2 ) AS pct_of_orders
FROM silver.orders
GROUP BY order_status
ORDER BY orders DESC;

GO



-- =============================================================================
-- Q4. On which weekday and at what hour do customers order?
-- =============================================================================

-- 4a. Orders and revenue by weekday
SELECT
    d.day_of_week,
    d.day_name,
    COUNT(*) AS orders,
    SUM(fo.items_value) AS revenue
FROM gold.fact_orders AS fo
JOIN gold.dim_date AS d
    ON d.calendar_date = fo.purchase_date
WHERE fo.is_valid_sale = 1
GROUP BY d.day_of_week, d.day_name
ORDER BY d.day_of_week;

-- 4b. Orders by hour
SELECT
    DATEPART(HOUR, order_purchase_timestamp) AS hour_of_day,
    COUNT(*) AS orders
FROM gold.fact_orders
WHERE is_valid_sale = 1
GROUP BY DATEPART(HOUR, order_purchase_timestamp)
ORDER BY hour_of_day;

GO

-- =============================================================================
-- Q5. Which 10 days had the most orders (sale events)?
-- =============================================================================

SELECT TOP 10
    purchase_date,
    COUNT(*) AS orders,
    SUM(items_value) AS revenue
FROM gold.fact_orders
WHERE is_valid_sale = 1
GROUP BY purchase_date
ORDER BY orders DESC;

GO






############################################################################
   SECTION B - PRODUCTS & CATEGORIES
############################################################################



-- =============================================================================
-- Q6. Which categories make up 80% of revenue (Pareto)?
-- =============================================================================

WITH category_revenue AS (
    SELECT
        p.product_category_name_eng AS category,
        COUNT(DISTINCT f.order_id) AS orders,
        SUM(f.price) AS revenue
    FROM gold.fact_order_items AS f
    JOIN gold.dim_products AS p
        ON p.product_key = f.product_key
    WHERE f.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY p.product_category_name_eng
)

SELECT
    category,
    orders,
    revenue,
    ROUND( 100.0 * revenue / SUM(revenue) OVER (), 2 ) AS share_pct,
    ROUND( 100.0 * SUM(revenue) OVER ( ORDER BY revenue DESC  ROWS UNBOUNDED PRECEDING ) / SUM(revenue) OVER () , 2 ) AS cumulative_pct
FROM category_revenue
ORDER BY revenue DESC;

GO


-- =============================================================================
-- Q7. How do the top 20 categories compare on price, freight burden and reviews?
-- =============================================================================

SELECT TOP 20
    p.product_category_name_eng AS category,
    COUNT(DISTINCT f.order_id) AS orders,
    SUM(f.price) AS revenue,
    ROUND(AVG(f.price), 2) AS avg_item_price,
    ROUND( 100.0 * SUM(f.freight_value) / NULLIF(SUM(f.price), 0) , 1 ) AS freight_pct_of_price,
    ROUND( AVG(CAST(fo.review_score AS FLOAT)) , 2 ) AS avg_review
FROM gold.fact_order_items AS f
JOIN gold.dim_products AS p
    ON p.product_key = f.product_key
JOIN gold.fact_orders AS fo
    ON fo.order_id = f.order_id
WHERE fo.is_valid_sale = 1
GROUP BY p.product_category_name_eng
ORDER BY revenue DESC;

GO


-- =============================================================================
-- Q8. Which categories (100+ orders) have the lowest review scores and how do their late-delivery rates compare?
-- =============================================================================

SELECT TOP 10
    p.product_category_name_eng AS category,
    COUNT(DISTINCT f.order_id) AS orders,
    ROUND( AVG(CAST(fo.review_score AS FLOAT)) , 2 ) AS avg_review,
    ROUND( 100.0 * AVG(CAST(fo.is_late AS FLOAT)) , 1 ) AS late_pct
FROM gold.fact_order_items AS f
JOIN gold.dim_products AS p
    ON p.product_key = f.product_key
JOIN gold.fact_orders AS fo
    ON fo.order_id = f.order_id
WHERE fo.is_valid_sale = 1
GROUP BY p.product_category_name_eng
HAVING COUNT(DISTINCT f.order_id) >= 100
ORDER BY avg_review ASC;

GO



-- =============================================================================
-- Q9. How do order volume, freight burden, reviews and lateness change by order-value band? (relevant to low-price, value-shopper markets).   
-- =============================================================================

SELECT
    b.price_band,
    COUNT(*) AS orders,
    ROUND( 100.0 * COUNT(*) / SUM(COUNT(*)) OVER () , 1 ) AS pct_of_orders,
    ROUND( 100.0 * SUM(fo.freight_value) / NULLIF(SUM(fo.items_value), 0) , 1 ) AS freight_pct_of_price,
    ROUND( AVG(CAST(fo.review_score AS FLOAT)) , 2 ) AS avg_review,
    ROUND( 100.0 * AVG(CAST(fo.is_late AS FLOAT)) , 1 ) AS late_pct
FROM gold.fact_orders AS fo
CROSS APPLY (
    SELECT
        CASE
            WHEN fo.items_value < 50  THEN '1. Under 50'
            WHEN fo.items_value < 100 THEN '2. 50-99'
            WHEN fo.items_value < 200 THEN '3. 100-199'
            WHEN fo.items_value < 500 THEN '4. 200-499'
            ELSE '5. 500+'
        END AS price_band
) AS b
WHERE fo.is_valid_sale = 1
GROUP BY b.price_band
ORDER BY b.price_band;

GO


  
############################################################################
   SECTION C - DELIVERY PERFORMANCE
############################################################################



-- =============================================================================
-- Q10. What are the overall delivery KPIs?
-- =============================================================================

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(AVG(CAST(delivery_days AS FLOAT)), 1) AS avg_delivery_days,
    ROUND(AVG(CAST(delay_days AS FLOAT)), 1) AS avg_delay_days,
    ROUND(100.0 * AVG(CAST(is_late AS FLOAT)), 2) AS late_pct
FROM gold.fact_orders
WHERE is_delivered = 1;

GO


  
-- =============================================================================
-- Q11. Which customer states have the highest late-delivery rate (100+ orders)?
-- =============================================================================

SELECT
    customer_state,
    COUNT(*) AS delivered_orders,
    ROUND( AVG(CAST(delivery_days AS FLOAT)) , 1 ) AS avg_delivery_days,
    ROUND( 100.0 * AVG(CAST(is_late AS FLOAT)) , 1 ) AS late_pct,
    ROUND( AVG(CAST(review_score AS FLOAT)) , 2) AS avg_review
FROM gold.fact_orders
WHERE is_delivered = 1
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY late_pct DESC;

GO



-- =============================================================================
-- Q12. How do review scores vary by delivery delay?
-- =============================================================================

SELECT
    b.delay_bucket,
    COUNT(*) AS orders,
    ROUND( AVG(CAST(fo.review_score AS FLOAT)) , 2 ) AS avg_review,
    ROUND( 100.0 * AVG(
            CASE
                WHEN fo.review_score <= 2 THEN 1.0
                ELSE 0
            END
        ) , 1 ) AS pct_1_or_2_star
  
FROM gold.fact_orders AS fo
CROSS APPLY (
    SELECT
        CASE
            WHEN fo.delay_days < 0 THEN '1. Early'
            WHEN fo.delay_days = 0 THEN '2. On estimated date'
            WHEN fo.delay_days <= 3 THEN '3. Late 1-3 days'
            WHEN fo.delay_days <= 7 THEN '4. Late 4-7 days'
            WHEN fo.delay_days <= 14 THEN '5. Late 8-14 days'
            ELSE '6. Late 15+ days'
        END AS delay_bucket
) AS b
WHERE fo.is_delivered = 1
  AND fo.review_score IS NOT NULL
GROUP BY b.delay_bucket
ORDER BY b.delay_bucket;

GO



-- =============================================================================
-- Q13. By state, how many days of buffer does the promised delivery date include?
-- =============================================================================

SELECT
    customer_state,
    COUNT(*) AS delivered_orders,
    ROUND( AVG( CAST( DATEDIFF( DAY , order_purchase_timestamp , order_estimated_delivery_date ) AS FLOAT ) ) , 1 ) AS avg_promised_days,
    ROUND( AVG(CAST(delivery_days AS FLOAT)) , 1) AS avg_actual_days,
    ROUND( AVG( CAST( DATEDIFF( DAY, order_purchase_timestamp, order_estimated_delivery_date ) AS FLOAT ) ) - AVG(CAST(delivery_days AS FLOAT)) , 1 ) AS avg_buffer_days
FROM gold.fact_orders
WHERE is_delivered = 1
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY avg_buffer_days;

GO



-- =============================================================================
-- Q14. Is the late-delivery rate getting better or worse over time?
-- =============================================================================

SELECT
    purchase_month,
    COUNT(*) AS delivered_orders,
    ROUND( 100.0 * AVG(CAST(is_late AS FLOAT)) , 1 ) AS late_pct,
    ROUND( AVG(CAST(delivery_days AS FLOAT)) , 1 ) AS avg_delivery_days
FROM gold.fact_orders
WHERE is_delivered = 1
  AND purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
GROUP BY purchase_month
ORDER BY purchase_month;

GO



-- =============================================================================
-- Q15. How do same-state and cross-state items differ in delivery time , freight burden and lateness?.
-- =============================================================================

SELECT
    route.route_type,
    COUNT(*) AS items,
    ROUND( 100.0 * COUNT(*) / SUM(COUNT(*)) OVER () , 1 ) AS pct_of_items,
    ROUND(
        AVG(CAST(f.delivery_days AS FLOAT)),
        1
    ) AS avg_delivery_days,
    ROUND(
        100.0 * SUM(f.freight_value)
        / NULLIF(SUM(f.price), 0),
        1
    ) AS freight_pct_of_price,
    ROUND(
        100.0 * AVG(
            CASE
                WHEN f.delivery_delay_days > 0 THEN 1.0
                ELSE 0
            END
        ),
        1
    ) AS late_pct
FROM gold.fact_order_items AS f
JOIN gold.dim_customers AS c
    ON c.customer_key = f.customer_key
JOIN gold.dim_sellers AS s
    ON s.seller_key = f.seller_key
CROSS APPLY (
    SELECT
        CASE
            WHEN c.customer_state = s.seller_state
                THEN 'Same state'
            ELSE 'Cross state'
        END AS route_type
) AS route
WHERE f.order_status = 'delivered'
  AND f.delivery_days IS NOT NULL
GROUP BY route.route_type
ORDER BY route.route_type;

GO


############################################################################
   SECTION D - LOGISTICS COST
############################################################################



-- =============================================================================
-- Q16. Which customer states pay the most freight relative to product price?.
-- =============================================================================

SELECT
    customer_state,
    COUNT(*) AS orders,
    ROUND(AVG(freight_value), 2) AS avg_freight,
    ROUND(
        100.0 * SUM(freight_value)
        / NULLIF(SUM(items_value), 0),
        1
    ) AS freight_pct_of_price
FROM gold.fact_orders
WHERE is_valid_sale = 1
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY freight_pct_of_price DESC;

GO



-- =============================================================================
-- Q17. Which categories (200+ items) carry the highest freight burden?.
-- =============================================================================

SELECT TOP 15
    p.product_category_name_eng AS category,
    COUNT(*) AS items_sold,
    ROUND(AVG(f.price), 2) AS avg_price,
    ROUND(AVG(f.freight_value), 2) AS avg_freight,
    ROUND(
        100.0 * SUM(f.freight_value)
        / NULLIF(SUM(f.price), 0),
        1
    ) AS freight_pct_of_price
FROM gold.fact_order_items AS f
JOIN gold.dim_products AS p
    ON p.product_key = f.product_key
WHERE f.order_status NOT IN ('canceled', 'unavailable')
GROUP BY p.product_category_name_eng
HAVING COUNT(*) >= 200
ORDER BY freight_pct_of_price DESC;

GO



############################################################################
   SECTION E - SELLERS
############################################################################ 


-- =============================================================================
-- Q18. Seller scorecard: top 50 sellers (30+ orders) by revenue.
-- =============================================================================

WITH seller_performance AS (
    SELECT
        f.seller_key,
        COUNT(DISTINCT f.order_id) AS orders,
        SUM(f.price) AS revenue,
        ROUND(
            AVG(CAST(fo.review_score AS FLOAT)),
            2
        ) AS avg_review,
        ROUND(
            100.0 * AVG(CAST(fo.is_late AS FLOAT)),
            1
        ) AS late_pct
    FROM gold.fact_order_items AS f
    JOIN gold.fact_orders AS fo
        ON fo.order_id = f.order_id
    WHERE fo.is_valid_sale = 1
    GROUP BY f.seller_key
    HAVING COUNT(DISTINCT f.order_id) >= 30
)

SELECT TOP 50
    RANK() OVER (ORDER BY revenue DESC) AS revenue_rank,
    d.seller_id,
    d.seller_state,
    s.orders,
    s.revenue,
    s.avg_review,
    s.late_pct
FROM seller_performance AS s
JOIN gold.dim_sellers AS d
    ON d.seller_key = s.seller_key
ORDER BY revenue_rank;

GO



  
-- =============================================================================
-- Q19. How concentrated is revenue among sellers (by decile)?
-- =============================================================================

WITH seller_revenue AS (
    SELECT
        seller_key,
        SUM(price) AS revenue
    FROM gold.fact_order_items
    WHERE order_status NOT IN ('canceled', 'unavailable')
    GROUP BY seller_key
),
seller_deciles AS (
    SELECT
        revenue,
        NTILE(10) OVER (ORDER BY revenue DESC) AS decile
    FROM seller_revenue
)

SELECT
    decile,
    COUNT(*) AS sellers,
    SUM(revenue) AS revenue,
    ROUND(
        100.0 * SUM(revenue)
        / SUM(SUM(revenue)) OVER (),
        1
    ) AS share_of_revenue_pct
FROM seller_deciles
GROUP BY decile
ORDER BY decile;

GO



-- =============================================================================
-- Q20. Which high-revenue sellers are "at risk" (late % or review problems)?.
-- =============================================================================

WITH seller_performance AS (
    SELECT
        f.seller_key,
        COUNT(DISTINCT f.order_id) AS orders,
        SUM(f.price) AS revenue,
        ROUND(
            AVG(CAST(fo.review_score AS FLOAT)),
            2
        ) AS avg_review,
        ROUND(
            100.0 * AVG(CAST(fo.is_late AS FLOAT)),
            1
        ) AS late_pct
    FROM gold.fact_order_items AS f
    JOIN gold.fact_orders AS fo
        ON fo.order_id = f.order_id
    WHERE fo.is_valid_sale = 1
    GROUP BY f.seller_key
    HAVING COUNT(DISTINCT f.order_id) >= 50
)

SELECT
    d.seller_id,
    d.seller_state,
    s.orders,
    s.revenue,
    s.avg_review,
    s.late_pct
FROM seller_performance AS s
JOIN gold.dim_sellers AS d
    ON d.seller_key = s.seller_key
WHERE s.late_pct > 15
   OR s.avg_review < 3.5
ORDER BY s.revenue DESC;

GO



-- =============================================================================
-- Q21. Where does seller supply sit compared with customer demand by state?
-- =============================================================================

WITH supply AS (
    SELECT
        seller_state AS state,
        COUNT(DISTINCT seller_id) AS sellers
    FROM gold.dim_sellers
    GROUP BY seller_state
),
demand AS (
    SELECT
        customer_state AS state,
        COUNT(DISTINCT customer_unique_id) AS customers
    FROM gold.dim_customers
    GROUP BY customer_state
)

SELECT
    COALESCE(d.state, s.state) AS state,
    s.sellers,
    d.customers,
    ROUND(
        100.0 * ISNULL(d.customers, 0)
        / NULLIF(SUM(d.customers) OVER (), 0),
        1
    ) AS demand_share_pct,
    ROUND(
        100.0 * ISNULL(s.sellers, 0)
        / NULLIF(SUM(s.sellers) OVER (), 0),
        1
    ) AS supply_share_pct
FROM demand AS d
FULL JOIN supply AS s
    ON s.state = d.state
ORDER BY demand_share_pct DESC;

GO





############################################################################
   SECTION F - CUSTOMERS & RETENTION
############################################################################ 

-- =============================================================================
-- Q22. What percentage of customers buy more than once?
-- =============================================================================

WITH customer_orders AS (
    SELECT
        customer_unique_id,
        COUNT(*) AS orders
    FROM gold.fact_orders
    WHERE is_valid_sale = 1
    GROUP BY customer_unique_id
)

SELECT
    COUNT(*) AS customers,
    SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(
        100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_pct
FROM customer_orders;

GO



  
-- =============================================================================
-- Q23. Customer segments (RFM-style): who is repeat, high-value, or lapsed?
-- =============================================================================

DECLARE @ref_date DATE =
(
    SELECT MAX(purchase_date)
    FROM gold.fact_orders
);

WITH customer_metrics AS (
    SELECT
        customer_unique_id,
        DATEDIFF(
            DAY,
            MAX(purchase_date),
            @ref_date
        ) AS recency_days,
        COUNT(*) AS frequency,
        SUM(items_value) AS monetary
    FROM gold.fact_orders
    WHERE is_valid_sale = 1
    GROUP BY customer_unique_id
),

customer_scores AS (
    SELECT
        *,
        NTILE(5) OVER (
            ORDER BY recency_days ASC
        ) AS r_score,
        NTILE(5) OVER (
            ORDER BY monetary ASC
        ) AS m_score
    FROM customer_metrics
),

customer_segments AS (
    SELECT
        *,
        CASE
            WHEN frequency >= 2 AND r_score >= 3
                THEN 'Loyal / Repeat'

            WHEN frequency >= 2
                THEN 'Repeat - Lapsing'

            WHEN m_score = 5 AND r_score >= 4
                THEN 'High-Value New'

            WHEN r_score <= 2
                THEN 'One-Time - Lapsed'

            ELSE 'One-Time - Recent'
        END AS segment
    FROM customer_scores
)

SELECT
    segment,
    COUNT(*) AS customers,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        1
    ) AS pct_of_customers,
    SUM(monetary) AS revenue,
    ROUND(
        AVG(monetary),
        2
    ) AS avg_spend
FROM customer_segments
GROUP BY segment
ORDER BY customers DESC;

GO




-- =============================================================================
-- Q24. Q24. Cohort retention: of customers who first bought in month X, what % are active 1, 2, 3... months later?
-- =============================================================================

WITH first_order AS (
    SELECT
        customer_unique_id,
        MIN(purchase_month) AS cohort_month
    FROM gold.fact_orders
    WHERE is_valid_sale = 1
    GROUP BY customer_unique_id
),

customer_activity AS (
    SELECT DISTINCT
        fo.customer_unique_id,
        f.cohort_month,
        DATEDIFF(
            MONTH,
            f.cohort_month,
            fo.purchase_month
        ) AS months_since
    FROM gold.fact_orders AS fo
    JOIN first_order AS f
        ON f.customer_unique_id = fo.customer_unique_id
    WHERE fo.is_valid_sale = 1
),

retention_counts AS (
    SELECT
        cohort_month,
        months_since,
        COUNT(*) AS active_customers
    FROM customer_activity
    GROUP BY cohort_month, months_since
)

SELECT
    cohort_month,
    months_since,
    active_customers,
    ROUND(
        100.0 * active_customers
        / FIRST_VALUE(active_customers) OVER (
            PARTITION BY cohort_month
            ORDER BY months_since
        ),
        2
    ) AS retention_pct
FROM retention_counts
WHERE months_since <= 6
  AND cohort_month BETWEEN '2017-01-01' AND '2018-02-01'
ORDER BY cohort_month, months_since;

GO



############################################################################
   SECTION G - PAYMENTS
############################################################################ 


-- =============================================================================
-- Q25. How is payment split by method (share of value, average ticket, installments)?
-- =============================================================================

SELECT
    payment_type,
    COUNT(DISTINCT order_id) AS orders,
    SUM(payment_value) AS total_value,
    ROUND(
        100.0 * SUM(payment_value)
        / NULLIF(SUM(SUM(payment_value)) OVER (), 0),
        1
    ) AS value_share_pct,
    ROUND(
        AVG(payment_value),
        2
    ) AS avg_payment,
    ROUND(
        AVG(CAST(payment_installments AS FLOAT)),
        1
    ) AS avg_installments
FROM gold.fact_payments
WHERE order_status NOT IN ('canceled', 'unavailable')
GROUP BY payment_type
ORDER BY total_value DESC;

GO




-- =============================================================================
-- Q26. Do customers use more instalments as the payment amount grows (credit card)?
-- =============================================================================

SELECT
    b.value_band,
    COUNT(*) AS payments,
    ROUND(
        AVG(CAST(p.payment_installments AS FLOAT)),
        1
    ) AS avg_installments,
    ROUND(
        100.0 * AVG(
            CASE
                WHEN p.payment_installments > 1 THEN 1.0
                ELSE 0
            END
        ),
        1
    ) AS pct_using_installments
FROM gold.fact_payments AS p
CROSS APPLY (
    SELECT
        CASE
            WHEN p.payment_value < 100  THEN '1. Under 100'
            WHEN p.payment_value < 300  THEN '2. 100-299'
            WHEN p.payment_value < 1000 THEN '3. 300-999'
            ELSE '4. 1000+'
        END AS value_band
) AS b
WHERE p.payment_type = 'credit_card'
  AND p.order_status NOT IN ('canceled', 'unavailable')
GROUP BY b.value_band
ORDER BY b.value_band;

GO



############################################################################
   SECTION H - EXPERIENCE & REVIEWS
############################################################################ 


-- =============================================================================
-- Q27. Do orders with items from several sellers do worse than single-seller orders?
-- =============================================================================

SELECT
    order_type,
    COUNT(*) AS orders,
    ROUND(
        AVG(CAST(fo.delivery_days AS FLOAT)),
        1
    ) AS avg_delivery_days,
    ROUND(
        100.0 * AVG(CAST(fo.is_late AS FLOAT)),
        1
    ) AS late_pct,
    ROUND(
        AVG(CAST(fo.review_score AS FLOAT)),
        2
    ) AS avg_review
FROM gold.fact_orders AS fo
CROSS APPLY (
    SELECT
        CASE
            WHEN fo.seller_count > 1
                THEN 'Multi-seller'
            ELSE 'Single seller'
        END AS order_type
) AS t
WHERE fo.is_delivered = 1
GROUP BY order_type;

GO



-- =============================================================================
-- Q28. What is the review score distribution, and how long do customers take to answer the review survey?
-- =============================================================================

SELECT
    review_score,
    COUNT(*) AS reviews,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        1
    ) AS pct_of_reviews,
    ROUND(
        AVG(CAST(review_response_days AS FLOAT)),
        1
    ) AS avg_days_to_answer_survey
FROM gold.fact_reviews
GROUP BY review_score
ORDER BY review_score;

GO



-- =============================================================================
-- END OF BUSINESS ANALYSIS
-- =============================================================================
-- The analysis covers sales, products, delivery, logistics, sellers,
-- customers, payments and customer experience.
-- Results are used for dashboard development and business recommendations.
-- =============================================================================
