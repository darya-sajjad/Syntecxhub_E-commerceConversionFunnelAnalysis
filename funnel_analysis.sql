-- Overall Funnel Analysis

-- analyzing the conversion funnel.
WITH SessionMilestones AS (
    SELECT 
        Session_ID,
        MAX(CASE WHEN Event = 'Add to Cart' THEN 1 ELSE 0 END) AS Reached_AddToCart,
        MAX(CASE WHEN Event = 'Checkout'    THEN 1 ELSE 0 END) AS Reached_Checkout,
        MAX(CASE WHEN Event = 'Purchase'    THEN 1 ELSE 0 END) AS Reached_Purchase
    FROM ecommerce
    GROUP BY Session_ID
)
SELECT 0 AS Stage_Order, 'Browse' AS Stage, COUNT(*) AS Sessions 
FROM SessionMilestones

UNION ALL

SELECT 1 AS Stage_Order, 'Add to Cart' AS Stage, COUNT(*) AS Sessions 
FROM SessionMilestones
WHERE Reached_AddToCart = 1 OR Reached_Checkout = 1 OR Reached_Purchase = 1

UNION ALL

SELECT 2 AS Stage_Order, 'Checkout' AS Stage, COUNT(*) AS Sessions 
FROM SessionMilestones
WHERE Reached_Checkout = 1 OR Reached_Purchase = 1

UNION ALL

SELECT 3 AS Stage_Order, 'Purchase' AS Stage, COUNT(*) AS Sessions 
FROM SessionMilestones
WHERE Reached_Purchase = 1
ORDER BY Stage_Order;

-- Calculate conversion and drop-off rates
WITH SessionMilestones AS (
    SELECT 
        Session_ID,
        MAX(CASE WHEN Event = 'Add to Cart' THEN 1 ELSE 0 END) AS Reached_AddToCart,
        MAX(CASE WHEN Event = 'Checkout'    THEN 1 ELSE 0 END) AS Reached_Checkout,
        MAX(CASE WHEN Event = 'Purchase'    THEN 1 ELSE 0 END) AS Reached_Purchase
    FROM ecommerce
    GROUP BY Session_ID
),
FunnelCounts AS (
    SELECT 0 AS Stage_Order, 'Browse' AS Stage, COUNT(*) AS Sessions FROM SessionMilestones
    UNION ALL
    SELECT 1 AS Stage_Order, 'Add to Cart' AS Stage, COUNT(*) AS Sessions FROM SessionMilestones
    WHERE Reached_AddToCart = 1 OR Reached_Checkout = 1 OR Reached_Purchase = 1
    UNION ALL
    SELECT 2 AS Stage_Order, 'Checkout' AS Stage, COUNT(*) AS Sessions FROM SessionMilestones
    WHERE Reached_Checkout = 1 OR Reached_Purchase = 1
    UNION ALL
    SELECT 3 AS Stage_Order, 'Purchase' AS Stage, COUNT(*) AS Sessions FROM SessionMilestones
    WHERE Reached_Purchase = 1
),
BrowseTotal AS (
    SELECT Sessions FROM FunnelCounts WHERE Stage_Order = 0
)
SELECT 
    f.Stage_Order,
    f.Stage,
    f.Sessions,
    ROUND(CAST(f.Sessions AS FLOAT) / b.Sessions * 100, 2) AS Conversion_Rate,
    ROUND(
        ISNULL(
            (1.0 - (CAST(f.Sessions AS FLOAT) / NULLIF(LAG(f.Sessions) OVER (ORDER BY f.Stage_Order), 0))) * 100, 
            0
        ), 2
    ) AS Drop_Off_Rate
FROM FunnelCounts f
CROSS JOIN BrowseTotal b
ORDER BY f.Stage_Order;

-- Calculate total revenue, average order value, and total number of orders
WITH PurchaseSessions AS (
    SELECT 
        Session_ID,
        MAX(Revenue) AS Session_Revenue
    FROM ecommerce
    GROUP BY Session_ID
    HAVING MAX(CASE WHEN Event = 'Purchase' THEN 1 ELSE 0 END) = 1
)
SELECT 
    ROUND(SUM(Session_Revenue), 2) AS Total_Revenue,
    ROUND(AVG(Session_Revenue), 2) AS Average_Order_Value,
    COUNT(*) AS Total_Orders
FROM PurchaseSessions;

-- Funnel Analysis by Channel

