SELECT DISTINCT custnum, agent_custid, first, last, company
 FROM cust_pkg LEFT JOIN cust_main USING ( custnum )
 WHERE cancel IS NULL AND 0 < (
   SELECT COUNT(*) FROM cust_pkg AS others
    WHERE cust_pkg.custnum = others.custnum
      AND cust_pkg.pkgnum != others.pkgnum
      AND cust_pkg.bill != others.bill
      AND others.cancel IS NULL
 );
