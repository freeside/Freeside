#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#======================================================================
#
# Inventory received module
#
#======================================================================

package IR;


sub post_invoice {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($query, $sth, $null, $project_id);
  my $exchangerate = 0;

  if ($form->{id}) {

    &reverse_invoice($dbh, $form);

  } else {
    my $uid = time;
    $uid .= $form->{login};

    $query = qq|INSERT INTO ap (invnumber, employee_id)
                VALUES ('$uid', (SELECT id FROM employee
		                 WHERE login = '$form->{login}'))|;
    $dbh->do($query) || $form->dberror($query);
    
    $query = qq|SELECT id FROM ap
                WHERE invnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
  }

  map { $form->{$_} =~ s/'/''/g } qw(invnumber ordnumber);
  
  my ($amount, $linetotal, $lastinventoryaccno, $lastexpenseaccno);
  my ($netamount, $invoicediff, $expensediff) = (0, 0, 0);

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, 'sell');
  }
  
  $form->{exchangerate} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{exchangerate});

  
  for my $i (1 .. $form->{rowcount}) {
    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
    
    if ($form->{"qty_$i"} != 0) {
      
      map { $form->{"${_}_$i"} =~ s/'/''/g } qw(partnumber description unit);
      
      my ($allocated, $taxrate) = (0, 0);
      my $taxamount;
      
      $form->{"sellprice_$i"} = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      my $fxsellprice = $form->{"sellprice_$i"};

      my ($dec) = ($fxsellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;
      
      
      map { $taxrate += $form->{"${_}_rate"} } split / /, $form->{"taxaccounts_$i"};

      if ($form->{"inventory_accno_$i"}) {

	$linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2);
	
	if ($form->{taxincluded}) {
	  $taxamount = $linetotal * ($taxrate / (1 + $taxrate));
	  $form->{"sellprice_$i"} = $form->{"sellprice_$i"} * (1 / (1 + $taxrate));
	} else {
	  $taxamount = $linetotal * $taxrate;
	}

	$netamount += $linetotal;
	
	if ($taxamount != 0) {
	  map { $form->{amount}{$form->{id}}{$_} -= $taxamount * $form->{"${_}_rate"} / $taxrate } split / /, $form->{"taxaccounts_$i"};
	}

	# add purchase to inventory, this one is without the tax!
	$amount = $form->{"sellprice_$i"} * $form->{"qty_$i"} * $form->{exchangerate};
	$linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2) * $form->{exchangerate};
	$linetotal = $form->round_amount($linetotal, 2);

        # this is the difference for the inventory
	$invoicediff += ($amount - $linetotal);
	
	$form->{amount}{$form->{id}}{$form->{"inventory_accno_$i"}} -= $linetotal;

        # adjust and round sellprice
	$form->{"sellprice_$i"} = $form->round_amount($form->{"sellprice_$i"} * $form->{exchangerate}, $decimalplaces);

	
	# update parts table
	$query = qq|UPDATE parts SET
		    lastcost = $form->{"sellprice_$i"},
		    onhand = onhand + $form->{"qty_$i"}
	            WHERE id = $form->{"id_$i"}|;
	$dbh->do($query) || $form->dberror($query);


        # check if we sold the item already and
        # make an entry for the expense and inventory
	$query = qq|SELECT i.id, i.qty, i.allocated, i.trans_id,
		    p.inventory_accno_id, p.expense_accno_id, a.transdate
		    FROM invoice i, ar a, parts p
		    WHERE i.parts_id = p.id
	            AND i.parts_id = $form->{"id_$i"}
		    AND (i.qty + i.allocated) > 0
		    AND i.trans_id = a.id
		    ORDER BY transdate|;
	$sth = $dbh->prepare($query);
	$sth->execute || $form->dberror($query);


        my $totalqty = $form->{"qty_$i"};
	
	while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
	  
	  my $qty = $ref->{qty} + $ref->{allocated};
	  
	  if (($qty - $totalqty) > 0) {
	    $qty = $totalqty;
	  }


          $linetotal = $form->round_amount($form->{"sellprice_$i"} * $qty, 2);
	  
	  if ($ref->{allocated} < 0) {
	    # we have an entry for it already, adjust amount
	    $form->update_balance($dbh,
				  "acc_trans",
				  "amount",
				  qq|trans_id = $ref->{trans_id} AND chart_id = $ref->{inventory_accno_id} AND transdate = '$ref->{transdate}'|,
				  $linetotal);

	    $form->update_balance($dbh,
				  "acc_trans",
				  "amount",
				  qq|trans_id = $ref->{trans_id} AND chart_id = $ref->{expense_accno_id} AND transdate = '$ref->{transdate}'|,
				  $linetotal * -1);

	  } else {
	    # add entry for inventory, this one is for the sold item
	    if ($linetotal != 0) {
	      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, 
			  transdate)
			  VALUES ($ref->{trans_id}, $ref->{inventory_accno_id},
			  $linetotal, '$ref->{transdate}')|;
	      $dbh->do($query) || $form->dberror($query);

	      # add expense
	      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, 
			  transdate)
			  VALUES ($ref->{trans_id}, $ref->{expense_accno_id},
			  |. ($linetotal * -1) .qq|, '$ref->{transdate}')|;
	      $dbh->do($query) || $form->dberror($query);
	    }
	  }
	
	  # update allocated for sold item
	  $form->update_balance($dbh,
				"invoice",
				"allocated",
				qq|id = $ref->{id}|,
				$qty * -1);
	
	  $allocated += $qty;

	  last if (($totalqty -= $qty) <= 0);
	}

	$sth->finish;

        $lastinventoryaccno = $form->{"inventory_accno_$i"};
	
      } else {
	
	$linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2);
	
        if ($form->{taxincluded}) {
	  $taxamount = $linetotal * ($taxrate / (1 + $taxrate));
	  
	  $form->{"sellprice_$i"} = $form->{"sellprice_$i"} * (1 / (1 + $taxrate));
	} else {
	  $taxamount = $linetotal * $taxrate;
	}
	
	$netamount += $linetotal;
	
        if ($taxamount != 0) {
	  map { $form->{amount}{$form->{id}}{$_} -= $taxamount * $form->{"${_}_rate"} / $taxrate } split / /, $form->{"taxaccounts_$i"};
	}

        $amount = $form->{"sellprice_$i"} * $form->{"qty_$i"} * $form->{exchangerate};
	$linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2) * $form->{exchangerate};
	$linetotal = $form->round_amount($linetotal, 2);

        # this is the difference for expense
	$expensediff += ($amount - $linetotal);
	
	# add amount to expense
	$form->{amount}{$form->{id}}{$form->{"expense_accno_$i"}} -= $linetotal;

	$lastexpenseaccno = $form->{"expense_accno_$i"};

        # adjust and round sellprice
        $form->{"sellprice_$i"} = $form->round_amount($form->{"sellprice_$i"} * $form->{exchangerate}, $decimalplaces);
	
	# update lastcost
	$query = qq|UPDATE parts SET
		    lastcost = $form->{"sellprice_$i"}
	            WHERE id = $form->{"id_$i"}|;
	$dbh->do($query) || $form->dberror($query);

      }

      $project_id = 'NULL';
      if ($form->{"project_id_$i"}) {
	$project_id = $form->{"project_id_$i"};
      }
      $deliverydate = ($form->{"deliverydate_$i"}) ? qq|'$form->{"deliverydate_$i"}'| : "NULL";
      
      # save detail record in invoice table
      $query = qq|INSERT INTO invoice (trans_id, parts_id, description, qty,
                  sellprice, fxsellprice, allocated, unit, deliverydate)
		  VALUES ($form->{id}, $form->{"id_$i"},
		  '$form->{"description_$i"}', |. ($form->{"qty_$i"} * -1) .qq|,
		  $form->{"sellprice_$i"}, $fxsellprice, $allocated,
		  '$form->{"unit_$i"}', $deliverydate)|;
      $dbh->do($query) || $form->dberror($query);

    }
  }


  $form->{datepaid} = $form->{invdate};

  # all amounts are in natural state, netamount includes the taxes
  # if tax is included, netamount is rounded to 2 decimal places,
  # taxes are not
  
  # total payments
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
    $form->{paid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"} if ($form->{"datepaid_$i"}); 
  }

  my ($tax, $paiddiff) = (0, 0);

  $netamount = $form->round_amount($netamount, 2);
  
  # figure out rounding errors for amount paid and total amount
  if ($form->{taxincluded}) {

    $amount = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $paiddiff = $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;

    foreach my $item (split / /, $form->{taxaccounts}) {
      $amount = $form->{amount}{$form->{id}}{$item} * $form->{exchangerate};
      $form->{amount}{$form->{id}}{$item} = $form->round_amount($amount, 2);
      $amount = $form->{amount}{$form->{id}}{$item} * -1;
      $tax += $amount;
      $netamount -= $amount;
    }

    $invoicediff += $paiddiff;
    $expensediff += $paiddiff;
    
    ######## this only applies to tax included
    if ($lastinventoryaccno) {
      $form->{amount}{$form->{id}}{$lastinventoryaccno} -= $invoicediff;
    }
    if ($lastexpenseaccno) {
      $form->{amount}{$form->{id}}{$lastexpenseaccno} -= $expensediff;
    }

  } else {
    $amount = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $paiddiff = $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;
    foreach my $item (split / /, $form->{taxaccounts}) {
      $form->{amount}{$form->{id}}{$item} = $form->round_amount($form->{amount}{$form->{id}}{$item}, 2);
      $amount = $form->round_amount($form->{amount}{$form->{id}}{$item} * $form->{exchangerate} * -1, 2);
      $paiddiff += $amount - $form->{amount}{$form->{id}}{$item} * $form->{exchangerate} * -1;
      $form->{amount}{$form->{id}}{$item} = $form->round_amount($amount * -1, 2);
      $amount = $form->{amount}{$form->{id}}{$item} * -1;
      $tax += $amount;
    }
  }


  $form->{amount}{$form->{id}}{$form->{AP}} = $netamount + $tax;

  if ($form->{paid} != 0) {
    $form->{paid} = $form->round_amount($form->{paid} * $form->{exchangerate} + $paiddiff, 2);
  }


  # update exchangerate
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{invdate}, 0, $form->{exchangerate});
  }
  
  # record acc_trans transactions
  foreach my $trans_id (keys %{$form->{amount}}) {
    foreach my $accno (keys %{ $form->{amount}{$trans_id} }) {
      if (($form->{amount}{$trans_id}{$accno} = $form->round_amount($form->{amount}{$trans_id}{$accno}, 2)) != 0) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, 
		    transdate)
		    VALUES ($trans_id, (SELECT id FROM chart
		                         WHERE accno = '$accno'),
		    $form->{amount}{$trans_id}{$accno}, '$form->{invdate}')|;
	$dbh->do($query) || $form->dberror($query);
      }
    }
  }

  # deduct payment differences from paiddiff
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, 2);
      $paiddiff -= $amount - $form->{"paid_$i"} * $form->{exchangerate};
    }
  }

  # force AP entry if 0
  $form->{amount}{$form->{id}}{$form->{AP}} = $form->{paid} if ($form->{amount}{$form->{id}}{$form->{AP}} == 0);
  
  # record payments and offsetting AP
  for my $i (1 .. $form->{paidaccounts}) {

    if ($form->{"paid_$i"} != 0) {
      my ($accno) = split /--/, $form->{"AP_paid_$i"};
      $form->{"datepaid_$i"} = $form->{invdate} unless ($form->{"datepaid_$i"});
      $form->{datepaid} = $form->{"datepaid_$i"};
      
      $amount = ($form->round_amount($form->{"paid_$i"} * $form->{exchangerate} + $paiddiff, 2)) * -1;
      
      # record AP
      
      if ($form->{amount}{$form->{id}}{$form->{AP}} != 0) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate)
		    VALUES ($form->{id}, (SELECT id FROM chart
					WHERE accno = '$form->{AP}'),
		    $amount, '$form->{"datepaid_$i"}')|;
	$dbh->do($query) || $form->dberror($query);
      }

      # record payment
      
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                  source)
                  VALUES ($form->{id}, (SELECT id FROM chart
		                      WHERE accno = '$accno'),
                  $form->{"paid_$i"}, '$form->{"datepaid_$i"}',
		  '$form->{"source_$i"}')|;
      $dbh->do($query) || $form->dberror($query);


      $exchangerate = 0;

      if ($form->{currency} eq $form->{defaultcurrency}) {
	$form->{"exchangerate_$i"} = 1;
      } else {
	$exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell');

	$form->{"exchangerate_$i"} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      }
      

      # exchangerate difference
      $form->{fx}{$accno}{$form->{"datepaid_$i"}} += $form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1) + $paiddiff;
      

      # gain/loss
      $amount = ($form->{"paid_$i"} * $form->{exchangerate}) - ($form->{"paid_$i"} * $form->{"exchangerate_$i"});
      if ($amount > 0) {
	$form->{fx}{$form->{fxgain_accno}}{$form->{"datepaid_$i"}} += $amount;
      } else {
	$form->{fx}{$form->{fxloss_accno}}{$form->{"datepaid_$i"}} += $amount;
      }
      
      $paiddiff = 0;

      # update exchange rate
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
	$form->update_exchangerate($dbh, $form->{currency}, $form->{"datepaid_$i"}, 0, $form->{"exchangerate_$i"});
      }
    }
  }

  # record exchange rate differences and gains/losses
  foreach my $accno (keys %{$form->{fx}}) {
    foreach my $transdate (keys %{ $form->{fx}{$accno} }) {
      if (($form->{fx}{$accno}{$transdate} = $form->round_amount($form->{fx}{$accno}{$transdate}, 2)) != 0) {

	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, cleared, fx_transaction)
	            VALUES ($form->{id}, (SELECT id FROM chart
		                        WHERE accno = '$accno'),
                    $form->{fx}{$accno}{$transdate}, '$transdate', '0', '1')|;
        $dbh->do($query) || $form->dberror($query);
      }
    }
  }


  $amount = $netamount + $tax;

  # set values which could be empty
  $form->{taxincluded} *= 1;
  my $datepaid = ($form->{paid}) ? qq|'$form->{datepaid}'| : "NULL";
  my $duedate = ($form->{duedate}) ? qq|'$form->{duedate}'| : "NULL";
  
  # save AP record
  $query = qq|UPDATE ap set
              invnumber = '$form->{invnumber}',
	      ordnumber = '$form->{ordnumber}',
              transdate = '$form->{invdate}',
              vendor_id = $form->{vendor_id},
              amount = $amount,
              netamount = $netamount,
              paid = $form->{paid},
	      datepaid = $datepaid,
	      duedate = $duedate,
	      invoice = '1',
	      taxincluded = '$form->{taxincluded}',
	      notes = '$form->{notes}',
	      curr = '$form->{currency}'
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # add shipto
  $form->{name} = $form->{vendor};
  $form->{name} =~ s/--$form->{vendor_id}//;
  $form->add_shipto($dbh, $form->{id});
  
  # delete zero entries
  $query = qq|DELETE FROM acc_trans
              WHERE amount = 0|;
  $dbh->do($query) || $form->dberror($query);
 
  my $rc = $dbh->commit;
  $dbh->disconnect;
  $rc;
  
}