-- calculate the number of sessions that reached each funnel stage (Add to Cart, Checkout, Purchase) for each channel
WITH SessionSummary AS (
    SELECT 
        Session_ID,
        MIN(Channel) AS Channel,
        MAX(Revenue) AS Revenue,
        -- Check if the session hit each funnel stage milestone (1 = Yes, 0 = No)
        MAX(CASE WHEN Event = 'Add to Cart' THEN 1 ELSE 0 END) AS Reached_AddToCart,
        MAX(CASE WHEN Event = 'Checkout'    THEN 1 ELSE 0 END) AS Reached_Checkout,
        MAX(CASE WHEN Event = 'Purchase'    THEN 1 ELSE 0 END) AS Reached_Purchase
    FROM ecommerce
    GROUP BY Session_ID
),
ChannelFunnelStages AS (
    SELECT 
        Channel,
        COUNT(*) AS Total_Sessions,
        COUNT(*) AS Browse_Sessions,
        100.00 AS Browse_Rate,

        SUM(CASE WHEN Reached_AddToCart = 1 OR Reached_Checkout = 1 OR Reached_Purchase = 1 THEN 1 ELSE 0 END) AS AddToCart_Sessions,
        ROUND(SUM(CASE WHEN Reached_AddToCart = 1 OR Reached_Checkout = 1 OR Reached_Purchase = 1 THEN 1.0 ELSE 0.0 END) / COUNT(*) * 100, 2) AS AddToCart_Rate,

        SUM(CASE WHEN Reached_Checkout = 1 OR Reached_Purchase = 1 THEN 1 ELSE 0 END) AS Checkout_Sessions,
        ROUND(SUM(CASE WHEN Reached_Checkout = 1 OR Reached_Purchase = 1 THEN 1.0 ELSE 0.0 END) / COUNT(*) * 100, 2) AS Checkout_Rate,

        SUM(CASE WHEN Reached_Purchase = 1 THEN 1 ELSE 0 END) AS Purchase_Sessions,
        ROUND(SUM(CASE WHEN Reached_Purchase = 1 THEN 1.0 ELSE 0.0 END) / COUNT(*) * 100, 2) AS Conversion_Rate,

        SUM(CASE WHEN Reached_Purchase = 1 THEN Revenue ELSE 0 END) AS Total_Revenue
    FROM SessionSummary
    GROUP BY Channel
)
SELECT 
    Channel,
    Total_Sessions,
    Browse_Sessions,
    Browse_Rate,
    AddToCart_Sessions,
    AddToCart_Rate,
    Checkout_Sessions,
    Checkout_Rate,
    Purchase_Sessions,
    Conversion_Rate,
    ROUND(Total_Revenue, 2) AS Total_Revenue,
    ROUND(ISNULL(Total_Revenue / NULLIF(Purchase_Sessions, 0), 0), 2) AS AOV
FROM ChannelFunnelStages
ORDER BY Total_Revenue DESC;

-- Funnel Analysis by Channel

-- calculate the number of sessions that reached each funnel stage (Add to Cart, Checkout, Purchase) for each region
WITH RawSessionSummary AS (
    SELECT 
        Session_ID,
        MIN(Region) AS Region,
        MAX(Revenue) AS Revenue,
        -- Calculate session duration anchors
        MIN(Event_Time) AS Session_Start,
        MAX(Event_Time) AS Session_End,
        -- Check if the session hit each funnel stage milestone (1 = Yes, 0 = No)
        MAX(CASE WHEN Event = 'Add to Cart' THEN 1 ELSE 0 END) AS Reached_AddToCart,
        MAX(CASE WHEN Event = 'Checkout'    THEN 1 ELSE 0 END) AS Reached_Checkout,
        MAX(CASE WHEN Event = 'Purchase'    THEN 1 ELSE 0 END) AS Reached_Purchase
    FROM ecommerce
    GROUP BY Session_ID
),
RegionalAggregations AS (
    SELECT 
        Region,
        COUNT(*) AS Total_Sessions,
        SUM(CASE WHEN Reached_Purchase = 1 THEN Revenue ELSE 0 END) AS Total_Revenue,
        AVG(DATEDIFF(SECOND, Session_Start, Session_End) / 60.0) AS Average_Session_Duration_Min,

        SUM(CASE WHEN Reached_Purchase = 1 THEN 1 ELSE 0 END) AS Converted_Sessions,

        COUNT(*) AS Browse_Sessions,
        SUM(CASE WHEN Reached_AddToCart = 1 OR Reached_Checkout = 1 OR Reached_Purchase = 1 THEN 1 ELSE 0 END) AS AddToCart_Sessions,
        SUM(CASE WHEN Reached_Checkout = 1 OR Reached_Purchase = 1 THEN 1 ELSE 0 END) AS Checkout_Sessions,
        SUM(CASE WHEN Reached_Purchase = 1 THEN 1 ELSE 0 END) AS Purchase_Sessions
    FROM RawSessionSummary
    GROUP BY Region
)
SELECT 
    Region,
    Total_Sessions,
    ROUND(Total_Revenue, 2) AS Total_Revenue,
    ROUND(Average_Session_Duration_Min, 1) AS Avg_Session_Duration_Min,
    Converted_Sessions,

    ROUND(CAST(Converted_Sessions AS FLOAT) / NULLIF(Total_Sessions, 0) * 100, 2) AS Conversion_Rate,

    ROUND(ISNULL(Total_Revenue / NULLIF(Converted_Sessions, 0), 0), 2) AS AOV,
    
    Browse_Sessions,
    AddToCart_Sessions,
    Checkout_Sessions,
    Purchase_Sessions
