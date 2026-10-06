# Funnel Stage Definition

The conversion funnel tracks the user journey through the application across sequential interaction milestones. Stages are ranked chronologically from traffic acquisition to conversion:

### 1. Browse:
User views a product page or category layout.
### 2. Add To Cart:
User selects a product and adds it to their shopping cart.
### 3. Checkout:
User moves to the checkout phase to provide billing/shipping information.
### 4. Purchase:
User completes the order processing flow successfully.

## Funnel Progression Matrix

| Stage Order | Event Name | Objective Description |
| :--- | :--- | :--- |
| 1 | `Browse` | Initial intent checkpoint |
| 2 | `Add to Cart` | Consideration milestone |
| 3 | `Checkout` | High-intent transaction initiation |
| 4 | `Purchase` | Successful conversion event |

``` CREATE VIEW Session_Summary AS
WITH SessionAggregation AS (
    SELECT 
        Session_ID,
        MIN(User_ID) AS User_ID,
        MIN(Event_Time) AS Session_Start,
        MAX(Event_Time) AS Session_End,
        MIN(Device) AS Device,
        MIN(Region) AS Region,
        MIN(Channel) AS Channel,
        MIN(Product_Category) AS Product_Category,
        MAX(Revenue) AS Revenue,
        MIN(CAST(Bonus_Flag AS INT)) AS Bonus_Flag,
        
        STRING_AGG(Event, ',') WITHIN GROUP (ORDER BY Event_Time ASC) AS Event_List
    FROM ecommerce
    GROUP BY Session_ID
)
SELECT 
    Session_ID,
    User_ID,
    Session_Start,
    Session_End,
    Device,
    Region,
    Channel,
    Product_Category,
    Revenue,
    Bonus_Flag,
    DATEDIFF(SECOND, Session_Start, Session_End) / 60.0 AS Session_Duration_Min,
    CASE 
        WHEN Event_List LIKE '%Purchase%'   THEN 'Purchase'
        WHEN Event_List LIKE '%Checkout%'   THEN 'Checkout'
        WHEN Event_List LIKE '%Add to Cart%' THEN 'Add to Cart'
        ELSE 'Browse'
    END AS Max_Funnel_Stage
FROM SessionAggregation;

```