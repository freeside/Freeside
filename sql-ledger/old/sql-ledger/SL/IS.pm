#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 1998-2002
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
# Inventory invoicing module
#
#======================================================================

package IS;


sub invoice_details {
  my ($self, $myconfig, $form) = @_;

  $form->{duedate} = $form->{invdate} unless ($form->{duedate});

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT date '$form->{duedate}' - date '$form->{invdate}'
                 AS terms
		 FROM defaults|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{terms}) = $sth->fetchrow_array;
  $sth->finish;

  my $tax = 0;
  my $item;
  my $i;
  my @partsgroup = ();
  my $partsgroup;
  my %oid = ( 'Pg' => 'oid',
              'Oracle' => 'rowid' );
  
  # sort items by partsgroup
  for $i (1 .. $form->{rowcount}) {
    $partsgroup = "";
    if ($form->{"partsgroup_$i"} && $form->{groupitems}) {
      $form->format_string("partsgroup_$i");
      $partsgroup = $form->{"partsgroup_$i"};
    }
    push @partsgroup, [ $i, $partsgroup ];
  }
  
  my $sameitem = "";
  foreach $item (sort { $a->[1] cmp $b->[1] } @partsgroup) {
    $i = $item->[0];

    if ($item->[1] ne $sameitem) {
      push(@{ $form->{description} }, qq|$item->[1]|);
      $sameitem = $item->[1];

      map { push(@{ $form->{$_} }, "") } qw(runningnumber number bin qty unit deliverydate sellprice listprice netprice discount linetotal);
    }
    
    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
    
    if ($form->{"qty_$i"} != 0) {

      # add number, description and qty to $form->{number}, ....
      push(@{ $form->{runningnumber} }, $i);
      push(@{ $form->{number} }, qq|$form->{"partnumber_$i"}|);
      push(@{ $form->{bin} }, qq|$form->{"bin_$i"}|);
      push(@{ $form->{description} }, qq|$form->{"description_$i"}|);
      push(@{ $form->{qty} }, $form->format_amount($myconfig, $form->{"qty_$i"}));
      push(@{ $form->{unit} }, qq|$form->{"unit_$i"}|);
      push(@{ $form->{deliverydate} }, qq|$form->{"deliverydate_$i"}|);
      
      push(@{ $form->{sellprice} }, $form->{"sellprice_$i"});
      
      # listprice
      push(@{ $form->{listprice} }, $form->{"listprice_$i"});

      my $sellprice = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      my ($dec) = ($sellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;
      
      my $discount = $form->round_amount($sellprice * $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100, $decimalplaces);
      
      # keep a netprice as well, (sellprice - discount)
      $form->{"netprice_$i"} = $sellprice - $discount;
      push(@{ $form->{netprice} }, ($form->{"netprice_$i"} != 0) ? $form->format_amount($myconfig, $form->{"netprice_$i"}, $decimalplaces) : " ");

      
      my $linetotal = $form->round_amount($form->{"qty_$i"} * $form->{"netprice_$i"}, 2);

      $discount = ($discount != 0) ? $form->format_amount($myconfig, $discount * -1, $decimalplaces) : " ";
      $linetotal = ($linetotal != 0) ? $linetotal : " ";
      
      push(@{ $form->{discount} }, $discount);

      $form->{total} += $linetotal;

      push(@{ $form->{linetotal} }, $form->format_amount($myconfig, $linetotal, 2));
      
      my $taxrate = 0;
      my ($taxamount, $taxbase);
      
      map { $taxrate += $form->{"${_}_rate"} } split / /, $form->{"taxaccounts_$i"};

      if ($form->{taxincluded}) {
	# calculate tax
	$taxamount = $linetotal * ($taxrate / (1 + $taxrate));
	$taxbase = $linetotal - $taxamount;
      } else {
        $taxamount = $linetotal * $taxrate;
	$taxbase = $linetotal;
      }
      
      if ($taxamount != 0) {
	foreach my $item (split / /, $form->{"taxaccounts_$i"}) {
	  $taxaccounts{$item} += $taxamount * $form->{"${item}_rate"} / $taxrate;
	  $taxbase{$item} += $taxbase;
	}
      }

      if ($form->{"assembly_$i"}) {
	$sameitem = "";
	
        # get parts and push them onto the stack
	my $sortorder = "";
	if ($form->{groupitems}) { 
	  $sortorder = qq|ORDER BY pg.partsgroup, a.$oid{$myconfig->{dbdriver}}|;
	} else {
	  $sortorder = qq|ORDER BY a.$oid{$myconfig->{dbdriver}}|;
	}
	
	$query = qq|SELECT p.partnumber, p.description, p.unit, a.qty,
	            pg.partsgroup
	            FROM assembly a
		    JOIN parts p ON (a.parts_id = p.id)
		    LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		    WHERE a.bom = '1'
		    AND a.id = '$form->{"id_$i"}'
		    $sortorder|;
        $sth = $dbh->prepare($query);
        $sth->execute || $form->dberror($query);

	while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
	  if ($form->{groupitems} && $ref->{partsgroup} ne $sameitem) {
	    map { push(@{ $form->{$_} }, "") } qw(runningnumber number unit qty bin sellprice listprice netprice discount linetotal);
	    $sameitem = ($ref->{partsgroup}) ? $ref->{partsgroup} : "--";
	    push(@{ $form->{description} }, $sameitem);
	  }
	    
	  push(@{ $form->{number} }, qq|$ref->{partnumber}|);
	  push(@{ $form->{description} }, qq|$ref->{description}|);
	  push(@{ $form->{unit} }, qq|$ref->{unit}|);
	  push(@{ $form->{qty} }, $form->format_amount($myconfig, $ref->{qty} * $form->{"qty_$i"}));

          map { push(@{ $form->{$_} }, "") } qw(runningnumber bin sellprice listprice netprice discount linetotal);
	  
	}
	$sth->finish;
      }
      
    }
  }


  foreach my $item (sort keys %taxaccounts) {
    if ($form->round_amount($taxaccounts{$item}, 2) != 0) {
      push(@{ $form->{taxbase} }, $form->format_amount($myconfig, $taxbase{$item}, 2));
      
      $tax += $taxamount = $form->round_amount($taxaccounts{$item}, 2);
      
      push(@{ $form->{tax} }, $form->format_amount($myconfig, $taxamount));
      push(@{ $form->{taxdescription} }, $form->{"${item}_description"});
      push(@{ $form->{taxrate} }, $form->format_amount($myconfig, $form->{"${item}_rate"} * 100));
      push(@{ $form->{taxnumber} }, $form->{"${item}_taxnumber"});
    }
  }
    

  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"}) {
      push(@{ $form->{payment} }, $form->{"paid_$i"});
      my ($accno, $description) = split /--/, $form->{"AR_paid_$i"};
      push(@{ $form->{paymentaccount} }, $description); 
      push(@{ $form->{paymentdate} }, $form->{"datepaid_$i"});
      push(@{ $form->{paymentsource} }, $form->{"source_$i"});

      $form->{paid} += $form->parse_amount($myconfig, $form->{"paid_$i"});
    }
  }
  
  $form->{subtotal} = $form->format_amount($myconfig, $form->{total}, 2);
  $form->{invtotal} = ($form->{taxincluded}) ? $form->{total} : $form->{total} + $tax;
  $form->{total} = $form->format_amount($myconfig, $form->{invtotal} - $form->{paid}, 2);
  $form->{invtotal} = $form->format_amount($myconfig, $form->{invtotal}, 2);

  $form->{paid} = $form->format_amount($myconfig, $form->{paid}, 2);

  # myconfig variables
  map { $form->{$_} = $myconfig->{$_} } (qw(company address tel fax signature businessnumber));
  $form->{username} = $myconfig->{name};

  $dbh->disconnect;
  
}