sub reverse_invoice {
  my ($dbh, $form) = @_;
  
  # reverse inventory items
  my $query = qq|SELECT i.parts_id, p.inventory_accno_id, p.expense_accno_id,
                 i.qty, i.allocated, i.sellprice
                 FROM invoice i, parts p
		 WHERE i.parts_id = p.id
                 AND i.trans_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $netamount = 0;
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $netamount += $form->round_amount($ref->{sellprice} * $ref->{qty} * -1, 2);

    if ($ref->{inventory_accno_id}) {
      # update onhand
      $form->update_balance($dbh,
			    "parts",
			    "onhand",
			    qq|id = $ref->{parts_id}|,
			    $ref->{qty});
 
      # if $ref->{allocated} > 0 than we sold that many items
      if ($ref->{allocated} > 0) {

	# get references for sold items
	$query = qq|SELECT i.id, i.trans_id, i.allocated, a.transdate
	            FROM invoice i, ar a
		    WHERE i.parts_id = $ref->{parts_id}
		    AND i.allocated < 0
		    AND i.trans_id = a.id
		    ORDER BY transdate DESC|;
	my $sth = $dbh->prepare($query);
	$sth->execute || $form->dberror($query);

	while (my $pthref = $sth->fetchrow_hashref(NAME_lc)) {
	  my $qty = $ref->{allocated};
	  if (($ref->{allocated} + $pthref->{allocated}) > 0) {
	    $qty = $pthref->{allocated} * -1;
	  }

	  my $amount = $form->round_amount($ref->{sellprice} * $qty, 2);
	  
	  #adjust allocated
	  $form->update_balance($dbh,
				"invoice",
				"allocated",
				qq|id = $pthref->{id}|,
				$qty);
	  
	  $form->update_balance($dbh,
				"acc_trans",
				"amount",
				qq|trans_id = $pthref->{trans_id} AND chart_id = $ref->{expense_accno_id} AND transdate = '$pthref->{transdate}'|,
				$amount);
		      
	  $form->update_balance($dbh,
				"acc_trans",
				"amount",
				qq|trans_id = $pthref->{trans_id} AND chart_id = $ref->{inventory_accno_id} AND transdate = '$pthref->{transdate}'|,
				$amount * -1);

	  last if (($ref->{allocated} -= $qty) <= 0);
	}
	$sth->finish;
      }
    }
  }
  $sth->finish;
  
  # delete acc_trans
  $query = qq|DELETE FROM acc_trans
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete invoice entries
  $query = qq|DELETE FROM invoice
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM shipto
              WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
} 



