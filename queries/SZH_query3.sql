ACCEPT age_choice NUMBER PROMPT 'Enter age group choice (1=Teenagers, 2=Young Adults, 3=Adults, 4=Seniors): '
COLUMN chosen_age_grp NEW_VALUE age_group_title
SELECT CASE &age_choice
           WHEN 1 THEN 'Teenagers (13-19)'
           WHEN 2 THEN 'Young Adults (20-35)'
           WHEN 3 THEN 'Adults (36-60)'
           WHEN 4 THEN 'Seniors (60+)'
       END AS chosen_age_grp
FROM dual;

SET LINESIZE 130
SET PAGESIZE 35

COLUMN age_group        FORMAT A25     HEADING 'AGE GROUP'
COLUMN cal_year         FORMAT 9999    HEADING 'YEAR'
COLUMN 'TOTAL LOANS'    FORMAT 999,999 
COLUMN 'Loan YOY (%)'   FORMAT 999.99
COLUMN top_loan_category FORMAT A25    HEADING 'Top Loan Category'
COLUMN "TOTAL SALES (RM)" FORMAT 999,999,999.99
COLUMN 'Sales YOY (%)'    FORMAT 999.99 
COLUMN top_seller_category FORMAT A25  HEADING 'Top Seller Category'


TTITLE CENTER 'Book Loans vs Sales by Age Group' SKIP 1 -
    LEFT 'Date Generated: ' _DATE -
    RIGHT 'Page ' SQL.PNO SKIP 2 -
    LEFT 'Age Group: &age_group_title' SKIP 1 - 
    LEFT '-----------------------------------------------------------------------------------------------------------------' SKIP 1


WITH AgeMapping AS (
    SELECT 1 AS choice, 'Teenagers (13-19)' AS age_group FROM dual UNION ALL
    SELECT 2, 'Young Adults (20-35)' FROM dual UNION ALL
    SELECT 3, 'Adults (36-60)' FROM dual UNION ALL
    SELECT 4, 'Seniors (60+)' FROM dual
),
-- Loan category totals
LoanAggRaw AS (
    SELECT
        dd.cal_year,
        CASE
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 13 AND 19 THEN 'Teenagers (13-19)'
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 20 AND 35 THEN 'Young Adults (20-35)'
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 36 AND 60 THEN 'Adults (36-60)'
            ELSE 'Seniors (60+)'
        END AS age_group,
        bd.book_category,
        COUNT(blf.loan_id) AS loan_count
    FROM Book_Loan_Fact blf
    JOIN Member_Dim md ON blf.member_key = md.member_key
    JOIN Date_Dim dd   ON blf.date_key   = dd.date_key
    JOIN Book_Dim bd   ON blf.book_key   = bd.book_key
    GROUP BY dd.cal_year, bd.book_category,
             CASE
                 WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 13 AND 19 THEN 'Teenagers (13-19)'
                 WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 20 AND 35 THEN 'Young Adults (20-35)'
                 WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 36 AND 60 THEN 'Adults (36-60)'
                 ELSE 'Seniors (60+)'
             END
),
LoanAgg AS (
    SELECT
        cal_year,
        age_group,
        SUM(loan_count) AS total_loans
    FROM LoanAggRaw
    GROUP BY cal_year, age_group
),
TopLoan AS (
    SELECT cal_year, age_group, book_category AS top_loan_category
    FROM (
        SELECT cal_year, age_group, book_category, SUM(loan_count) AS total_cat_loans,
               RANK() OVER (PARTITION BY cal_year, age_group ORDER BY SUM(loan_count) DESC) AS rnk
        FROM LoanAggRaw
        GROUP BY cal_year, age_group, book_category
    )
    WHERE rnk = 1
),
-- Sales category totals
SalesAggRaw AS (
    SELECT
        dd.cal_year,
        CASE
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 13 AND 19 THEN 'Teenagers (13-19)'
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 20 AND 35 THEN 'Young Adults (20-35)'
            WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 36 AND 60 THEN 'Adults (36-60)'
            ELSE 'Seniors (60+)'
        END AS age_group,
        bfs.category,
        SUM(salesf.total_sales_amount) AS sales_amount
    FROM Book_Sales_Fact salesf
    JOIN Member_Dim md ON salesf.member_key = md.member_key
    JOIN Date_Dim dd   ON salesf.date_key   = dd.date_key
    JOIN Book_For_Sales_Dim bfs ON salesf.book_for_sales_key = bfs.book_for_sales_key
    GROUP BY dd.cal_year, bfs.category,
             CASE
                 WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 13 AND 19 THEN 'Teenagers (13-19)'
                 WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 20 AND 35 THEN 'Young Adults (20-35)'
                 WHEN TRUNC(MONTHS_BETWEEN(SYSDATE, md.member_dob)/12) BETWEEN 36 AND 60 THEN 'Adults (36-60)'
                 ELSE 'Seniors (60+)'
             END
),
SalesAgg AS (
    SELECT
        cal_year,
        age_group,
        SUM(sales_amount) AS total_sales
    FROM SalesAggRaw
    GROUP BY cal_year, age_group
),
TopSales AS (
    SELECT cal_year, age_group, category AS top_seller_category
    FROM (
        SELECT cal_year, age_group, category, SUM(sales_amount) AS total_cat_sales,
               RANK() OVER (PARTITION BY cal_year, age_group ORDER BY SUM(sales_amount) DESC) AS rnk
        FROM SalesAggRaw
        GROUP BY cal_year, age_group, category
    )
    WHERE rnk = 1
),
Combined AS (
    SELECT
        COALESCE(l.cal_year, s.cal_year) AS cal_year,
        COALESCE(l.age_group, s.age_group) AS age_group,
        NVL(l.total_loans,0) AS total_loans,
        t1.top_loan_category,
        NVL(s.total_sales,0) AS total_sales,
        t2.top_seller_category
    FROM LoanAgg l
    FULL OUTER JOIN SalesAgg s
        ON l.cal_year = s.cal_year AND l.age_group = s.age_group
    LEFT JOIN TopLoan t1
        ON l.cal_year = t1.cal_year AND l.age_group = t1.age_group
    LEFT JOIN TopSales t2
        ON s.cal_year = t2.cal_year AND s.age_group = t2.age_group
)
SELECT
    cal_year,
    top_loan_category,
    total_loans AS "TOTAL LOANS",
    ROUND(((total_loans - LAG(total_loans) OVER (PARTITION BY age_group ORDER BY cal_year))
           / NULLIF(LAG(total_loans) OVER (PARTITION BY age_group ORDER BY cal_year),0))*100,2) AS "Loan YOY (%)",
    top_seller_category AS,
    total_sales AS "TOTAL SALES (RM)",
    ROUND(((total_sales - LAG(total_sales) OVER (PARTITION BY age_group ORDER BY cal_year))
           / NULLIF(LAG(total_sales) OVER (PARTITION BY age_group ORDER BY cal_year),0))*100,2) AS "Sales YOY (%)"
FROM Combined
WHERE age_group = (SELECT age_group FROM AgeMapping WHERE choice = &age_choice)
AND cal_year BETWEEN 2015 AND EXTRACT(YEAR FROM SYSDATE) - 1
ORDER BY cal_year;


TTITLE OFF
CLEAR BREAKS
CLEAR COMPUTES;
