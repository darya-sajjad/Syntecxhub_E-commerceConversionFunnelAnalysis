-- Check for null values
SELECT * FROM ecommerce
WHERE
	User_ID IS NULL
	OR Session_ID IS NULL
	OR Event_Time IS NULL
	OR Event IS NULL
	OR Device IS NULL
	OR Region IS NULL
	OR Channel IS NULL
	OR Product_Category IS NULL
	OR Revenue IS NULL
	OR Bonus_Flag IS NULL

-- Check for duplicates
WITH CTE_Duplicates AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY [User_ID]
            ,[Session_ID]
            ,[Event_Time]
            ,[Event]
            ,[Device]
            ,[Region]
            ,[Channel]
            ,[Product_Category]
            ,[Revenue]
            ,[Bonus_Flag] 
                ORDER BY [User_ID]
            ) AS RowNum
        FROM ecommerce
    )
SELECT *
FROM CTE_Duplicates
WHERE RowNum > 1;

-- Add new columns for date, day, hour, and week number, extracted from the Event_Time column
ALTER TABLE ecommerce
ADD
	[Date] AS CAST (Event_Time AS DATE),
	[Day] AS DATEPART (WEEKDAY, Event_Time),
	[Hour] AS DATEPART (HOUR, Event_Time),
	[Week_Number] AS DATEPART (WEEK, Event_Time)
    
-- Add a column for event sequence
ALTER TABLE ecommerce
ADD Event_Sequence INT

-- Calculate the event sequence within each session
WITH SequencedData AS (
SELECT
	Session_ID,
	Event_Time,
	ROW_NUMBER() OVER (
		PARTITION BY Session_ID
		ORDER BY Event_Time ASC
	) AS CalculatedSequence
FROM ecommerce
)
UPDATE e
SET e.Event_Sequence = s.CalculatedSequence
FROM ecommerce e
JOIN SequencedData s
ON e.Session_ID = s.Session_ID
AND e.Event_Time = s.Event_Time