sub delete_invoice {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  # check for other foreign currency transactions
  $form->delete_exchangerate($dbh) if ($form->{currency} ne $form->{defaultcurrency});

  &reverse_invoice($dbh, $form);
  
  # delete zero entries
  my $query = qq|DELETE FROM acc_trans
                 WHERE amount = 0|;
  $dbh->do($query) || $form->dberror($query);

  # delete AP record
  my $query = qq|DELETE FROM ap
                 WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}



sub retrieve_invoice {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;

  if ($form->{id}) {
    # get default accounts and last invoice number
    $query = qq|SELECT (SELECT c.accno FROM chart c
                        WHERE d.inventory_accno_id = c.id) AS inventory_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.income_accno_id = c.id) AS income_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.expense_accno_id = c.id) AS expense_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxloss_accno_id = c.id) AS fxloss_accno,
                d.curr AS currencies
	 	FROM defaults d|;
  } else {
    $query = qq|SELECT (SELECT c.accno FROM chart c
                        WHERE d.inventory_accno_id = c.id) AS inventory_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.income_accno_id = c.id) AS income_accno,
                       (SELECT c.accno FROM chart c
		        WHERE d.expense_accno_id = c.id) AS expense_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
		       (SELECT c.accno FROM chart c
		        WHERE d.fxloss_accno_id = c.id) AS fxloss_accno,
                d.ponumber AS invnumber, d.curr AS currencies,
		current_date AS invdate
	 	FROM defaults d|;
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;


  if ($form->{id}) {
    
    # retrieve invoice
    $query = qq|SELECT a.invnumber, a.transdate AS invdate, a.duedate,
                a.ordnumber, a.paid, a.taxincluded, a.notes, a.curr AS currency
		FROM ap a
		WHERE id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

    $form->{exchangerate} = $form->get_exchangerate($dbh, $form->{currency}, $form->{invdate}, "sell");
    
    # get shipto
    $query = qq|SELECT * FROM shipto
                WHERE trans_id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;
    
    # retrieve individual items
    $query = qq|SELECT c1.accno AS inventory_accno,
                       c2.accno AS income_accno,
		       c3.accno AS expense_accno,
		p.partnumber, i.description, i.qty, i.fxsellprice AS sellprice,
		i.parts_id AS id, i.unit, p.bin, i.deliverydate,
		pr.projectnumber,
                i.project_id,
		pg.partsgroup
		FROM invoice i
		JOIN parts p ON (i.parts_id = p.id)
		LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		LEFT JOIN project pr ON (i.project_id = pr.id)
		LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		WHERE trans_id = $form->{id}
		ORDER BY i.id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

      # get tax rates for part
      $query = qq|SELECT c.accno
                  FROM chart c, partstax pt
	          WHERE pt.chart_id = c.id
	          AND pt.parts_id = $ref->{id}|;
      my $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      $ref->{taxaccounts} = "";
      my $taxrate = 0;
      
      while (my $ptref = $sth->fetchrow_hashref(NAME_lc)) {
        $ref->{taxaccounts} .= "$ptref->{accno} ";
        $taxrate += $form->{"$ptref->{accno}_rate"};
      }
      
      $sth->finish;
      chop $ref->{taxaccounts};

      $ref->{qty} *= -1;
      
      push @{ $form->{invoice_details} }, $ref;
      
    }
    
    $sth->finish;
    
  } else {

    # up invoice number by 1
    $form->{invnumber}++;

    # save the new number
    $query = qq|UPDATE defaults
                SET ponumber = '$form->{invnumber}'|;
    $dbh->do($query) || $form->dberror($query);

  }
  
  
  my $rc = $dbh->commit;
  $dbh->disconnect;
  
  $rc;
  
}



