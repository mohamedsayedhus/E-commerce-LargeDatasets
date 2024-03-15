CREATE DATABASE Performanc_Sales_Data

USE Performanc_Sales_Data

--Before anything, we will copy a backup copy through (T-SQL)
BACKUP DATABASE Performanc_Sales_Data
TO DISK = 'C:\Users\m-r\Documents\SQL Server Management Studio\Code Snippets\SQL\YourBackupFileName.bak';

SELECT name FROM sys.databases WHERE name = 'Performanc_Sales_Data';

--Moving the data into a single Table to improve the querys
SELECT Customer_ID, Customer_Name, Segment, Country, City, State, Postal_Code, Region
INTO NewCustomers 
FROM SalesOrders

---Here Remove erase any duplicates to give them index

-- Check & Validation 
SELECT Customer_ID, COUNT(*) AS count
FROM NewCustomers
GROUP BY Customer_ID;
-- Remove any duplicates 
WITH CTE AS (
             SELECT 
			       Customer_ID,
			       ROW_NUMBER() OVER (PARTITION BY Customer_ID ORDER BY (SELECT NULL)) AS RowNum
			 FROM NewCustomers
			 )
DELETE FROM CTE WHERE RowNum >1
--Here we created a table to create the index because the main identifier was "text"
ALTER TABLE NewCustomers
ADD Customer_Index INT;

;WITH CTE AS (
    SELECT Customer_ID, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum
    FROM NewCustomers
)
UPDATE NewCustomers
SET Customer_Index = CTE.RowNum
FROM NewCustomers
JOIN CTE ON NewCustomers.Customer_ID = CTE.Customer_ID
-- We Merge the two tables for relationships
ALTER TABLE SalesOrders
ADD Cus_Index INT;

MERGE INTO SalesOrders s
USING NewCustomers n
ON s.Customer_ID = n.Customer_ID
WHEN MATCHED THEN
  UPDATE SET s.Cus_Index = n.Cus_Index;
-- Remove product rows from the master table to improve optimization and performance
ALTER TABLE SalesOrders
DROP COLUMN Customer_Name, Segment, Country, City, State, Postal_Code, Region;

-----------------------------------------------------------------------------------------------------
--###################################################################################################
-----------------------------------------------------------------------------------------------------
--Moving the data into a single Table to improve the querys
SElECT Product_ID, Category, Sub_Category, Product_Name
INTO NewProducts
FROM SalesOrders
--Here we erase any duplicates to give them index

--Check any duplicates
SELECT Product_ID, COUNT(*) AS COUNT 
FROM NewProducts
GROUP BY Product_ID;
-- Remove any duplicates
WITH CTE AS (
    SELECT 
        Product_ID,
        ROW_NUMBER() OVER (PARTITION BY Product_ID ORDER BY (SELECT NULL)) AS RowNum
    FROM NewProducts
)
DELETE FROM CTE WHERE RowNum > 1;
--Here we created a table to create the index because the main identifier was "text"
ALTER TABLE NewProducts
ADD Product_Index INT;

;WITH CTE AS (
    SELECT Product_ID, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum
    FROM NewProducts
)
UPDATE NewProducts
SET Product_Index = CTE.RowNum
FROM NewProducts
JOIN CTE ON NewProducts.Product_ID = CTE.Product_ID;
-- We Merge the two tables for relationships
ALTER TABLE SalesOrders
ADD Pro_Index INT; 

MERGE INTO SalesOrders s
USING NewProducts n
ON s.Product_ID = n.Product_ID
WHEN MATCHED THEN 
    UPDATE SET s.Pro_Index = n.Product_Index;
