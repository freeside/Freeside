#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2000
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
  
  my $null;
  my $taxrate;
  my $amount;
  my $exchangerate = 0;
  
  # split and store id numbers in link accounts
  map { ($form->{AP_amounts}{"amount_$_"}) = split(/--/, $form->{"AP_amount_$_"}) } (1 .. $form->{rowcount});
  ($form->{AP_amounts}{payables}) = split(/--/, $form->{AP});

  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, 'sell');

    $form->{exchangerate} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{exchangerate});
  }
  
  # reverse and parse amounts
  for my $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} = $form->round_amount($form->parse_amount($myconfig, $form->{"amount_$i"}) * $form->{exchangerate} * -1, 2);
    $form->{netamount} += ($form->{"amount_$i"} * -1);
  }

  
  # taxincluded doesn't make sense if there is no amount
  $form->{taxincluded} = 0 if ($form->{netamount} == 0);

  for my $item (split / /, $form->{taxaccounts}) {
    $form->{AP_amounts}{"tax_$item"} = $item;

    $form->{"tax_$item"} = $form->round_amount($form->parse_amount($myconfig, $form->{"tax_$item"}) * $form->{exchangerate}, 2) * -1;
    $form->{tax} += ($form->{"tax_$item"} * -1);
  }
 

  # adjust paidaccounts if there is no date in the last row
  $form->{paidaccounts}-- unless ($form->{"datepaid_$form->{paidaccounts}"});
  
  $form->{paid} = 0;
  # add payments
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} = $form->round_amount($form->parse_amount($myconfig, $form->{"paid_$i"}), 2);
    
    $form->{paid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"};

  }
  
  
  if ($form->{taxincluded} *= 1) {
    for $i (1 .. $form->{rowcount}) {
      $tax = ($form->{netamount}) ? $form->{tax} * $form->{"amount_$i"} / $form->{netamount} : 0;
      $amount = $form->{"amount_$i"} - $tax;
      $form->{"amount_$i"} = $form->round_amount($amount, 2);
      $diff += $amount - $form->{"amount_$i"};
    }

    $form->{netamount} -= $form->{tax};
    # deduct difference from amount_1
    $form->{amount_1} += $form->round_amount($diff, 2);
  }

  $form->{amount} = $form->{netamount} + $form->{tax};
  $form->{paid} = $form->round_amount($form->{paid} * $form->{exchangerate}, 2);
  
  my $query;
  my $sth;

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
    ($form->{id}) = $dbh->selectrow_array($query);
  }

  $form->{datepaid} = $form->{transdate} unless ($form->{datepaid});
  my $datepaid = ($form->{paid} != 0) ? qq|'$form->{datepaid}'| : 'NULL';

  $query = qq|UPDATE ap SET
	      invnumber = |.$dbh->quote($form->{invnumber}).qq|,
	      transdate = '$form->{transdate}',
	      ordnumber = |.$dbh->quote($form->{ordnumber}).qq|,
	      vendor_id = $form->{vendor_id},
	      taxincluded = '$form->{taxincluded}',
	      amount = $form->{amount},
	      duedate = |.$form->dbquote($form->{duedate}, SQL_DATE).qq|,
	      paid = $form->{paid},
	      datepaid = $datepaid,
	      netamount = $form->{netamount},
	      curr = |.$dbh->quote($form->{currency}).qq|,
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      department_id = $form->{department_id}
	      WHERE id = $form->{id}
	     |;
  $dbh->do($query) || $form->dberror($query);

  # amount for AP account
  $form->{payables} = $form->{amount};
  

  # update exchangerate
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, 0, $form->{exchangerate});
  }

  # add individual transactions
  foreach my $item (keys %{ $form->{AP_amounts} }) {
    
    if ($form->{$item} != 0) {

      $project_id = 'NULL';
      if ($item =~ /amount_/) {
	if ($form->{"projectnumber_$'"}) {
	  ($null, $project_id) = split /--/, $form->{"projectnumber_$'"}
	}
      }

      # insert detail records in acc_trans
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                                         project_id)
                  VALUES ($form->{id}, (SELECT id FROM chart
		         WHERE accno = '$form->{AP_amounts}{$item}'),
		  $form->{$item}, '$form->{transdate}', $project_id)|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  # if there is no amount but a payment record a payable
  if ($form->{amount} == 0) {
    $form->{payables} = $form->{paid};
    $form->{payables} -= $form->{paid_1} if $form->{amount_1} != 0;
  }
 
  # add paid transactions
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {
      
      # get paid account
      ($form->{AP_amounts}{"paid_$i"}) = split(/--/, $form->{"AP_paid_$i"});
      $form->{"datepaid_$i"} = $form->{transdate} unless ($form->{"datepaid_$i"});

      $exchangerate = 0;
      if ($form->{currency} eq $form->{defaultcurrency}) {
	$form->{"exchangerate_$i"} = 1;
      } else {
	$exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'sell');

	$form->{"exchangerate_$i"} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      }
      
      
      # if there is no amount
      if ($form->{amount} == 0 && $form->{netamount} == 0) {
	$form->{exchangerate} = $form->{"exchangerate_$i"};
      }
      
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate} * -1, 2);
      if ($form->{payables} != 0) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate)
		    VALUES ($form->{id},
		        (SELECT id FROM chart
			WHERE accno = '$form->{AP_amounts}{payables}'),
		    $amount, '$form->{"datepaid_$i"}')|;
	$dbh->do($query) || $form->dberror($query);
      }
      $form->{payables} = $amount;

      # add payment
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
                  transdate, source, memo)
                  VALUES ($form->{id},
		      (SELECT id FROM chart
		      WHERE accno = '$form->{AP_amounts}{"paid_$i"}'),
		  $form->{"paid_$i"}, '$form->{"datepaid_$i"}', |
		  .$dbh->quote($form->{"source_$i"}).qq|, |
		  .$dbh->quote($form->{"memo_$i"}).qq|)|;
      $dbh->do($query) || $form->dberror($query);
      
      # add exchange rate difference
      $amount = $form->round_amount($form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1), 2);
      if ($amount != 0) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate, fx_transaction, cleared)
		    VALUES ($form->{id},
		      (SELECT id FROM chart
		      WHERE accno = '$form->{AP_amounts}{"paid_$i"}'),
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

  # save printed and queued
  $form->save_status($dbh);
  
  my %audittrail = ( tablename  => 'ap',
                     reference  => $form->{invnumber},
		     formname   => 'transaction',
		     action     => 'posted',
		     id         => $form->{id} );
  $form->audittrail($dbh, "", \%audittrail);
  
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}