sub get_vendor {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  my $dateformat = $myconfig->{dateformat};
  $dateformat .= "yy" if $myconfig->{dateformat} !~ /^y/;

  my $duedate = ($form->{invdate}) ? "to_date('$form->{invdate}', '$dateformat')" : "current_date";

  $form->{vendor_id} *= 1;
  # get vendor
  my $query = qq|SELECT taxincluded, terms, email, cc, bcc,
                 addr1, addr2, addr3, addr4,
                 $duedate + terms AS duedate
                 FROM vendor
	         WHERE id = $form->{vendor_id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;
  
  # get shipto if we do not convert an order or invoice
  if (!$form->{shipto}) {
    map { delete $form->{$_} } qw(shiptoname shiptoaddr1 shiptoaddr2 shiptoaddr3 shiptoaddr4 shiptocontact shiptophone shiptofax shiptoemail);

    $query = qq|SELECT * FROM shipto
                WHERE trans_id = $form->{vendor_id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;
  }
  
  # get taxes for vendor
  $query = qq|SELECT c.accno
              FROM chart c, vendortax v
	      WHERE v.chart_id = c.id
	      AND v.vendor_id = $form->{vendor_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $vendortax = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $vendortax{$ref->{accno}} = 1;
  }
  $sth->finish;


  # get tax rates and description
  $query = qq|SELECT c.accno, c.description, c.link, t.rate
              FROM chart c, tax t
              WHERE c.id = t.chart_id
	      AND c.link LIKE '%CT_tax%'
	      ORDER BY accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{taxaccounts} = "";
  $form->{taxpart} = "";
  $form->{taxservice} = "";
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    if ($vendortax{$ref->{accno}}) {
      $form->{"$ref->{accno}_rate"} = $ref->{rate};
      $form->{"$ref->{accno}_description"} = $ref->{description};
      $form->{taxaccounts} .= "$ref->{accno} ";
    }
    
    foreach my $item (split /:/, $ref->{link}) {
      if ($item =~ /IC_taxpart/) {
	$form->{taxpart} .= "$ref->{accno} ";
      }
      
      if ($item =~ /IC_taxservice/) {
	$form->{taxservice} .= "$ref->{accno} ";
      }
    }
  }
  $sth->finish;
  chop $form->{taxaccounts};
  chop $form->{taxpart};
  chop $form->{taxservice};

  if (!$form->{id} && $form->{type} !~ /_order/) {
    # setup last accounts used
    $query = qq|SELECT c.accno, c.description, c.link, c.category
                FROM chart c
		JOIN acc_trans ac ON (ac.chart_id = c.id)
		JOIN ap a ON (a.id = ac.trans_id)
		WHERE a.vendor_id = $form->{vendor_id}
		AND NOT (c.link LIKE '%_tax%' OR c.link LIKE '%_paid%')
		AND a.id IN (SELECT max(id) FROM ap
		             WHERE vendor_id = $form->{vendor_id})|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my $i = 0;
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      if ($ref->{category} eq 'E') {
	$i++;
	$form->{"AP_amount_$i"} = "$ref->{accno}--$ref->{description}";
      }
      if ($ref->{category} eq 'L') {
	$form->{AP} = $form->{AP_1} = "$ref->{accno}--$ref->{description}";
      }
    }
    $sth->finish;
    $form->{rowcount} = $i if ($i && !$form->{type});
  }

  $dbh->disconnect;
  
}