FROM RegionalAggregations
ORDER BY Total_Revenue DESC;

-- Funnel Analysis by Device Type

-- calculate the number of sessions, total revenue, average session duration, and conversion rate for each device type
WITH DeviceBaseMetrics AS (
    SELECT 
        Session_ID,
        MIN(Device) AS Device,
        MAX(Revenue) AS Revenue,
        MIN(Event_Time) AS Session_Start,
        MAX(Event_Time) AS Session_End,
        MAX(CASE WHEN Event = 'Purchase' THEN 1 ELSE 0 END) AS Is_Purchase
    FROM ecommerce
    GROUP BY Session_ID
),
DeviceAggregations AS (
    SELECT 
        Device,
        COUNT(*) AS Total_Sessions,
        SUM(CASE WHEN Is_Purchase = 1 THEN Revenue ELSE 0 END) AS Total_Revenue,
        AVG(DATEDIFF(SECOND, Session_Start, Session_End) / 60.0) AS Avg_Session_Duration_Min,
        SUM(Is_Purchase) AS Purchases
    FROM DeviceBaseMetrics
    GROUP BY Device
)
SELECT 
    Device,
    Total_Sessions,
    ROUND(Total_Revenue, 2) AS Revenue,
    ROUND(Avg_Session_Duration_Min, 1) AS Avg_Session_Duration_Min,
    Purchases,

    ROUND(CAST(Purchases AS FLOAT) / NULLIF(Total_Sessions, 0) * 100, 2) AS Conversion_Rate,

    ROUND(ISNULL(Total_Revenue / NULLIF(Purchases, 0), 0), 2) AS AOV
FROM DeviceAggregations
ORDER BY Total_Revenue DESC;

-- Funnel Analysis by Product Category

-- calculate the number of sessions, total revenue, average order value, and conversion rate for each product category
WITH ProductBaseMetrics AS (
    SELECT 
        Session_ID,
        MIN(Product_Category) AS Product_Category,
        MAX(Revenue) AS Revenue,
        MAX(CASE WHEN Event = 'Purchase' THEN 1 ELSE 0 END) AS Is_Purchase
    FROM ecommerce
    GROUP BY Session_ID
),
ProductAggregations AS (
    SELECT 
        Product_Category,
        COUNT(*) AS Total_Sessions,
        SUM(CASE WHEN Is_Purchase = 1 THEN Revenue ELSE 0 END) AS Total_Revenue,
        SUM(Is_Purchase) AS Purchases
    FROM ProductBaseMetrics
    GROUP BY Product_Category
)
SELECT 
    Product_Category,
    Total_Sessions,
    ROUND(Total_Revenue, 2) AS Revenue,
    Purchases,

    ROUND(CAST(Purchases AS FLOAT) / NULLIF(Total_Sessions, 0) * 100, 2) AS Conversion_Rate,

    ROUND(ISNULL(Total_Revenue / NULLIF(Purchases, 0), 0), 2) AS AOV,

    ROUND(Total_Revenue / NULLIF(Total_Sessions, 0), 2) AS Revenue_Per_Session
FROM ProductAggregations
ORDER BY Total_Revenue DESC;
