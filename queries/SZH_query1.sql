SET PAGESIZE 35
SET LINESIZE 130

ACCEPT startYear PROMPT 'Enter the start year: '
ACCEPT endYear   PROMPT 'Enter the end year: '


TTITLE CENTER 'Annual Sales Trend by Category and Gender (&startYear - &endYear)' SKIP  -
       LEFT 'Date Generated: ' _DATE -
       RIGHT 'Page ' SQL.PNO SKIP 2

COLUMN category           HEADING 'CATEGORY'
COLUMN year               FORMAT A10 HEADING 'YEAR'
COLUMN male_sales         FORMAT 999,999,999.99 HEADING 'MALE_SALES (RM)'
COLUMN female_sales       FORMAT 999,999,999.99 HEADING 'FEMALE_SALES (RM)'
COLUMN diff               FORMAT 999,999,999.99 HEADING 'DIFF (RM)'
COLUMN perc               FORMAT 999.99 HEADING 'PERCENTAGE (%)'

BREAK ON category SKIP 1 ON REPORT
COMPUTE AVG LABEL 'Average' OF male_sales female_sales diff perc ON category
COMPUTE AVG LABEL 'Grand Average' OF male_sales female_sales diff perc ON REPORT


WITH SalesAgg AS (
    SELECT
        bfs.category,
        mem.member_gender,
        dd.cal_year,
        SUM(bsf.total_sales_amount) AS total_sales
    FROM Book_Sales_Fact bsf
         JOIN Date_Dim dd ON bsf.date_key = dd.date_key
         JOIN Member_Dim mem ON bsf.member_key = mem.member_key
         JOIN Book_For_Sales_Dim bfs ON bsf.book_for_sales_key = bfs.book_for_sales_key
    WHERE dd.cal_year BETWEEN &startYear AND &endYear
    GROUP BY bfs.category, mem.member_gender, dd.cal_year
),
SalesPivot AS (
    SELECT
        category,
        cal_year AS year,
        SUM(CASE WHEN member_gender = 'M' THEN total_sales ELSE 0 END) AS male_sales,
        SUM(CASE WHEN member_gender = 'F' THEN total_sales ELSE 0 END) AS female_sales
    FROM SalesAgg
    GROUP BY category, cal_year
)
SELECT
    category,
    TO_CHAR(year) AS year,
    male_sales,
    female_sales,
    male_sales - female_sales AS diff,
    CASE 
        WHEN GREATEST(male_sales, female_sales) = 0 THEN NULL
        ELSE ROUND(((male_sales - female_sales) / GREATEST(male_sales, female_sales)) * 100, 2)
    END AS perc
FROM SalesPivot
ORDER BY category, year;

CLEAR BREAKS
CLEAR COMPUTES
TTITLE OFF;