sub delete_transaction {
  my ($self, $myconfig, $form, $spool) = @_;

  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my %audittrail = ( tablename  => 'ap',
                     reference  => $form->{invnumber},
		     formname   => 'transaction',
		     action     => 'deleted',
		     id         => $form->{id} );
  $form->audittrail($dbh, "", \%audittrail);

  my $query = qq|DELETE FROM ap WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  $query = qq|DELETE FROM acc_trans WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  # delete spool files
  $query = qq|SELECT spoolfile FROM status
              WHERE trans_id = $form->{id}
	      AND spoolfile IS NOT NULL|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $spoolfile;
  my @spoolfiles = ();

  while (($spoolfile) = $sth->fetchrow_array) {
    push @spoolfiles, $spoolfile;
  }
  $sth->finish;
  
  $query = qq|DELETE FROM status WHERE trans_id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);
  
  # commit and redirect
  my $rc = $dbh->commit;
  $dbh->disconnect;

  if ($rc) {
    foreach $spoolfile (@spoolfiles) {
      unlink "$spool/$spoolfile" if $spoolfile;
    }
  }

  $rc;

}




sub ap_transactions {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $var;
  
  my $paid = "a.paid";

  if ($form->{outstanding}) {
    $paid = qq|SELECT SUM(ac.amount) 
               FROM acc_trans ac
	       JOIN chart c ON (c.id = ac.chart_id)
	       WHERE ac.trans_id = a.id
	       AND (c.link LIKE '%AP_paid%' OR c.link = '')|;
    $paid .= qq|
               AND ac.transdate <= '$form->{transdateto}'| if $form->{transdateto};
  }
  
  my $query = qq|SELECT a.id, a.invnumber, a.transdate, a.duedate,
                 a.amount, ($paid) AS paid, a.ordnumber, v.name,
		 a.invoice, a.netamount, a.datepaid, a.notes,
		 a.vendor_id, e.name AS employee, m.name AS manager,
		 a.curr, ex.sell AS exchangerate
	         FROM ap a
	      JOIN vendor v ON (a.vendor_id = v.id)
	      LEFT JOIN employee e ON (a.employee_id = e.id)
	      LEFT JOIN employee m ON (e.managerid = m.id)
	      LEFT JOIN exchangerate ex ON (ex.curr = a.curr
	                                    AND ex.transdate = a.transdate)
	      |;

  my %ordinal = ( 'id' => 1,
                  'invnumber' => 2,
                  'transdate' => 3,
		  'duedate' => 4,
		  'ordnumber' => 7,
		  'name' => 8,
		  'datepaid' => 11,
		  'employee' => 14,
		  'manager' => 15,
		  'curr' => 16
		);
  
  my @a = (transdate, invnumber, name);
  push @a, "employee" if $form->{l_employee};
  push @a, "manager" if $form->{l_manager};
  my $sortorder = $form->sort_order(\@a, \%ordinal);
  
  my $where = "1 = 1";
  
  if ($form->{vendor_id}) {
    $where .= " AND a.vendor_id = $form->{vendor_id}";
  } else {
    if ($form->{vendor}) {
      $var = $form->like(lc $form->{vendor});
      $where .= " AND lower(v.name) LIKE '$var'";
    }
  }
  if ($form->{department}) {
    my ($null, $department_id) = split /--/, $form->{department};
    $where .= " AND a.department_id = $department_id";
  }
  if ($form->{invnumber}) {
    $var = $form->like(lc $form->{invnumber});
    $where .= " AND lower(a.invnumber) LIKE '$var'";
    $form->{open} = $form->{closed} = 0;
  }
  if ($form->{ordnumber}) {
    $var = $form->like(lc $form->{ordnumber});
    $where .= " AND lower(a.ordnumber) LIKE '$var'";
    $form->{open} = $form->{closed} = 0;
  }
  if ($form->{notes}) {
    $var = $form->like(lc $form->{notes});
    $where .= " AND lower(a.notes) LIKE '$var'";
  }

  ($form->{transdatefrom}, $form->{transdateto}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};

  $where .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
  $where .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};
  if ($form->{open} || $form->{closed}) {
    unless ($form->{open} && $form->{closed}) {
      $where .= " AND a.amount != a.paid" if ($form->{open});
      $where .= " AND a.amount = a.paid" if ($form->{closed});
    }
  }


  if ($form->{AP}) {
    my ($accno) = split /--/, $form->{AP};
    $where .= qq|
                AND a.id IN (SELECT ac.trans_id
		             FROM acc_trans ac
			     JOIN chart c ON (c.id = ac.chart_id)
			     WHERE a.id = ac.trans_id
			     AND c.accno = '$accno')
		|;
  }

  $query .= "WHERE $where
             ORDER by $sortorder";

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $ref->{exchangerate} = 1 unless $ref->{exchangerate};
    if ($form->{outstanding}) {
      next if $form->round_amount($ref->{amount}, 2) == $form->round_amount($ref->{paid}, 2);
    }
    push @{ $form->{transactions} }, $ref;
  }
  
  $sth->finish;
  $dbh->disconnect;
  
}


1;