sub project_description {
  my ($self, $dbh, $id) = @_;

  my $query = qq|SELECT description
                 FROM project
		 WHERE id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($_) = $sth->fetchrow_array;

  $sth->finish;

  $_;

}


sub customer_details {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  # get rest for the customer
  my $query = qq|SELECT customernumber, name, addr1, addr2, addr3, addr4,
	         phone as customerphone, fax as customerfax, contact
	         FROM customer
	         WHERE id = $form->{customer_id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;

  $sth->finish;
  $dbh->disconnect;

}


sub post_invoice {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database, turn off autocommit
  my $dbh = $form->dbconnect_noauto($myconfig);

  my ($query, $sth, $null, $project_id, $deliverydate);
  my $exchangerate = 0;
 
  if ($form->{id}) {

    &reverse_invoice($dbh, $form);

  } else {
    my $uid = time;
    $uid .= $form->{login};
    
    $query = qq|INSERT INTO ar (invnumber, employee_id)
                VALUES ('$uid', (SELECT id FROM employee
		                 WHERE login = '$form->{login}') )|;
    $dbh->do($query) || $form->dberror($query);

    $query = qq|SELECT id FROM ar
                WHERE invnumber = '$uid'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    ($form->{id}) = $sth->fetchrow_array;
    $sth->finish;
  }


  map { $form->{$_} =~ s/'/''/g } (qw(invnumber shippingpoint notes message));

  my ($netamount, $invoicediff) = (0, 0);
  my ($amount, $linetotal, $lastincomeaccno);

  if ($form->{currency} eq $form->{defaultcurrency}) {
    $form->{exchangerate} = 1;
  } else {
    $exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{transdate}, 'buy');
  }

  $form->{exchangerate} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{exchangerate});
  

  foreach my $i (1 .. $form->{rowcount}) {
    $form->{"qty_$i"} = $form->parse_amount($myconfig, $form->{"qty_$i"});
    
    if ($form->{"qty_$i"} != 0) {

      map { $form->{"${_}_$i"} =~ s/'/''/g } (qw(partnumber description unit));
      
      # undo discount formatting
      $form->{"discount_$i"} = $form->parse_amount($myconfig, $form->{"discount_$i"}) / 100;

      my ($allocated, $taxrate) = (0, 0);
      my $taxamount;
      
      # keep entered selling price
      my $fxsellprice = $form->parse_amount($myconfig, $form->{"sellprice_$i"});
      
      my ($dec) = ($fxsellprice =~ /\.(\d+)/);
      $dec = length $dec;
      my $decimalplaces = ($dec > 2) ? $dec : 2;
      
      # deduct discount
      my $discount = $form->round_amount($fxsellprice * $form->{"discount_$i"}, $decimalplaces);
      $form->{"sellprice_$i"} = $fxsellprice - $discount;
      
      # add tax rates
      map { $taxrate += $form->{"${_}_rate"} } split / /, $form->{"taxaccounts_$i"};

      # round linetotal to 2 decimal places
      $linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2);
      
      if ($form->{taxincluded}) {
	$taxamount = $linetotal * ($taxrate / (1 + $taxrate));
	$form->{"sellprice_$i"} = $form->{"sellprice_$i"} * (1 / (1 + $taxrate));
      } else {
	$taxamount = $linetotal * $taxrate;
      }

      $netamount += $linetotal;
      
      if ($taxamount != 0) {
	map { $form->{amount}{$form->{id}}{$_} += $taxamount * $form->{"${_}_rate"} / $taxrate } split / /, $form->{"taxaccounts_$i"};
      }
    
    
      # add amount to income, $form->{amount}{trans_id}{accno}
      $amount = $form->{"sellprice_$i"} * $form->{"qty_$i"} * $form->{exchangerate};
      
      $linetotal = $form->round_amount($form->{"sellprice_$i"} * $form->{"qty_$i"}, 2) * $form->{exchangerate};
      $linetotal = $form->round_amount($linetotal, 2);
      
      # this is the difference from the inventory
      $invoicediff += ($amount - $linetotal);
		      
      $form->{amount}{$form->{id}}{$form->{"income_accno_$i"}} += $linetotal;
      
      $lastincomeaccno = $form->{"income_accno_$i"};
      

      # adjust and round sellprice
      $form->{"sellprice_$i"} = $form->round_amount($form->{"sellprice_$i"} * $form->{exchangerate}, $decimalplaces);
      
      if ($form->{"inventory_accno_$i"} || $form->{"assembly_$i"}) {
        # adjust parts onhand quantity

        if ($form->{"assembly_$i"}) {
	  # do not update if assembly consists of all services
	  $query = qq|SELECT sum(p.inventory_accno_id)
		      FROM parts p, assembly a
		      WHERE a.parts_id = p.id
		      AND a.id = $form->{"id_$i"}|;
	  $sth = $dbh->prepare($query);
	  $sth->execute || $form->dberror($query);

	  if ($sth->fetchrow_array) {
	    $form->update_balance($dbh,
				  "parts",
				  "onhand",
				  qq|id = $form->{"id_$i"}|,
				  $form->{"qty_$i"} * -1);
	  }
	  $sth->finish;
	   
	  # record assembly item as allocated
	  &process_assembly($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"});
	} else {
	  $form->update_balance($dbh,
				"parts",
				"onhand",
				qq|id = $form->{"id_$i"}|,
				$form->{"qty_$i"} * -1);
	  
	  $allocated = &cogs($dbh, $form, $form->{"id_$i"}, $form->{"qty_$i"});
	}
      }

      $project_id = 'NULL';
      if ($form->{"project_id_$i"}) {
	$project_id = $form->{"project_id_$i"};
      }
      $deliverydate = ($form->{"deliverydate_$i"}) ? qq|'$form->{"deliverydate_$i"}'| : "NULL";

      # save detail record in invoice table
      $query = qq|INSERT INTO invoice (trans_id, parts_id, description, qty,
                  sellprice, fxsellprice, discount, allocated, assemblyitem,
		  unit, deliverydate, project_id)
		  VALUES ($form->{id}, $form->{"id_$i"},
		  '$form->{"description_$i"}', $form->{"qty_$i"},
		  $form->{"sellprice_$i"}, $fxsellprice,
		  $form->{"discount_$i"}, $allocated, 'f',
		  '$form->{"unit_$i"}', $deliverydate, $project_id)|;
      $dbh->do($query) || $form->dberror($query);

    }
  }


  $form->{datepaid} = $form->{invdate};
  
  # total payments, don't move we need it here
  for my $i (1 .. $form->{paidaccounts}) {
    $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
    $form->{paid} += $form->{"paid_$i"};
    $form->{datepaid} = $form->{"datepaid_$i"} if ($form->{"datepaid_$i"});
  }
  
  my ($tax, $diff) = (0, 0);
  
  $netamount = $form->round_amount($netamount, 2);
  
  # figure out rounding errors for total amount vs netamount + taxes
  if ($form->{taxincluded}) {
    
    $amount = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $diff += $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;
    
    foreach my $item (split / /, $form->{taxaccounts}) {
      $amount = $form->{amount}{$form->{id}}{$item} * $form->{exchangerate};
      $form->{amount}{$form->{id}}{$item} = $form->round_amount($amount, 2);
      $tax += $form->{amount}{$form->{id}}{$item};
      $netamount -= $form->{amount}{$form->{id}}{$item};
    }

    $invoicediff += $diff;
    ######## this only applies to tax included
    if ($lastincomeaccno) {
      $form->{amount}{$form->{id}}{$lastincomeaccno} += $invoicediff;
    }

  } else {
    $amount = $form->round_amount($netamount * $form->{exchangerate}, 2);
    $diff = $amount - $netamount * $form->{exchangerate};
    $netamount = $amount;
    foreach my $item (split / /, $form->{taxaccounts}) {
      $form->{amount}{$form->{id}}{$item} = $form->round_amount($form->{amount}{$form->{id}}{$item}, 2);
      $amount = $form->round_amount($form->{amount}{$form->{id}}{$item} * $form->{exchangerate}, 2);
      $diff += $amount - $form->{amount}{$form->{id}}{$item} * $form->{exchangerate};
      $form->{amount}{$form->{id}}{$item} = $form->round_amount($amount, 2);
      $tax += $form->{amount}{$form->{id}}{$item};
    }
  }

  
  $form->{amount}{$form->{id}}{$form->{AR}} = $netamount + $tax;

  if ($form->{paid} != 0) {
    $form->{paid} = $form->round_amount($form->{paid} * $form->{exchangerate} + $diff, 2);
  }
  
  # reverse AR
  $form->{amount}{$form->{id}}{$form->{AR}} *= -1;


  # update exchangerate
  if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
    $form->update_exchangerate($dbh, $form->{currency}, $form->{invdate}, $form->{exchangerate}, 0);
  }
    
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

  # deduct payment differences from diff
  for my $i (1 .. $form->{paidaccounts}) {
    if ($form->{"paid_$i"} != 0) {
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate}, 2);
      $diff -= $amount - $form->{"paid_$i"} * $form->{exchangerate};
    }
  }

  # force AR entry if 0
  $form->{amount}{$form->{id}}{$form->{AR}} = 1 if ($form->{amount}{$form->{id}}{$form->{AR}} == 0);
  
  # record payments and offsetting AR
  for my $i (1 .. $form->{paidaccounts}) {
    
    if ($form->{"paid_$i"} != 0) {
      my ($accno) = split /--/, $form->{"AR_paid_$i"};
      $form->{"datepaid_$i"} = $form->{invdate} unless ($form->{"datepaid_$i"});
      $form->{datepaid} = $form->{"datepaid_$i"};
      
      # record AR
      $amount = $form->round_amount($form->{"paid_$i"} * $form->{exchangerate} + $diff, 2);

      if ($form->{amount}{$form->{id}}{$form->{AR}} != 0) {
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate)
		    VALUES ($form->{id}, (SELECT id FROM chart
					WHERE accno = '$form->{AR}'),
		    $amount, '$form->{"datepaid_$i"}')|;
	$dbh->do($query) || $form->dberror($query);
      }

      # record payment
      $form->{"paid_$i"} *= -1;

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
	$exchangerate = $form->check_exchangerate($myconfig, $form->{currency}, $form->{"datepaid_$i"}, 'buy');
	
	$form->{"exchangerate_$i"} = ($exchangerate) ? $exchangerate : $form->parse_amount($myconfig, $form->{"exchangerate_$i"});
      }
      
      
      # exchangerate difference
      $form->{fx}{$accno}{$form->{"datepaid_$i"}} += $form->{"paid_$i"} * ($form->{"exchangerate_$i"} - 1) + $diff;

      
      # gain/loss
      $amount = $form->{"paid_$i"} * $form->{exchangerate} - $form->{"paid_$i"} * $form->{"exchangerate_$i"};
      if ($amount > 0) {
	$form->{fx}{$form->{fxgain_accno}}{$form->{"datepaid_$i"}} += $amount;
      } else {
	$form->{fx}{$form->{fxloss_accno}}{$form->{"datepaid_$i"}} += $amount;
      }

      $diff = 0;

      # update exchange rate
      if (($form->{currency} ne $form->{defaultcurrency}) && !$exchangerate) {
	$form->update_exchangerate($dbh, $form->{currency}, $form->{"datepaid_$i"}, $form->{"exchangerate_$i"}, 0);
      }
    }
  }

  
  # record exchange rate differences and gains/losses
  foreach my $accno (keys %{$form->{fx}}) {
    foreach my $transdate (keys %{ $form->{fx}{$accno} }) {
      if (($form->{fx}{$accno}{$transdate} = $form->round_amount($form->{fx}{$accno}{$transdate}, 2)) != 0) {

	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, amount,
	            transdate, cleared, fx_transaction)
		    VALUES ($form->{id},
		           (SELECT id FROM chart
		            WHERE accno = '$accno'),
		    $form->{fx}{$accno}{$transdate}, '$transdate', '0', '1')|;
	$dbh->do($query) || $form->dberror($query);
      }
    }
  }
 

  $amount = $netamount + $tax;
  
  # set values which could be empty to 0
  $form->{terms} *= 1;
  $form->{taxincluded} *= 1;
  my $datepaid = ($form->{paid}) ? qq|'$form->{datepaid}'| : "NULL";
  my $duedate = ($form->{duedate}) ? qq|'$form->{duedate}'| : "NULL";

  # fill in subject if there is none
  $form->{subject} = qq|$form->{label} $form->{invnumber}| unless $form->{subject};
  # if there is a message stuff it into the notes
  my $cc = "Cc: $form->{cc}\\r\n" if $form->{cc};
  my $bcc = "Bcc: $form->{bcc}\\r\n" if $form->{bcc};
  $form->{notes} .= qq|\r
