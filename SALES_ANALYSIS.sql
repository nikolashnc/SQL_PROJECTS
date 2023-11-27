--- INSPECTING DATA

SELECT * 

FROM sales_data_sample

---- CHECKING UNIQUE VALUES


SELECT DISTINCT status ---- good to plot
FROM sales_data_sample  

SELECT DISTINCT productline ---- good to plot
FROM sales_data_sample

SELECT DISTINCT country ---- good to plot
FROM sales_data_sample

SELECT DISTINCT dealsize ---- good to plot
FROM sales_data_sample

SELECT DISTINCT territory ---- good to plot
FROM sales_data_sample


---ANALYSIS
---------------- GROUPING  SALES BY PRODUCTLINE

SELECT SUM(SALES) TOTAL_SALES,PRODUCTLINE
FROM sales_data_sample
GROUP BY PRODUCTLINE
ORDER BY 1 DESC
---------------- GROUPING  SALES BY YEAR_ID
SELECT SUM(SALES) TOTAL_SALES,YEAR_ID
FROM sales_data_sample
GROUP BY YEAR_ID
ORDER BY 1 DESC
---------------- GROUPING  SALES BY DEALSIZE
SELECT SUM(SALES) TOTAL_SALES,DEALSIZE
FROM sales_data_sample
GROUP BY DEALSIZE
ORDER BY 1 DESC

----WHAT WAS THE BEST MONTH FOR SALES IN A SPECIFIC YEAR? HOW MUCH WAR EARNED THAT MONTH?

SELECT TOP(1) SUM (SALES),YEAR_ID,MONTH_ID,COUNT (MONTH_ID) FREQUENCY
FROM sales_data_sample
GROUP BY YEAR_ID,MONTH_ID
HAVING YEAR_ID = 2003
ORDER BY 1 DESC

SELECT TOP (1) SUM (SALES),YEAR_ID,MONTH_ID,COUNT (MONTH_ID) FREQUENCY
FROM sales_data_sample
GROUP BY YEAR_ID,MONTH_ID
HAVING YEAR_ID = 2004
ORDER BY 1 DESC

SELECT TOP(1)SUM (SALES),YEAR_ID,MONTH_ID,COUNT (MONTH_ID) FREQUENCY
FROM sales_data_sample
GROUP BY YEAR_ID,MONTH_ID
HAVING YEAR_ID = 2005
ORDER BY 1 DESC


---- WHO IS THE BEST CUSTOMER( BY ANALYZING RFM- RECENCY FREQUENCY MONETARY)?

DROP TABLE IF EXISTS #RFM
;WITH RFM AS (
				SELECT
					CUSTOMERNAME,
					SUM (SALES) MONETARY_VALUE,
					AVG(SALES) AVG_MONETARY_VALUE,
					COUNT(ORDERNUMBER) FREQUENCY,
					MAX (FORMAT(ORDERDATE,'yyyy-MM-dd')) last_order_date,
					(SELECT MAX (FORMAT(ORDERDATE,'yyyy-MM-dd')) FROM sales_data_sample) max_order_date,
					DATEDIFF(day,MAX (FORMAT(ORDERDATE,'yyyy-MM-dd')),
					(SELECT MAX (FORMAT(ORDERDATE,'yyyy-MM-dd')) FROM sales_data_sample)) Recency

				FROM sales_data_sample
				GROUP BY CUSTOMERNAME
			),

RFM_CAL AS (

			SELECT *,
					NTILE(4) OVER (ORDER BY RECENCY DESC) RFM_RECENCY,
					NTILE(4) OVER (ORDER BY FREQUENCY ) RFM_FREQUENCY,
					NTILE(4) OVER (ORDER BY AVG_MONETARY_VALUE ) RFM_MONETARY

			from rfm

			)
SELECT *,RFM_RECENCY+RFM_FREQUENCY+RFM_MONETARY AS RFM_CELL ,
CONCAT(RFM_RECENCY,RFM_FREQUENCY,RFM_MONETARY) AS RFM_CELL_STRING

INTO #RFM

FROM RFM_CAL

SELECT CUSTOMERNAME,RFM_RECENCY,RFM_FREQUENCY,RFM_MONETARY,

case 
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'  --lost customers
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately) slipping away
		when rfm_cell_string in (311, 411, 331) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322) then 'potential churners'
		when rfm_cell_string in (323, 333,321, 422, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment


FROM #RFM

--What products are most often sold together? 
--select * from [dbo].[sales_data_sample] where ORDERNUMBER =  10411

select distinct OrderNumber, stuff(

	(select ',' + PRODUCTCODE
	from [sales_data_sample] p
	where ORDERNUMBER in 
		(

			select ORDERNUMBER
			from (
				select ORDERNUMBER, count(*) rn
				FROM [sales_data_sample]
				where STATUS = 'Shipped'
				group by ORDERNUMBER
			)m
			where rn = 3
		)
		and p.ORDERNUMBER = s.ORDERNUMBER
		for xml path (''))

		, 1, 1, '') ProductCodes

from [sales_data_sample] s
order by 2 desc


---EXTRAs----
--What city has the highest number of sales in a specific country
select city, sum (sales) Revenue
from [sales_data_sample]
where country = 'UK'
group by city
order by 2 desc



---What is the best product in United States?
select country, YEAR_ID, PRODUCTLINE, sum(sales) Revenue
from [sales_data_sample]
where country = 'USA'
group by  country, YEAR_ID, PRODUCTLINE
order by 4 desc