-- Remove product rows from the master table to improve optimization and performance
ALTER TABLE SalesOrders
DROP COLUMN Product_ID, Category, Sub_Category, Product_Name;
-----------------------------------------------------------------------------------------------------
--###################################################################################################
-----------------------------------------------------------------------------------------------------
--Total Sales
SELECT SUM(Sales) AS Total_Sales
FROM SalesOrders
--Total Quantity BY Product_Name
SELECT Product_Name, Count(*) AS Total_Quantity
FROM NewProducts
GROUP BY Product_Name 
--Total Customers
SELECT COUNT(Customer_ID) AS total_Customer 
FROM NewCustomers 
--Total Sales By Customer Segmentation
SELECT Segment, SUM(Sales) AS TotalSales
FROM NewCustomers n
JOIN SalesOrders s 
ON n.Cus_Index = s.Cus_Index
GROUP BY Segment;
-- Top Product By Sales
SELECT Product_Name, Category, SUM(Sales) AS TotalSales
FROM NewProducts n
JOIN SalesOrders s ON n.Pro_Index = s.Pro_Index
GROUP BY Product_Name, Category
ORDER BY TotalSales DESC;
--Sales By State
SELECT State, SUM(Sales) AS Total_Sales
FROM NewCustomers n
JOIN SalesOrders S
ON n.Cus_Index = s.Cus_Index
GROUP BY State
ORDER BY SUM(Sales) DESC;
-- Sales Trends 
SELECT Order_Date, Product_Name, Category, s.Customer_ID,SUM(Sales) AS Total_Sales
FROM SalesOrders s
JOIN NewProducts n 
ON s.Pro_Index = n.Pro_Index
JOIN NewCustomers c
ON s.Cus_Index = c.Cus_Index
GROUP BY Order_Date, Product_Name, Category, s.Customer_ID
ORDER BY Total_Sales DESC;
-- Sales Timeing Basedon (D - M - Y)
--Sales By Day
SELECT 
    CONVERT(DATE, Order_Date) AS OrderDay,
    SUM(Sales) AS DailyRevenue
FROM SalesOrders
GROUP BY CONVERT(DATE, Order_Date)
ORDER BY OrderDay DESC;
--Sales By Month
SELECT
      FORMAT(Order_Date, '2018 - 12') As OrderMonth, 
	  SUM(Sales) As ManthSalling
FROM SalesOrders
GROUP BY FORMAT(Order_Date, '2018 - 12')
ORDER BY OrderMonth DESC;
--Sales By Year
SELECT 
      YEAR(Order_Date) AS OrderYear,
	  SUM(Sales) AS AnnualRevenue
FROM SalesOrders
GROUP BY  YEAR(Order_Date) 
ORDER BY OrderYear DESC;
--Sales Clustring
SELECT MIN(Sales)AS Mnimum, AVG(Sales) AS Average, MAX(Sales) AS Maxmum
FROM SalesOrders 

--Sales Clustring Segment & Category
SELECT Segment, Category,
       CASE 
	   WHEN Sales <= 230 THEN 'Less Than 230$'
	   WHEN Sales >= 230 AND Sales <= 1000 THEN '230$ To 1K$'
	   WHEN Sales >= 1000 AND Sales <= 10000 THEN '1k$ To 10K$'
	   WHEN Sales >= 10000 AND Sales <= 15000 THEN '10k$ To 15K$'
	   ELSE 'More Than 15K$'
	END AS Sales_Clustring
FROM SalesOrders s
JOIN NewCustomers n
ON s.Cus_Index = n.Cus_Index
Join NewProducts p
ON s.Pro_Index = p.Pro_Index
GROUP BY Segment, Sales, Category
ORDER BY Sales_Clustring Asc;

-- Missing Order Date AND Determine the type of day
WITH Numbers AS (
    SELECT ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM master.dbo.spt_values
), DateSeries AS (
    SELECT DATEADD(DAY, n, MIN(Order_Date)) AS OrderDate,
           CASE 
               WHEN DATEPART(WEEKDAY, DATEADD(DAY, n, MIN(Order_Date))) IN (1, 7) THEN 'Weekend'
               ELSE 'Work Day'
           END AS DayType
    FROM SalesOrders
    CROSS JOIN Numbers
    GROUP BY n
    HAVING DATEADD(DAY, n, MIN(Order_Date)) <= MAX(Order_Date)
)

SELECT ds.OrderDate AS Missing_Order_Date, ds.DayType
FROM DateSeries ds
LEFT JOIN SalesOrders so
ON ds.OrderDate = so.Order_Date
WHERE so.Order_Date IS NULL;
--difference in shipping days
SELECT Order_ID, 
       Order_Date, 
       Ship_Date,
       DATEDIFF(DAY, Order_Date, Ship_Date) AS DaysDifference
FROM SalesOrders;
-- Days since last order 
WITH OrderedSales AS (
    SELECT 
        s.Customer_ID,
        s.Order_ID, 
        s.Order_Date, 
        LAG(s.Order_Date) OVER (PARTITION BY s.Customer_ID ORDER BY s.Order_Date) AS PreviousOrderDate
    FROM SalesOrders s
    INNER JOIN NewCustomers c ON s.Cus_Index = c.Cus_Index 
)
SELECT 
    o.Customer_ID,
    o.Order_ID, 
    o.Order_Date,
    o.PreviousOrderDate,
    DATEDIFF(DAY, o.PreviousOrderDate, o.Order_Date) AS DaysSinceLastOrder
FROM OrderedSales o;