\r
[email]\r
To: $form->{email}\r
$cc${bcc}Subject: $form->{subject}\r
\r
Message: $form->{message}\r| if $form->{message};

  # save AR record
  $query = qq|UPDATE ar set
              invnumber = '$form->{invnumber}',
	      ordnumber = '$form->{ordnumber}',
              transdate = '$form->{invdate}',
              customer_id = $form->{customer_id},
              amount = $amount,
              netamount = $netamount,
              paid = $form->{paid},
	      datepaid = $datepaid,
	      duedate = $duedate,
	      invoice = '1',
	      shippingpoint = '$form->{shippingpoint}',
	      terms = $form->{terms},
	      notes = '$form->{notes}',
	      taxincluded = '$form->{taxincluded}',
	      curr = '$form->{currency}'
              WHERE id = $form->{id}
             |;
  $dbh->do($query) || $form->dberror($query);

  # add shipto
  $form->{name} = $form->{customer};
  $form->{name} =~ s/--$form->{customer_id}//;
  $form->add_shipto($dbh, $form->{id});

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;
  
}


sub process_assembly {
  my ($dbh, $form, $id, $totalqty) = @_;

  my $query = qq|SELECT a.parts_id, a.qty, p.assembly,
                 p.partnumber, p.description, p.unit,
                 p.inventory_accno_id, p.income_accno_id,
		 p.expense_accno_id
                 FROM assembly a, parts p
		 WHERE a.parts_id = p.id
		 AND a.id = $id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    my $allocated = 0;
    
    $ref->{inventory_accno_id} *= 1;
    $ref->{expense_accno_id} *= 1;

    map { $ref->{$_} =~ s/'/''/g } (qw(partnumber description unit));
    
    # multiply by number of assemblies
    $ref->{qty} *= $totalqty;
    
    if ($ref->{assembly}) {
      &process_assembly($dbh, $form, $ref->{parts_id}, $ref->{qty});
      next;
    } else {
      if ($ref->{inventory_accno_id}) {
	$allocated = &cogs($dbh, $form, $ref->{parts_id}, $ref->{qty});
      }
    }

    # save detail record for individual assembly item in invoice table
    $query = qq|INSERT INTO invoice (trans_id, description, parts_id, qty,
                sellprice, fxsellprice, allocated, assemblyitem, unit)
		VALUES
		($form->{id}, '$ref->{description}',
		$ref->{parts_id}, $ref->{qty}, 0, 0, $allocated, 't',
		'$ref->{unit}')|;
    $dbh->do($query) || $form->dberror($query);
	 
  }

  $sth->finish;

}


