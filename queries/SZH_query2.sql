SET PAGESIZE 34
SET LINESIZE 130

ACCEPT startYear PROMPT 'Enter the start year: '
ACCEPT endYear   PROMPT 'Enter the end year: '

DECLARE
    v_start NUMBER := &startYear;
    v_end   NUMBER := &endYear;
BEGIN
    IF v_start IS NULL OR v_end IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Start year and End year must be entered.');
    ELSIF v_start > v_end THEN
        RAISE_APPLICATION_ERROR(-20002, 'Start year cannot be greater than End year.');
    ELSIF v_start < 2015 OR v_end > EXTRACT(YEAR FROM SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20003, 'Years must be between 2015 and current year.');
    END IF;
END;
/

COLUMN cal_year       FORMAT 9999      HEADING 'YEAR'
COLUMN member_city    FORMAT A20      HEADING 'CITY'
COLUMN member_state   FORMAT A25      HEADING 'STATE'
COLUMN total_loans    FORMAT 999,999  HEADING 'TOTAL_LOANS'
COLUMN unique_borrowers FORMAT 999,999 HEADING 'UNIQUE|BORROWERS'
COLUMN avg_loans      FORMAT 999.99   HEADING 'AVG LOANS/BORROWER'
COLUMN loan_share     FORMAT 999.99   HEADING 'Loan Contribution(%)'
COLUMN yoy_growth     FORMAT 999.99   HEADING 'YOY GROWTH(%)'

TTITLE CENTER 'Top 6 Malaysian Cities by Annual Book Loans (&startYear - &endYear)' SKIP 1 -
       LEFT 'Date Generated: ' _DATE -
       RIGHT 'Page ' SQL.PNO SKIP 2

BREAK ON cal_year SKIP 1

WITH LoanAgg AS (
    SELECT 
        dd.cal_year,
        md.city AS member_city,
        md.state AS member_state,
        COUNT(blf.loan_id) AS total_loans,
        COUNT(DISTINCT blf.member_key) AS unique_borrowers,
        COUNT(blf.loan_id) / COUNT(DISTINCT blf.member_key) AS avg_loans
    FROM Book_Loan_Fact blf
    JOIN Member_Dim md
        ON blf.member_key = md.member_key
    JOIN Date_Dim dd
        ON blf.date_key = dd.date_key
    WHERE dd.cal_year BETWEEN &startYear AND &endYear
      AND md.country = 'MALAYSIA'
      AND md.city IN ('KUALA LUMPUR',
                      'JOHOR BAHRU',
                      'SHAH ALAM',
                      'KLANG',
                      'PETALING JAYA',
                      'KUANTAN')
    GROUP BY dd.cal_year, md.city, md.state
)
SELECT 
    cal_year,
    member_city,
    member_state,
    total_loans,
    unique_borrowers,
    ROUND(avg_loans,2) AS avg_loans,
    ROUND((total_loans / SUM(total_loans) OVER (PARTITION BY cal_year)) * 100,2) AS loan_share,
    ROUND(((total_loans - LAG(total_loans) OVER (PARTITION BY member_city ORDER BY cal_year))
           / LAG(total_loans) OVER (PARTITION BY member_city ORDER BY cal_year)) * 100,2) AS yoy_growth
FROM LoanAgg
ORDER BY cal_year, total_loans DESC;


TTITLE OFF
CLEAR BREAKS
CLEAR COMPUTES;
