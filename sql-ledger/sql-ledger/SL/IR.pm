#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2000
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors: Jim Rawlings <jim@your-dba.com>
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

  my $query;
  my $sth;
  my $null;
  my $project_id;
  my $exchangerate = 0;
  my $allocated;
  my $taxrate;
  my $taxamount;
  my $taxdiff;
  my $item;

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

      # project
      $project_id = 'NULL';
      if ($form->{"projectnumber_$i"}) {
	($null, $project_id) = split /--/, $form->{"projectnumber_$i"};
      }
 
      # undo discount formatting
      $form->{"discount_$i"} = $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100;
      
      @taxaccounts = split / /, $form->{"taxaccounts_$i"};
      $taxdiff = 0;
      $allocated = 0;
      $taxrate = 0;
      
      # keep entered selling price
      my $fxsellprice = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
          
      my ($dec) = ($fxsellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;
      
      # deduct discount
      my $discount = $form->round_amount($fxsellprice * $form->{"discount_$i"}, $decimalplaces);
      $form->{"sellprice_$i"} = $fxsellprice - $discount;
      
      map { $taxrate += $form->{"${_}_rate"} } @taxaccounts;

      if ($form->{"inventory_accno_$i"}) {

	$linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2);
	
	if ($form->{taxincluded}) {
	  $taxamount = $linetotal * ($taxrate / (1 + $taxrate));
	  $form->{"sellprice_$i"} = $form->{"sellprice_$i"} * (1 / (1 + $taxrate));
	} else {
	  $taxamount = $linetotal * $taxrate;
	}

	$netamount += $linetotal;

	if (@taxaccounts && $form->round_amount($taxamount, 2) == 0) {
	  if ($form->{taxincluded}) {
	    foreach $item (@taxaccounts) {
	      $taxamount = $form->round_amount($linetotal * $form->{"${item}_rate"} / (1 + abs($form->{"${item}_rate"})), 2);
	      $taxdiff += $taxamount;
	      $form->{amount}{$form->{id}}{$item} -= $taxamount;
	    }
	    $form->{amount}{$form->{id}}{$taxaccounts[0]} += $taxdiff;
	  } else {
	    map { $form->{amount}{$form->{id}}{$_} -= $linetotal * $form->{"${_}_rate"} } @taxaccounts;
	  }
	} else {
	    map { $form->{amount}{$form->{id}}{$_} -= $taxamount * $form->{"${_}_rate"} / $taxrate } @taxaccounts;
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
	$form->update_balance($dbh,
	                      "parts",
			      "onhand",
			      qq|id = $form->{"id_$i"}|,
			      $form->{"qty_$i"}) unless $form->{shipped};


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
	
	if (@taxaccounts && $form->round_amount($taxamount, 2) == 0) {
	  if ($form->{taxincluded}) {
	    foreach $item (@taxaccounts) {
	      $taxamount = $form->round_amount($linetotal * $form->{"${item}_rate"} / (1 + abs($form->{"${item}_rate"})), 2);
	      $totaltax += $taxamount;
	      $taxdiff += $taxamount;
	      $form->{amount}{$form->{id}}{$item} -= $taxamount;
	    }
	    $form->{amount}{$form->{id}}{$taxaccounts[0]} += $taxdiff;
	  } else {
	    map { $form->{amount}{$form->{id}}{$_} -= $linetotal * $form->{"${_}_rate"} } @taxaccounts;
	  }
	} else {
	    map { $form->{amount}{$form->{id}}{$_} -= $taxamount * $form->{"${_}_rate"} / $taxrate } @taxaccounts;
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
	
      }

     
      # save detail record in invoice table
      $query = qq|INSERT INTO invoice (trans_id, parts_id, description, qty,
                  sellprice, fxsellprice, discount, allocated,
		  unit, deliverydate, project_id, serialnumber)
		  VALUES ($form->{id}, $form->{"id_$i"}, |
		  .$dbh->quote($form->{"description_$i"}).qq|, |
		  .($form->{"qty_$i"} * -1) .qq|,
		  $form->{"sellprice_$i"}, $fxsellprice,
		  $form->{"discount_$i"}, $allocated, |
		  .$dbh->quote($form->{"unit_$i"}).qq|, |
		  .$form->dbquote($form->{"deliverydate_$i"}, SQL_DATE).qq|,
		  $project_id, |
		  .$dbh->quote($form->{"serialnumber_$i"}).qq|)|;
      $dbh->do($query) || $form->dberror($query);

    }
  }


  $form->{datepaid} = $form->{transdate};

  # all amounts are in natural state, netamount includes the taxes
  # if tax is included, netamount is rounded to 2 decimal places,
  
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

    foreach $item (split / /, $form->{taxaccounts}) {
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
    $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, 0, $form->{exchangerate});
  }
  
  # record acc_trans transactions
  foreach my $trans_id (keys %{$form->{amount}}) {
    foreach my $accno (keys %{ $form->{amount}{$trans_id} }) {
      if (($form->{amount}{$trans_id}{$accno} = $form->round_amount($form->{amount}{$trans_id}{$accno}, 2)) != 0) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, 
		    transdate)
		    VALUES ($trans_id, (SELECT id FROM chart
					 WHERE accno = '$accno'),
		    $form->{amount}{$trans_id}{$accno},
		    '$form->{transdate}')|;
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
      $form->{"datepaid_$i"} = $form->{transdate} unless ($form->{"datepaid_$i"});
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
                  source, memo)
                  VALUES ($form->{id}, (SELECT id FROM chart
		                      WHERE accno = '$accno'),
                  $form->{"paid_$i"}, '$form->{"datepaid_$i"}', |
		  .$dbh->quote($form->{"source_$i"}).qq|, |
		  .$dbh->quote($form->{"memo_$i"}).qq|)|;
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
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate},2) - $form->round_amount($form->{"paid_$i"} * $form->{"exchangerate_$i"},2);
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
  
  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;

  # save AP record
  $query = qq|UPDATE ap set
              invnumber = |.$dbh->quote($form->{invnumber}).qq|,
	      ordnumber = |.$dbh->quote($form->{ordnumber}).qq|,
	      quonumber = |.$dbh->quote($form->{quonumber}).qq|,
              transdate = '$form->{transdate}',
              vendor_id = $form->{vendor_id},
              amount = $amount,
              netamount = $netamount,
              paid = $form->{paid},
	      datepaid = |.$form->dbquote($form->{datepaid}, SQL_DATE).qq|,
	      duedate = |.$form->dbquote($form->{duedate}, SQL_DATE).qq|,
	      invoice = '1',
	      taxincluded = '$form->{taxincluded}',
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      intnotes = |.$dbh->quote($form->{intnotes}).qq|,
	      curr = '$form->{currency}',
	      department_id = $form->{department_id},
	      language_code = '$form->{language_code}'
              WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # add shipto
  $form->{name} = $form->{vendor};
  $form->{name} =~ s/--$form->{vendor_id}//;
  $form->add_shipto($dbh, $form->{id});
  
  my %audittrail = ( tablename  => 'ap',
                     reference  => $form->{invnumber},
		     formname   => $form->{type},
		     action     => 'posted',
		     id         => $form->{id} );
 
  $form->audittrail($dbh, "", \%audittrail);
 
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

          $query = qq|DELETE FROM acc_trans
	              WHERE trans_id = $pthref->{trans_id}
		      AND amount = 0|;
	  $dbh->do($query) || $form->dberror($query);
	  
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
  
  my %audittrail = ( tablename  => 'ap',
                     reference  => $form->{invnumber},
		     formname   => $form->{type},
		     action     => 'deleted',
		     id         => $form->{id} );
 
  $form->audittrail($dbh, "", \%audittrail);

  &reverse_invoice($dbh, $form);
  
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
                d.curr AS currencies,
		current_date AS transdate
	 	FROM defaults d|;
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;


  if ($form->{id}) {
    
    # retrieve invoice
    $query = qq|SELECT a.invnumber, a.transdate, a.duedate,
                a.ordnumber, a.quonumber, a.paid, a.taxincluded, a.notes,
		a.intnotes, a.curr AS currency, a.vendor_id, a.language_code
		FROM ap a
		WHERE id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

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
		p.partnumber, i.description, i.qty, i.fxsellprice, i.sellprice,
		i.parts_id AS id, i.unit, p.bin, i.deliverydate,
		pr.projectnumber,
                i.project_id, i.serialnumber, i.discount,
		pg.partsgroup, p.partsgroup_id, p.partnumber AS sku,
		t.description AS partsgrouptranslation
		FROM invoice i
		JOIN parts p ON (i.parts_id = p.id)
		LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		LEFT JOIN project pr ON (i.project_id = pr.id)
		LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		LEFT JOIN translation t ON (t.trans_id = p.partsgroup_id AND t.language_code = '$form->{language_code}')
		WHERE i.trans_id = $form->{id}
		ORDER BY i.id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    # exchangerate defaults
    &exchangerate_defaults($dbh, $form);

    # price matrix and vendor partnumber
    $query = qq|SELECT partnumber
                FROM partsvendor
		WHERE parts_id = ?
		AND vendor_id = $form->{vendor_id}|;
    my $pmh = $dbh->prepare($query) || $form->dberror($query);

    # tax rates for part
    $query = qq|SELECT c.accno
		FROM chart c
		JOIN partstax pt ON (pt.chart_id = c.id)
		WHERE pt.parts_id = ?|;
    my $tth = $dbh->prepare($query);

    my $ptref;
    my $taxrate;

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

      ($decimalplaces) = ($ref->{fxsellprice} =~ /\.(\d+)/);
      $decimalplaces = length $decimalplaces;
      $decimalplaces = 2 unless $decimalplaces;

      $tth->execute($ref->{id});
      $ref->{taxaccounts} = "";
      $taxrate = 0;
      
      while ($ptref = $tth->fetchrow_hashref(NAME_lc)) {
        $ref->{taxaccounts} .= "$ptref->{accno} ";
        $taxrate += $form->{"$ptref->{accno}_rate"};
      }
      
      $tth->finish;
      chop $ref->{taxaccounts};

      # price matrix
      $ref->{sellprice} = $form->round_amount($ref->{fxsellprice} * $form->{$form->{currency}}, 2);
      &price_matrix($pmh, $ref, $decimalplaces, $form);

      $ref->{sellprice} = $ref->{fxsellprice};
      $ref->{qty} *= -1;

      $ref->{partsgroup} = $ref->{partsgrouptranslation} if $ref->{partsgrouptranslation};
      
      push @{ $form->{invoice_details} }, $ref;
      
    }
    
    $sth->finish;
    
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
  if ($myconfig->{dateformat} !~ /^y/) {
    my @a = split /\W/, $form->{transdate};
    $dateformat .= "yy" if (length $a[2] > 2);
  }

  if ($form->{transdate} !~ /\W/) {
    $dateformat = 'yyyymmdd';
  }

  my $duedate;
  
  if ($myconfig->{dbdriver} eq 'DB2') {
    $duedate = ($form->{transdate}) ? "date('$form->{transdate}') + v.terms DAYS" : "current_date + v.terms DAYS";
  } else {
    $duedate = ($form->{transdate}) ? "to_date('$form->{transdate}', '$dateformat') + v.terms" : "current_date + v.terms";
  }

  $form->{vendor_id} *= 1;
  # get vendor
  my $query = qq|SELECT v.name AS vendor, v.creditlimit, v.terms,
                 v.email, v.cc, v.bcc, v.taxincluded,
		 v.address1, v.address2, v.city, v.state,
		 v.zipcode, v.country, v.curr AS currency, v.language_code,
                 $duedate AS duedate, v.notes AS intnotes,
		 e.name AS employee, e.id AS employee_id
                 FROM vendor v
		 LEFT JOIN employee e ON (e.id = v.employee_id)
	         WHERE v.id = $form->{vendor_id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);
  
  if ($form->{id}) {
    map { delete $ref->{$_} } qw(currency taxincluded employee employee_id intnotes);
  }
  
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

  # if no currency use defaultcurrency
  $form->{currency} = ($form->{currency}) ? $form->{currency} : $form->{defaultcurrency};
  
  $form->{exchangerate} = 0 if $form->{currency} eq $form->{defaultcurrency};
  if ($form->{transdate} && ($form->{currency} ne $form->{defaultcurrency})) {
    $form->{exchangerate} = $form->get_exchangerate($dbh, $form->{currency}, $form->{transdate}, "sell"); 
  }
  $form->{forex} = $form->{exchangerate};

  # if no employee, default to login
  ($form->{employee}, $form->{employee_id}) = $form->get_employee($dbh) unless $form->{employee_id};
  
  $form->{creditremaining} = $form->{creditlimit};
  $query = qq|SELECT SUM(amount - paid)
              FROM ap
	      WHERE vendor_id = $form->{vendor_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{creditremaining}) -= $sth->fetchrow_array;

  $sth->finish;
  
  $query = qq|SELECT o.amount,
                (SELECT e.sell FROM exchangerate e
		 WHERE e.curr = o.curr
		 AND e.transdate = o.transdate)
	      FROM oe o
	      WHERE o.vendor_id = $form->{vendor_id}
	      AND o.quotation = '0'
	      AND o.closed = '0'|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my ($amount, $exch) = $sth->fetchrow_array) {
    $exch = 1 unless $exch;
    $form->{creditremaining} -= $amount * $exch;
  }
  $sth->finish;
    
		
  # get shipto if we do not convert an order or invoice
  if (!$form->{shipto}) {
    map { delete $form->{$_} } qw(shiptoname shiptoaddress1 shiptoaddress2 shiptocity shiptostate shiptozipcode shiptocountry shiptocontact shiptophone shiptofax shiptoemail);

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
              FROM chart c
	      JOIN vendortax v ON (v.chart_id = c.id)
	      WHERE v.vendor_id = $form->{vendor_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $vendortax = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $vendortax{$ref->{accno}} = 1;
  }
  $sth->finish;


  # get tax rates and description
  $query = qq|SELECT c.accno, c.description, c.link, t.rate, t.taxnumber
              FROM chart c
	      JOIN tax t ON (c.id = t.chart_id)
	      WHERE c.link LIKE '%CT_tax%'
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
      $form->{"$ref->{accno}_taxnumber"} = $ref->{taxnumber};
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


  if (!$form->{id} && $form->{type} !~ /_(order|quotation)/) {
    # setup last accounts used
    $query = qq|SELECT c.accno, c.description, c.link, c.category,
                ac.project_id, p.projectnumber, a.department_id,
		d.description AS department
		FROM chart c
		JOIN acc_trans ac ON (ac.chart_id = c.id)
		JOIN ap a ON (a.id = ac.trans_id)
		LEFT JOIN project p ON (ac.project_id = p.id)
		LEFT JOIN department d ON (a.department_id = d.id)
		WHERE a.vendor_id = $form->{vendor_id}
		AND a.id IN (SELECT max(id) FROM ap
			     WHERE vendor_id = $form->{vendor_id})|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);
    
    my $i = 0;
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      $form->{department} = $ref->{department};
      $form->{department_id} = $ref->{department_id};

      if ($ref->{link} =~ /_amount/) {
	$i++;
	$form->{"AP_amount_$i"} = "$ref->{accno}--$ref->{description}";
	$form->{"projectnumber_$i"} = "$ref->{projectnumber}--$ref->{project_id}";
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
  my $null;
  my $var;
  
  # don't include assemblies or obsolete parts
  my $where = "WHERE p.assembly = '0' AND p.obsolete = '0'";
  
  if ($form->{"partnumber_$i"}) {
    $var = $form->like(lc $form->{"partnumber_$i"});
    $where .= " AND lower(p.partnumber) LIKE '$var'";
  }
  
  if ($form->{"description_$i"}) {
    $var = $form->like(lc $form->{"description_$i"});
    if ($form->{language_code}) {
      $where .= " AND lower(t1.description) LIKE '$var'";
    } else {
      $where .= " AND lower(p.description) LIKE '$var'";
    }
  }

  if ($form->{"partsgroup_$i"}) {
    ($null, $var) = split /--/, $form->{"partsgroup_$i"};
    $where .= qq| AND p.partsgroup_id = $var|;
  }
  
  if ($form->{"description_$i"}) {
    $where .= " ORDER BY 3";
  } else {
    $where .= " ORDER BY 2";
  }

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT p.id, p.partnumber, p.description,
                 c1.accno AS inventory_accno,
		 c2.accno AS income_accno,
		 c3.accno AS expense_accno,
		 pg.partsgroup, p.partsgroup_id,
                 p.lastcost AS sellprice, p.unit, p.bin, p.onhand,
		 p.partnumber AS sku, p.weight,
		 t1.description AS translation,
		 t2.description AS grouptranslation
                 FROM parts p
		 LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		 LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		 LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		 LEFT JOIN partsgroup pg ON (pg.id = p.partsgroup_id)
		 LEFT JOIN translation t1 ON (t1.trans_id = p.id AND t1.language_code = '$form->{language_code}')
		 LEFT JOIN translation t2 ON (t2.trans_id = p.partsgroup_id AND t2.language_code = '$form->{language_code}')
	         $where|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  # foreign currency
  &exchangerate_defaults($dbh, $form);

  # taxes
  $query = qq|SELECT c.accno
	      FROM chart c
	      JOIN partstax pt ON (pt.chart_id = c.id)
	      WHERE pt.parts_id = ?|;
  my $tth = $dbh->prepare($query) || $form->dberror($query);

  # price matrix
  $query = qq|SELECT p.*
              FROM partsvendor p
	      WHERE p.parts_id = ?
	      AND vendor_id = $form->{vendor_id}|;
  my $pmh = $dbh->prepare($query) || $form->dberror($query);

  my $ref;
  my $ptref;
  my $decimalplaces;
  
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {

    ($decimalplaces) = ($ref->{sellprice} =~ /\.(\d+)/);
    $decimalplaces = length $decimalplaces;
    $decimalplaces = 2 unless $decimalplaces;
    
    # get taxes for part
    $tth->execute($ref->{id});

    $ref->{taxaccounts} = "";
    while ($ptref = $tth->fetchrow_hashref(NAME_lc)) {
      $ref->{taxaccounts} .= "$ptref->{accno} ";
    }
    $tth->finish;
    chop $ref->{taxaccounts};

    # get vendor price and partnumber
    &price_matrix($pmh, $ref, $decimalplaces, $form, $myconfig);

    $ref->{description} = $ref->{translation} if $ref->{translation};
    $ref->{partsgroup} = $ref->{grouptranslation} if $ref->{grouptranslation};
    
    push @{ $form->{item_list} }, $ref;
    
  }
  
  $sth->finish;
  $dbh->disconnect;
  
}


sub exchangerate_defaults {
  my ($dbh, $form) = @_;

  my $var;
  
  # get default currencies
  my $query = qq|SELECT substr(curr,1,3), curr FROM defaults|;
  my $eth = $dbh->prepare($query) || $form->dberror($query);
  $eth->execute;
  ($form->{defaultcurrency}, $form->{currencies}) = $eth->fetchrow_array;
  $eth->finish;

  $query = qq|SELECT sell
              FROM exchangerate
	      WHERE curr = ?
	      AND transdate = ?|;
  my $eth1 = $dbh->prepare($query) || $form->dberror($query);

  $query = qq~SELECT max(transdate || ' ' || sell || ' ' || curr)
              FROM exchangerate
	      WHERE curr = ?~;
  my $eth2 = $dbh->prepare($query) || $form->dberror($query);

  # get exchange rates for transdate or max
  foreach $var (split /:/, substr($form->{currencies},4)) {
    $eth1->execute($var, $form->{transdate});
    ($form->{$var}) = $eth1->fetchrow_array;
    if (! $form->{$var} ) {
      $eth2->execute($var);

      ($form->{$var}) = $eth2->fetchrow_array;
      ($null, $form->{$var}) = split / /, $form->{$var};
      $form->{$var} = 1 unless $form->{$var};
      $eth2->finish;
    }
    $eth1->finish;
  }

  $form->{$form->{defaultcurrency}} = 1;
  
}


sub price_matrix {
  my ($pmh, $ref, $decimalplaces, $form, $myconfig) = @_;
  
  $pmh->execute($ref->{id});
  my $mref = $pmh->fetchrow_hashref(NAME_lc);
  
  if ($mref->{partnumber}) {
    $ref->{partnumber} = $mref->{partnumber};
  }

  if ($mref->{lastcost}) {
    # do a conversion
    $ref->{sellprice} = $form->round_amount($mref->{lastcost} * $form->{$mref->{curr}}, $decimalplaces);
  }
  $pmh->finish;

  $ref->{sellprice} *= 1;
  
  # add 0:price to matrix
  $ref->{pricematrix} = "0:$ref->{sellprice}";
  
}


sub vendor_details {
  my ($self, $myconfig, $form) = @_;
      
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get rest for the vendor
  my $query = qq|SELECT vendornumber, name, address1, address2, city, state,
                 zipcode, country,
                 contact, phone as vendorphone, fax as vendorfax, vendornumber,
		 taxnumber, sic_code AS sic, iban, bic
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

