EXPLAIN SELECT    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill   LEFT JOIN cust_main USING ( custnum ) WHERE cust_bill._date >  ( EXTRACT( EPOCH FROM  now() ) - 2592000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL )   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund LEFT JOIN cust_main USING ( custnum ) WHERE cust_refund._date >  ( EXTRACT( EPOCH FROM  now() ) - 2592000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL ) )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit LEFT JOIN cust_main USING ( custnum ) WHERE cust_credit._date >  ( EXTRACT( EPOCH FROM  now() ) - 2592000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL ) )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay    LEFT JOIN cust_main USING ( custnum ) WHERE cust_pay._date >  ( EXTRACT( EPOCH FROM  now() ) - 2592000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL )    )
                                                             AS balance_0_30,   ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill   LEFT JOIN cust_main USING ( custnum ) WHERE cust_bill._date <= ( EXTRACT( EPOCH FROM  now() ) - 2592000 ) AND cust_bill._date >  ( EXTRACT( EPOCH FROM  now() ) - 5184000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL )   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund LEFT JOIN cust_main USING ( custnum ) WHERE cust_refund._date <= ( EXTRACT( EPOCH FROM  now() ) - 2592000 ) AND cust_refund._date >  ( EXTRACT( EPOCH FROM  now() ) - 5184000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL ) )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit LEFT JOIN cust_main USING ( custnum ) WHERE cust_credit._date <= ( EXTRACT( EPOCH FROM  now() ) - 2592000 ) AND cust_credit._date >  ( EXTRACT( EPOCH FROM  now() ) - 5184000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL ) )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay    LEFT JOIN cust_main USING ( custnum ) WHERE cust_pay._date <= ( EXTRACT( EPOCH FROM  now() ) - 2592000 ) AND cust_pay._date >  ( EXTRACT( EPOCH FROM  now() ) - 5184000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL )    )
                                                             AS balance_30_60,   ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill   LEFT JOIN cust_main USING ( custnum ) WHERE cust_bill._date <= ( EXTRACT( EPOCH FROM  now() ) - 5184000 ) AND cust_bill._date >  ( EXTRACT( EPOCH FROM  now() ) - 7776000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL )   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund LEFT JOIN cust_main USING ( custnum ) WHERE cust_refund._date <= ( EXTRACT( EPOCH FROM  now() ) - 5184000 ) AND cust_refund._date >  ( EXTRACT( EPOCH FROM  now() ) - 7776000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL ) )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit LEFT JOIN cust_main USING ( custnum ) WHERE cust_credit._date <= ( EXTRACT( EPOCH FROM  now() ) - 5184000 ) AND cust_credit._date >  ( EXTRACT( EPOCH FROM  now() ) - 7776000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL ) )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay    LEFT JOIN cust_main USING ( custnum ) WHERE cust_pay._date <= ( EXTRACT( EPOCH FROM  now() ) - 5184000 ) AND cust_pay._date >  ( EXTRACT( EPOCH FROM  now() ) - 7776000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL )    )
                                                             AS balance_60_90,   ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill   LEFT JOIN cust_main USING ( custnum ) WHERE cust_bill._date <= ( EXTRACT( EPOCH FROM  now() ) - 7776000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL )   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund LEFT JOIN cust_main USING ( custnum ) WHERE cust_refund._date <= ( EXTRACT( EPOCH FROM  now() ) - 7776000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL ) )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit LEFT JOIN cust_main USING ( custnum ) WHERE cust_credit._date <= ( EXTRACT( EPOCH FROM  now() ) - 7776000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL ) )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay    LEFT JOIN cust_main USING ( custnum ) WHERE cust_pay._date <= ( EXTRACT( EPOCH FROM  now() ) - 7776000 ) AND    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL )    )
                                                             AS balance_90_0,   ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill   LEFT JOIN cust_main USING ( custnum ) WHERE    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL )   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund LEFT JOIN cust_main USING ( custnum ) WHERE    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL ) )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit LEFT JOIN cust_main USING ( custnum ) WHERE    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL ) )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay    LEFT JOIN cust_main USING ( custnum ) WHERE    ( SELECT COALESCE(SUM(charged - ( SELECT COALESCE(SUM(amount),0) FROM cust_bill_pay
                                                                 WHERE cust_bill.invnum = cust_bill_pay.invnum   ) - ( SELECT COALESCE(SUM(amount),0) FROM cust_credit_bill
                                                                 WHERE cust_bill.invnum = cust_credit_bill.invnum   )),         0) FROM cust_bill    WHERE cust_main.custnum = cust_bill.custnum   )
                                                              + ( SELECT COALESCE(SUM(refund
                                                              - COALESCE( 
                                                                          ( SELECT SUM(amount) FROM cust_credit_refund
                                                                              WHERE cust_refund.refundnum = cust_credit_refund.refundnum )
                                                                          ,0
                                                                        )
                                                              - COALESCE(
                                                                          ( SELECT SUM(amount) FROM cust_pay_refund
                                                                              WHERE cust_refund.refundnum = cust_pay_refund.refundnum )
                                                                          ,0
                                                                        )
                                                            ), 0) FROM cust_refund  WHERE cust_main.custnum = cust_refund.custnum )
                                                              - ( SELECT COALESCE(SUM(amount
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_refund
                                                                                  WHERE cust_credit.crednum = cust_credit_refund.crednum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_credit_bill
                                                                                  WHERE cust_credit.crednum = cust_credit_bill.crednum )
                                                                              ,0
                                                                            )
                                                            ), 0) FROM cust_credit  WHERE cust_main.custnum = cust_credit.custnum )
                                                              - ( SELECT COALESCE(SUM(paid
                                                                  - COALESCE( 
                                                                              ( SELECT SUM(amount) FROM cust_bill_pay
                                                                                  WHERE cust_pay.paynum = cust_bill_pay.paynum )
                                                                              ,0
                                                                            )
                                                                  - COALESCE(
                                                                              ( SELECT SUM(amount) FROM cust_pay_refund
                                                                                  WHERE cust_pay.paynum = cust_pay_refund.paynum )
                                                                              ,0
                                                                            )
                                                            ),    0) FROM cust_pay     WHERE cust_main.custnum = cust_pay.custnum    )
                                                             > 0 AND ( agentnum = 1 OR agentnum = 2 OR agentnum = 3 OR agentnum = 4 OR agentnum IS NULL )    )
                                                             AS balance_0_0
