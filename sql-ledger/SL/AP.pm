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
# Accounts Payables database backend routines
#
#======================================================================


package AP;


sub post_transaction {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);
  
  my ($null, $taxrate, $amount);
  my $exchangerate = 0;
  
  # split and store id numbers in link accounts
  ($form->{AP}{payables}) = split(/--/, $form->{AP});
  map { ($form->{AP}{"amount_$_"}) = split(/--/, $form->{"AP_amount_$_"}) } (1 .. $form->{rowcount});

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, 'sell');

    $form->{exchangerate} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{exchangerate});
  }
  
  # reverse and parse amounts
  for my $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} = $form->round_amount($form->parse_amount($myconfig, $form->{"amount_$i"}) * $form->{exchangerate} * -1, 2);
    $amount += ($form->{"amount_$i"} * -1);
  }

  # this is for ap
  $form->{amount} = $amount;
  
  # taxincluded doesn't make sense if there is no amount
  $form->{taxincluded} = 0 if ($form->{amount} == 0);

  for my $item (split / /, $form->{taxaccounts}) {
    $form->{AP}{"tax_$item"} = $item;

    $amount = $form->round_amount($form->parse_amount($myconfig, $form->{"tax_$item"}), 2);
    
    $form->{"tax_$item"} = $form->round_amount($amount * $form->{exchangerate}, 2) * -1;
    $form->{total_tax} += ($form->{"tax_$item"} * -1);
  }
 

  # adjust paidaccounts if there is no date in the last row
  $form->{paidaccounts}-- unless ($form->{"datepaid_$form->{paidaccounts}"});
  
  $form->{invpaid} = 0;
  # add payments
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} = $form->round_amount($form->parse_amount($myconfig, $form->{"paid_$i"}), 2);
    
    $form->{invpaid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"};

  }
  
  $form->{invpaid} = $form->round_amount($form->{invpaid} * $form->{exchangerate}, 2);
  
  if ($form->{taxincluded} *= 1) {
    for $i (1 .. $form->{rowcount}) {
      $tax = $form->{total_tax} * $form->{"amount_$i"} / $form->{amount};
      $amount = $form->{"amount_$i"} - $tax;
      $form->{"amount_$i"} = $form->round_amount($amount, 2);
      $diff += $amount - $form->{"amount_$i"};
    }

    # deduct taxes from amount
    $form->{amount} -= $form->{total_tax};
    # deduct difference from amount_1
    $form->{amount_1} += $form->round_amount($diff, 2);
  }

  $form->{netamount} = $form->{amount};
  
  # store invoice total, this goes into ap table
  $form->{invtotal} = $form->{amount} + $form->{total_tax};
  
  # amount for total AP
  $form->{payables} = $form->{invtotal};
 

  my ($query, $sth);

  # if we have an id delete old records
  if ($form->{id}) {

    # delete detail records
    $query = qq|DELETE FROM acc_trans WHERE trans_id = $form->{id}|;

    $dbh->do($query) || $form->dberror($query);
    
  } else {
    my $uid = time;
    $uid .= $form->{login};

    $query = qq|INSERT INTO ap (invnumber, employee_id)
                VALUES ('$uid', (SELECT id FROM employee
		                 WHERE login = '$form->{login}') )|;
    $dbh->do($query) || $form->dberror($query);
    
    $query = qq|SELECT id FROM ap
                WHERE invnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
   
  }

  # escape '
  $form->{notes} =~ s/'/''/g;
    
  $form->{datepaid} = $form->{transdate} unless ($form->{datepaid});
  my $datepaid = ($form->{invpaid} != 0) ? qq|'$form->{datepaid}'| : 'NULL';

  $query = qq|UPDATE ap SET
	      invnumber = '$form->{invnumber}',
	      transdate = '$form->{transdate}',
	      ordnumber = '$form->{ordnumber}',
	      vendor_id = $form->{vendor_id},
	      taxincluded = '$form->{taxincluded}',
	      amount = $form->{invtotal},
	      duedate = '$form->{duedate}',
	      paid = $form->{invpaid},
	      datepaid = $datepaid,
	      netamount = $form->{netamount},
	      curr = '$form->{currency}',
	      notes = '$form->{notes}'
	      WHERE id = $form->{id}
	     |;
  $dbh->do($query) || $form->dberror($query);


  # update exchangerate
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, 0, $form->{exchangerate});
  }

  # add individual transactions
  foreach my $item (keys %{ $form->{AP} }) {
    if ($form->{$item} != 0) {
      $project_id = 'NULL';
      if ($item =~ /amount_/) {
	if ($form->{"project_id_$'"} && $form->{"projectnumber_$'"}) { 
	  $project_id = $form->{"project_id_$'"};
	}
      }

      # insert detail records in acc_trans
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                                         project_id)
                  VALUES ($form->{id}, (SELECT id FROM chart
		                        WHERE accno = '$form->{AP}{$item}'),
		  $form->{$item}, '$form->{transdate}', $project_id)|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # if there is no amount but a payment record a payable
  if ($form->{amount} == 0 && $form->{invtotal} == 0) {
    $form->{payables} = $form->{invpaid};
  }
 
  # add paid transactions
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {

      $exchangerate = 0;
      if ($form->{currency} eq $form->{defaultcurrency}) {
	$form->{"exchangerate_$i"} = 1;
      } else {
	$exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell');

	$form->{"exchangerate_$i"} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      }
      
      
      # get paid account
      ($form->{AP}{"paid_$i"}) = split(/--/, $form->{"AP_paid_$i"});
      $form->{"datepaid_$i"} = $form->{transdate} unless ($form->{"datepaid_$i"});

      # if there is no amount and invtotal is zero there is no exchangerate
      if ($form->{amount} == 0 && $form->{invtotal} == 0) {
	$form->{exchangerate} = $form->{"exchangerate_$i"};
      }
      
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate} * -1, 2);
      if ($form->{payables}) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate)
		    VALUES ($form->{id},
		           (SELECT id FROM chart
			    WHERE accno = '$form->{AP}{payables}'),
		    $amount, '$form->{"datepaid_$i"}')|;
	$dbh->do($query) || $form->dberror($query);
      }
      $form->{payables} = $amount;

      # add payment
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
                  transdate, source)
                  VALUES ($form->{id},
		         (SELECT id FROM chart
		          WHERE accno = '$form->{AP}{"paid_$i"}'),
		  $form->{"paid_$i"}, '$form->{"datepaid_$i"}',
		  '$form->{"source_$i"}')|;
      $dbh->do($query) || $form->dberror($query);
      
      # add exchange rate difference
      $amount = $form->round_amount($form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1), 2);
      if ($amount != 0) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate, fx_transaction, cleared)
		    VALUES ($form->{id},
		           (SELECT id FROM chart
			    WHERE accno = '$form->{AP}{"paid_$i"}'),
		    $amount, '$form->{"datepaid_$i"}', '1', '0')|;

	$dbh->do($query) || $form->dberror($query);
      }

      # exchangerate gain/loss
      $amount = $form->round_amount($form->{"paid_$i"} * ($form->{exchangerate} - $form->{"exchangerate_$i"}), 2);

      if ($amount != 0) {
	$accno = ($amount > 0) ? $form->{fxgain_accno} : $form->{fxloss_accno};
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate, fx_transaction, cleared)
		    VALUES ($form->{id}, (SELECT id FROM chart
					  WHERE accno = '$accno'),
		    $amount, '$form->{"datepaid_$i"}', '1', '0')|;
	$dbh->do($query) || $form->dberror($query);
      }

      # update exchange rate record
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
	$form->update_exchangerate($dbh, $form->{currency}, $form->{"datepaid_$i"}, 0, $form->{"exchangerate_$i"});
      }
    }
  }
  
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}