sub cogs {
  my ($dbh, $form, $id, $totalqty) = @_;
    
  my $query = qq|SELECT i.id, i.trans_id, i.qty, i.allocated, i.sellprice,
                        (SELECT c.accno FROM chart c
			 WHERE p.inventory_accno_id = c.id)
			 AS inventory_accno,
			(SELECT c.accno FROM chart c
			 WHERE p.expense_accno_id = c.id)
			 AS expense_accno
		  FROM invoice i, parts p
		  WHERE i.parts_id = p.id
		  AND i.parts_id = $id
		  AND (i.qty + i.allocated) < 0
		  ORDER BY trans_id|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $allocated = 0;
  my $qty;
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    if (($qty = (($ref->{qty} * -1) - $ref->{allocated})) > $totalqty) {
      $qty = $totalqty;
    }
    
    $form->update_balance($dbh,
			  "invoice",
			  "allocated",
			  qq|id = $ref->{id}|,
			  $qty);

    # total expenses and inventory
    # sellprice is the cost of the item
    $linetotal = $form->round_amount($ref->{sellprice} * $qty, 2);
    
    # add to expense
    $form->{amount}{$form->{id}}{$ref->{expense_accno}} += -$linetotal;

    # deduct inventory
    $form->{amount}{$form->{id}}{$ref->{inventory_accno}} -= -$linetotal;

    # add allocated
    $allocated += -$qty;
    
    last if (($totalqty -= $qty) <= 0);
  }

  $sth->finish;

  $allocated;
  
}



