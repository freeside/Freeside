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
# Accounts Receivable module backend routines
#
#======================================================================

package AR;


sub post_transaction {
  my ($self, $myconfig, $form) = @_;

  my $null;
  my $taxrate;
  my $amount;
  my $tax;
  my $diff;
  my $exchangerate = 0;
  my $i;

  # split and store id numbers in link accounts
  map { ($form->{AR_amounts}{"amount_$_"}) = split(/--/, $form->{"AR_amount_$_"}) } (1 .. $form->{rowcount});
  ($form->{AR_amounts}{receivables}) = split(/--/, $form->{AR});
  
  ($null, $form->{department_id}) = split(/--/, $form->{department});
  $form->{department_id} *= 1;
 
  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, 'buy');

    $form->{exchangerate} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{exchangerate}); 
  }

  for $i (1 .. $form->{rowcount}) {
    $form->{"amount_$i"} = $form->round_amount($form->parse_amount($myconfig, $form->{"amount_$i"}) * $form->{exchangerate}, 2);
    
    $form->{netamount} += $form->{"amount_$i"};

  }
  
  
  # taxincluded doesn't make sense if there is no amount
  $form->{taxincluded} = 0 if ($form->{netamount} == 0);

  foreach my $item (split / /, $form->{taxaccounts}) {
    $form->{AR_amounts}{"tax_$item"} = $item;

    $form->{"tax_$item"} = $form->round_amount($form->parse_amount($myconfig, $form->{"tax_$item"}) * $form->{exchangerate}, 2);
    $form->{tax} += $form->{"tax_$item"};
  }

  # adjust paidaccounts if there is no date in the last row
  $form->{paidaccounts}-- unless ($form->{"datepaid_$form->{paidaccounts}"});

  $form->{paid} = 0;
  # add payments
  for $i (1 .. $form->{paidaccounts}) {
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
  
  # connect to database
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $query;
  my $sth;
  
  ($null, $form->{employee_id}) = split /--/, $form->{employee};
  unless ($form->{employee_id}) {
    ($form->{employee}, $form->{employee_id}) = $form->get_employee($dbh); 
  }
  
  # if we have an id delete old records
  if ($form->{id}) {

    # delete detail records
    $query = qq|DELETE FROM acc_trans WHERE trans_id = $form->{id}|;
    $dbh->do($query) || $form->dberror($query);
    
  } else {
    my $uid = time;
    $uid .= $form->{login};

    $query = qq|INSERT INTO ar (invnumber)
                VALUES ('$uid')|;
    $dbh->do($query) || $form->dberror($query);
    
    $query = qq|SELECT id FROM ar
                WHERE invnumber = '$uid'|;
    ($form->{id}) = $dbh->selectrow_array($query);
  }

  
  # record last payment date in ar table
  $form->{datepaid} = $form->{transdate} unless $form->{datepaid};
  my $datepaid = ($form->{paid} != 0) ? qq|'$form->{datepaid}'| : 'NULL';

  $query = qq|UPDATE ar set
	      invnumber = |.$dbh->quote($form->{invnumber}).qq|,
	      ordnumber = |.$dbh->quote($form->{ordnumber}).qq|,
	      transdate = '$form->{transdate}',
	      customer_id = $form->{customer_id},
	      taxincluded = '$form->{taxincluded}',
	      amount = $form->{amount},
	      duedate = '$form->{duedate}',
	      paid = $form->{paid},
	      datepaid = $datepaid,
	      netamount = $form->{netamount},
	      curr = '$form->{currency}',
	      notes = |.$dbh->quote($form->{notes}).qq|,
	      department_id = $form->{department_id},
	      employee_id = $form->{employee_id}
	      WHERE id = $form->{id}|;
  $dbh->do($query) || $form->dberror($query);

  
  # amount for AR account
  $form->{receivables} = $form->{amount} * -1;
  

  # update exchangerate
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{transdate}, $form->{exchangerate}, 0);
  }
  
  # add individual transactions for AR, amount and taxes
  foreach my $item (keys %{ $form->{AR_amounts} }) {
    
    if ($form->{$item} != 0) {
      
      $project_id = 'NULL';
      if ($item =~ /amount_/) {
	if ($form->{"projectnumber_$'"}) {
	  ($null, $project_id) = split /--/, $form->{"projectnumber_$'"};
	}
      }
      
      # insert detail records in acc_trans
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount, transdate,
                                         project_id)
		  VALUES ($form->{id}, (SELECT id FROM chart
		                        WHERE accno = '$form->{AR_amounts}{$item}'),
		  $form->{$item}, '$form->{transdate}', $project_id)|;
      $dbh->do($query) || $form->dberror($query);
    }
  }

  if ($form->{amount} == 0) {
    $form->{receivables} = $form->{paid};
    $form->{receivables} -= $form->{paid_1} if $form->{amount_1} != 0;
  }

  # add paid transactions
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {
      
       ($form->{AR_amounts}{"paid_$i"}) = split(/--/, $form->{"AR_paid_$i"});
      $form->{"datepaid_$i"} = $form->{transdate} unless ($form->{"datepaid_$i"});
     
      $exchangerate = 0;
      if ($form->{currency} eq $form->{defaultcurrency}) {
	$form->{"exchangerate_$i"} = 1;
      } else {
	$exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy');
	
	$form->{"exchangerate_$i"} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{"exchangerate_$i"}); 
      }
      
     
      # if there is no amount
      if ($form->{amount} == 0 && $form->{netamount} == 0) {
	$form->{exchangerate} = $form->{"exchangerate_$i"};
      }
      
      # receivables amount
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, 2);
      
      if ($form->{receivables} != 0) {
	# add receivable
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate)
		    VALUES ($form->{id},
		           (SELECT id FROM chart
			    WHERE accno = '$form->{AR_amounts}{receivables}'),
		    $amount, '$form->{"datepaid_$i"}')|;
	$dbh->do($query) || $form->dberror($query);
      }
      $form->{receivables} = $amount;
      
      if ($form->{"paid_$i"} != 0) {
	# add payment
	$amount = $form->{"paid_$i"} * -1;
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		    transdate, source, memo)
		    VALUES ($form->{id},
			   (SELECT id FROM chart
			    WHERE accno = '$form->{AR_amounts}{"paid_$i"}'),
		    $amount, '$form->{"datepaid_$i"}', |
		    .$dbh->quote($form->{"source_$i"}).qq|, |
		    .$dbh->quote($form->{"memo_$i"}).qq|)|;
	$dbh->do($query) || $form->dberror($query);
	
	
	# exchangerate difference for payment
	$amount = $form->round_amount($form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1) * -1, 2);
	  
	if ($amount != 0) {
	  $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		      transdate, fx_transaction, cleared)
		      VALUES ($form->{id},
			     (SELECT id FROM chart
			      WHERE accno = '$form->{AR_amounts}{"paid_$i"}'),
		      $amount, '$form->{"datepaid_$i"}', '1', '0')|;
	  $dbh->do($query) || $form->dberror($query);
	}
	  
	# exchangerate gain/loss
	$amount = $form->round_amount($form->{"paid_$i"} * ($form->{exchangerate} - $form->{"exchangerate_$i"}) * -1, 2);
	
	if ($amount != 0) {
	  $accno = ($amount > 0) ? $form->{fxgain_accno} : $form->{fxloss_accno};
	  $query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
		      transdate, fx_transaction, cleared)
		      VALUES ($form->{id}, (SELECT id FROM chart
					    WHERE accno = '$accno'),
		      $amount, '$form->{"datepaid_$i"}', '1', '0')|;
	  $dbh->do($query) || $form->dberror($query);
	}
      }
      
      # update exchangerate record
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
	$form->update_exchangerate($dbh, $form->{currency}, $form->{"datepaid_$i"}, $form->{"exchangerate_$i"}, 0);
      }
    }
  }

  # save printed and queued
  $form->save_status($dbh);
  
  my %audittrail = ( tablename  => 'ar',
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
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);
  
  my %audittrail = ( tablename  => 'ar',
                     reference  => $form->{invnumber},
		     formname   => 'transaction',
		     action     => 'deleted',
		     id         => $form->{id} );

  $form->audittrail($dbh, "", \%audittrail);
  
  my $query = qq|DELETE FROM ar WHERE id = $form->{id}|;
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
  
  # commit
  my $rc = $dbh->commit;
  $dbh->disconnect;

  if ($rc) {
    foreach $spoolfile (@spoolfiles) {
      unlink "$spool/$spoolfile" if $spoolfile;
    }
  }
  
  $rc;

}