sub retrieve_item {
  my ($self, $myconfig, $form) = @_;

  my $i = $form->{rowcount};
  my $var;
  
  # don't include assemblies or obsolete parts
  my $where = "NOT p.assembly = '1' AND NOT p.obsolete = '1'";
  
  if ($form->{"partnumber_$i"}) {
    $var = $form->like(lc $form->{"partnumber_$i"});
    $where .= " AND lower(p.partnumber) LIKE '$var'";
  }
  
  if ($form->{"description_$i"}) {
    $var = $form->like(lc $form->{"description_$i"});
    $where .= " AND lower(p.description) LIKE '$var'";
  }

  if ($form->{"partsgroup_$i"}) {
    $var = $form->like(lc $form->{"partsgroup_$i"});
    $where .= " AND lower(pg.partsgroup) LIKE '$var'";
  }

  if ($form->{"description_$i"}) {
    $where .= " ORDER BY description";
  } else {
    $where .= " ORDER BY partnumber";
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT p.id, p.partnumber, p.description,
                 c1.accno AS inventory_accno,
		 c2.accno AS income_accno,
		 c3.accno AS expense_accno,
		 pg.partsgroup
                 FROM parts p
		 LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		 LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		 LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		 LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
	         WHERE $where|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    # get tax rates for part
    $query = qq|SELECT c.accno
                FROM chart c
		JOIN partstax pt ON (pt.chart_id = c.id)
		WHERE pt.parts_id = $ref->{id}|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref->{taxaccounts} = "";
    while (my $ptref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{taxaccounts} .= "$ptref->{accno} ";
    }
    $sth->finish;
    chop $ref->{taxaccounts};
    
    push @{ $form->{item_list} }, $ref;
  }
  
  $sth->finish;
  $dbh->disconnect;
  
}



sub vendor_details {
  my ($self, $myconfig, $form) = @_;
      
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get rest for the vendor
  my $query = qq|SELECT vendornumber, name, addr1, addr2, addr3, addr4,
                 contact, phone as vendorphone, fax as vendorfax, vendornumber
                 FROM vendor
                 WHERE id = $form->{vendor_id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;
  $dbh->disconnect;

}


sub item_links {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT accno, description, link
	         FROM chart
	         WHERE link LIKE '%IC%'
		 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $key (split(/:/, $ref->{link})) {
      if ($key =~ /IC/) {
        push @{ $form->{IC_links}{$key} }, { accno => $ref->{accno},
                                       description => $ref->{description} };
      }
    }
  }

  $sth->finish;
}

1;