sub reverse_invoice {
  my ($dbh, $form) = @_;
  
  # reverse inventory items
  my $query = qq|SELECT i.id, i.parts_id, i.qty, i.assemblyitem, p.assembly,
		 p.inventory_accno_id
                 FROM invoice i, parts p
		 WHERE i.parts_id = p.id
		 AND i.trans_id = $form->{id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {

    if ($ref->{inventory_accno_id} || $ref->{assembly}) {

      # if the invoice item is not an assemblyitem adjust parts onhand
      unless ($ref->{assemblyitem}) {
	# adjust onhand in parts table
	$form->update_balance($dbh,
			      "parts",
			      "onhand",
			      qq|id = $ref->{parts_id}|,
			      $ref->{qty});
      }

      # loop if it is an assembly
      next if ($ref->{assembly});
      
      # de-allocated purchases
      $query = qq|SELECT id, trans_id, allocated
                  FROM invoice
		  WHERE parts_id = $ref->{parts_id}
		  AND allocated > 0
		  ORDER BY trans_id DESC|;
      my $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      while (my $inhref = $sth->fetchrow_hashref(NAME_lc)) {
	$qty = $ref->{qty};
	if (($ref->{qty} - $inhref->{allocated}) > 0) {
	  $qty = $inhref->{allocated};
	}
	
	# update invoice
	$form->update_balance($dbh,
			      "invoice",
			      "allocated",
			      qq|id = $inhref->{id}|,
			      $qty * -1);

        last if (($ref->{qty} -= $qty) <= 0);
      }
      $sth->finish;
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
  
  # delete AR record
  my $query = qq|DELETE FROM ar
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
                d.invnumber, d.curr AS currencies, current_date AS invdate
                FROM defaults d|;
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;

  
  if ($form->{id}) {
    
    # retrieve invoice
    $query = qq|SELECT a.invnumber, a.ordnumber, a.transdate AS invdate, a.paid,
                a.shippingpoint, a.terms, a.notes, a.duedate, a.taxincluded,
		a.curr AS currency, (SELECT e.name FROM employee e
		                     WHERE e.id = a.employee_id) AS employee
		FROM ar a
		WHERE a.id = $form->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

    $form->{exchangerate} = $form->get_exchangerate($dbh, $form->{currency}, $form->{invdate}, "buy");

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
                i.description, i.qty, i.fxsellprice AS sellprice,
		i.discount, i.parts_id AS id, i.unit, i.deliverydate,
		pr.projectnumber,
                i.project_id,
		p.partnumber, p.assembly, p.bin,
		pg.partsgroup
		FROM invoice i
		JOIN parts p ON (i.parts_id = p.id)
		LEFT JOIN chart c1 ON (p.inventory_accno_id = c1.id)
		LEFT JOIN chart c2 ON (p.income_accno_id = c2.id)
		LEFT JOIN chart c3 ON (p.expense_accno_id = c3.id)
		LEFT JOIN project pr ON (i.project_id = pr.id)
		LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
		WHERE i.trans_id = $form->{id}
		AND NOT i.assemblyitem = '1'
		ORDER BY i.id|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      # get taxes
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

      push @{ $form->{invoice_details} }, $ref;
    }
    $sth->finish;

  } else {

    $form->{shippingpoint} = $myconfig->{shippingpoint} unless $form->{shippingpoint};

    # up invoice number by 1
    $form->{invnumber}++;

    # save the new number
    $query = qq|UPDATE defaults
                SET invnumber = '$form->{invnumber}'|;
    $dbh->do($query) || $form->dberror($query);

    $form->get_employee($dbh);

  }


  my $rc = $dbh->commit;
  $dbh->disconnect;
  
  $rc;

}


sub get_customer {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $dateformat = $myconfig->{dateformat};
  $dateformat .= "yy" if $myconfig->{dateformat} !~ /^y/;

  my $duedate = ($form->{invdate}) ? "to_date('$form->{invdate}', '$dateformat')" : "current_date";

  $form->{customer_id} *= 1;
  # get customer
  my $query = qq|SELECT c.name AS customer, c.discount, c.creditlimit, c.terms,
                 c.email, c.cc, c.bcc, c.taxincluded,
		 c.addr1, c.addr2, c.addr3, c.addr4,
	         $duedate + c.terms AS duedate
                 FROM customer c
	         WHERE c.id = $form->{customer_id}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $ref = $sth->fetchrow_hashref(NAME_lc);

  map { $form->{$_} = $ref->{$_} } keys %$ref;
  $sth->finish;
  
  $form->{creditremaining} = $form->{creditlimit};
  $query = qq|SELECT SUM(amount - paid)
	      FROM ar
	      WHERE customer_id = $form->{customer_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  ($form->{creditremaining}) -= $sth->fetchrow_array;

  $sth->finish;
  
  $query = qq|SELECT o.amount,
                (SELECT e.buy FROM exchangerate e
		 WHERE e.curr = o.curr
		 AND e.transdate = o.transdate)
	      FROM oe o
	      WHERE o.customer_id = $form->{customer_id}
	      AND o.closed = '0'|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my ($amount, $exch) = $sth->fetchrow_array) {
    $exch = 1 unless $exch;
    $form->{creditremaining} -= $amount * $exch;
  }
  $sth->finish;


  # get shipto if we did not converted an order or invoice
  if (!$form->{shipto}) {
    map { delete $form->{$_} } qw(shiptoname shiptoaddr1 shiptoaddr2 shiptoaddr3 shiptoaddr4 shiptocontact shiptophone shiptofax shiptoemail);

    $query = qq|SELECT * FROM shipto
                WHERE trans_id = $form->{customer_id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $form->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;
  }
      
  # get taxes we charge for this customer
  $query = qq|SELECT c.accno
              FROM chart c, customertax ct
	      WHERE ct.chart_id = c.id
	      AND ct.customer_id = $form->{customer_id}|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  my $customertax = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $customertax{$ref->{accno}} = 1;
  }
  $sth->finish;
    
  # get tax rates and description
  $query = qq|SELECT c.accno, c.description, t.rate, t.taxnumber
	      FROM chart c, tax t
	      WHERE c.id = t.chart_id
	      AND c.link LIKE '%CT_tax%'
	      ORDER BY accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{taxaccounts} = "";
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    if ($customertax{$ref->{accno}}) {
      $form->{"$ref->{accno}_rate"} = $ref->{rate};
      $form->{"$ref->{accno}_description"} = $ref->{description};
      $form->{"$ref->{accno}_taxnumber"} = $ref->{taxnumber};
      $form->{taxaccounts} .= "$ref->{accno} ";
    }
  }
  $sth->finish;
  chop $form->{taxaccounts};

  # setup last accounts used for this customer
  if (!$form->{id} && $form->{type} !~ /_order/) {
    $query = qq|SELECT c.accno, c.description, c.link, c.category
                FROM chart c
		JOIN acc_trans ac ON (ac.chart_id = c.id)
		JOIN ar a ON (a.id = ac.trans_id)
		WHERE a.customer_id = $form->{customer_id}
		AND NOT (c.link LIKE '%_tax%' OR c.link LIKE '%_paid%')
		AND a.id IN (SELECT max(id) FROM ar
		             WHERE customer_id = $form->{customer_id})|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my $i = 0;
    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      if ($ref->{category} eq 'I') {
	$i++;
	$form->{"AR_amount_$i"} = "$ref->{accno}--$ref->{description}";
      }
      if ($ref->{category} eq 'A') {
	$form->{AR} = $form->{AR_1} = "$ref->{accno}--$ref->{description}";
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
  my $where = "NOT obsolete = '1'";

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

  my $query = qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
                        p.listprice,
			c1.accno AS inventory_accno,
			c2.accno AS income_accno,
			c3.accno AS expense_accno,
		 p.unit, p.assembly, p.bin, p.onhand, p.makemodel,
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

    # get taxes for part
    $query = qq|SELECT c.accno
                FROM chart c
		JOIN partstax pt ON (c.id = pt.chart_id)
		WHERE pt.parts_id = $ref->{id}|;
    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    $ref->{taxaccounts} = "";
    while (my $ptref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{taxaccounts} .= "$ptref->{accno} ";
    }
    $sth->finish;
    chop $ref->{taxaccounts};

    # get makemodel
    if ($ref->{makemodel}) {
      $query = qq|SELECT name
		  FROM makemodel
		  WHERE parts_id = $ref->{id}|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);
      
      $ref->{makemodel} = "";
      while (my $ptref = $sth->fetchrow_hashref(NAME_lc)) {
	$ref->{makemodel} .= "$ptref->{name}:";
      }
      $sth->finish;
      chop $ref->{makemodel};
    }

    push @{ $form->{item_list} }, $ref;

  }
  
  $sth->finish;
  $dbh->disconnect;
  
}


1;