sub ar_transactions {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $var;
  
  my $paid = "a.paid";
  
  ($form->{transdatefrom}, $form->{transdateto}) = $form->from_to($form->{year}, $form->{month}, $form->{interval}) if $form->{year} && $form->{month};
 
  if ($form->{outstanding}) {
    $paid = qq|SELECT SUM(ac.amount) * -1
               FROM acc_trans ac
	       JOIN chart c ON (c.id = ac.chart_id)
	       WHERE ac.trans_id = a.id
	       AND (c.link LIKE '%AR_paid%' OR c.link = '')|;
    $paid .= qq|
               AND ac.transdate <= '$form->{transdateto}'| if $form->{transdateto};
  }

  my $query = qq|SELECT a.id, a.invnumber, a.ordnumber, a.transdate,
                 a.duedate, a.netamount, a.amount, ($paid) AS paid,
		 a.invoice, a.datepaid, a.terms, a.notes,
		 a.shipvia, a.shippingpoint, e.name AS employee, c.name,
		 a.customer_id, a.till, m.name AS manager, a.curr,
		 ex.buy AS exchangerate
	         FROM ar a
	      JOIN customer c ON (a.customer_id = c.id)
	      LEFT JOIN employee e ON (a.employee_id = e.id)
	      LEFT JOIN employee m ON (e.managerid = m.id)
	      LEFT JOIN exchangerate ex ON (ex.curr = a.curr
	                                    AND ex.transdate = a.transdate)
	      |;

  my %ordinal = ( 'id' => 1,
                  'invnumber' => 2,
		  'ordnumber' => 3,
		  'transdate' => 4,
		  'duedate' => 5,
		  'datepaid' => 10,
		  'shipvia' => 13,
		  'shippingpoint' => 14,
		  'employee' => 15,
		  'name' => 16,
		  'manager' => 19,
		  'curr' => 20
		);

  
  my @a = (transdate, invnumber, name);
  push @a, "employee" if $form->{l_employee};
  push @a, "manager" if $form->{l_manager};
  my $sortorder = $form->sort_order(\@a, \%ordinal);
  
  my $where = "1 = 1";
  if ($form->{customer_id}) {
    $where .= " AND a.customer_id = $form->{customer_id}";
  } else {
    if ($form->{customer}) {
      $var = $form->like(lc $form->{customer});
      $where .= " AND lower(c.name) LIKE '$var'";
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
  if ($form->{shipvia}) {
    $var = $form->like(lc $form->{shipvia});
    $where .= " AND lower(a.shipvia) LIKE '$var'";
  }
  if ($form->{notes}) {
    $var = $form->like(lc $form->{notes});
    $where .= " AND lower(a.notes) LIKE '$var'";
  }
 
  $where .= " AND a.transdate >= '$form->{transdatefrom}'" if $form->{transdatefrom};
  $where .= " AND a.transdate <= '$form->{transdateto}'" if $form->{transdateto};
  if ($form->{open} || $form->{closed}) {
    unless ($form->{open} && $form->{closed}) {
      $where .= " AND a.amount != a.paid" if ($form->{open});
      $where .= " AND a.amount = a.paid" if ($form->{closed});
    }
  }

  if ($form->{till}) {
    $where .= " AND a.invoice = '1'
                AND NOT a.till IS NULL";
    if ($myconfig->{role} eq 'user') {
      $where .= " AND e.login = '$form->{login}'";
    }
  }

  if ($form->{AR}) {
    my ($accno) = split /--/, $form->{AR};
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