sub delete_transaction {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  # check for other foreign currency transactions
  $form->delete_exchangerate($dbh) if ($form->{currency} ne $form->{defaultcurrency});
  
  my $query = qq|DELETE FROM ap WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM acc_trans WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}




sub ap_transactions {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $incemp = qq|, (SELECT e.name FROM employee e
                   WHERE a.employee_id = e.id) AS employee
		 | if ($form->{l_employee});
		    
  my $query = qq|SELECT a.id, a.invnumber, a.transdate, a.duedate,
                 a.amount, a.paid, a.ordnumber, v.name, a.invoice,
	         a.netamount, a.datepaid, a.notes
		 
		 $incemp
		 
	         FROM ap a, vendor v
	         WHERE a.vendor_id = v.id|;

  if ($form->{vendor_id}) {
    $query .= " AND a.vendor_id = $form->{vendor_id}";
  } else {
    if ($form->{vendor}) {
      my $vendor = $form->like(lc $form->{vendor});
      $query .= " AND lower(v.name) LIKE '$vendor'";
    }
  }
  if ($form->{invnumber}) {
    my $invnumber = $form->like(lc $form->{invnumber});
    $query .= " AND lower(a.invnumber) LIKE '$invnumber'";
  }
  if ($form->{ordnumber}) {
    my $ordnumber = $form->like(lc $form->{ordnumber});
    $query .= " AND lower(a.ordnumber) LIKE '$ordnumber'";
  }
  if ($form->{notes}) {
    my $notes = $form->like(lc $form->{notes});
    $query .= " AND lower(a.notes) LIKE '$notes'";
  }

  $query .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
  $query .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};
  if ($form->{open} || $form->{closed}) {
    unless ($form->{open} && $form->{closed}) {
      $query .= " AND a.amount <> a.paid" if ($form->{open});
      $query .= " AND a.amount = a.paid" if ($form->{closed});
    }
  }

  my @a = (transdate, invnumber, name);
  push @a, "employee" if $self->{l_employee};
  my $sortorder = join ', ', $form->sort_columns(@a);
  $sortorder = $form->{sort} unless $sortorder;

  $query .= " ORDER by $sortorder";

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ap = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{AP} }, $ap;
  }
  
  $sth->finish;
  $dbh->disconnect;
  
}


1;

