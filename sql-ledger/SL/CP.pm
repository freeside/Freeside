#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2003
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
# Check and receipt printing payment module backend routines
# Number to text conversion routines are in
# locale/{countrycode}/Num2text
#
#======================================================================

package CP;


sub new {
  my ($type, $countrycode) = @_;

  $self = {};

  if ($countrycode) {
    if (-f "locale/$countrycode/Num2text") {
      require "locale/$countrycode/Num2text";
    } else {
      use SL::Num2text;
    }
  } else {
    use SL::Num2text;
  }

  bless $self, $type;

}


sub paymentaccounts {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  
  my $query = qq|SELECT accno, description, link
                 FROM chart
		 WHERE link LIKE '%$form->{ARAP}%'
		 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  $form->{PR}{$form->{ARAP}} = ();
  $form->{PR}{"$form->{ARAP}_paid"} = ();
  
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    foreach my $item (split /:/, $ref->{link}) {
      if ($item eq $form->{ARAP}) {
	push @{ $form->{PR}{$form->{ARAP}} }, $ref;
      }
      if ($item eq "$form->{ARAP}_paid") {
	push @{ $form->{PR}{"$form->{ARAP}_paid"} }, $ref;
      }
    }
  }
  $sth->finish;
  
  # get currencies and closedto
  $query = qq|SELECT curr, closedto, current_date
              FROM defaults|;
  ($form->{currencies}, $form->{closedto}, $form->{datepaid}) = $dbh->selectrow_array($query);

  $dbh->disconnect;

}


sub get_openvc {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my $arap = ($form->{vc} eq 'customer') ? 'ar' : 'ap';
  my $query = qq|SELECT count(*)
                 FROM $form->{vc} ct, $arap a
		 WHERE a.$form->{vc}_id = ct.id
                 AND a.amount != a.paid|;
  my ($count) = $dbh->selectrow_array($query);

  my $sth;
  my $ref;

  # build selection list
  if ($count < $myconfig->{vclimit}) {
    $query = qq|SELECT DISTINCT ct.id, ct.name
                FROM $form->{vc} ct, $arap a
		WHERE a.$form->{vc}_id = ct.id
		AND a.amount != a.paid
		ORDER BY name|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{"all_$form->{vc}"} }, $ref;
    }

    $sth->finish;

  }

  if ($form->{ARAP} eq 'AR') {
    $query = qq|SELECT id, description
                FROM department
		WHERE role = 'P'
		ORDER BY 2|;
  } else {
    $query = qq|SELECT id, description
                FROM department
		ORDER BY 2|;
  }
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_departments} }, $ref;
  }
  $sth->finish;

  # get language codes
  $query = qq|SELECT *
              FROM language
              ORDER BY 2|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  $form->{all_languages} = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{all_languages} }, $ref;
  }
  $sth->finish;

  # get currency for first name
  if ($form->{"all_$form->{vc}"}) {
    $query = qq|SELECT curr FROM $form->{vc}
		WHERE id = $form->{"all_$form->{vc}"}->[0]->{id}|;
    ($form->{currency}) = $dbh->selectrow_array($query);
  }

  $dbh->disconnect;

}


sub get_openinvoices {
  my ($self, $myconfig, $form) = @_;
  
  my $null;
  my $department_id;
 
  # connect to database
  my $dbh = $form->dbconnect($myconfig);
 
  my $where = qq|WHERE $form->{vc}_id = $form->{"$form->{vc}_id"}
                 AND curr = '$form->{currency}'
	         AND amount != paid|;
  
  my ($buysell);
  if ($form->{vc} eq 'customer') {
    $buysell = "buy";
  } else {
    $buysell = "sell";
  }
  
  ($null, $department_id) = split /--/, $form->{department};
  if ($department_id) {
    $where .= qq|
                 AND department_id = $department_id|;
  }

  my $query = qq|SELECT id, invnumber, transdate, amount, paid, curr
	         FROM $form->{arap}
		 $where
		 ORDER BY transdate, invnumber|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    # if this is a foreign currency transaction get exchangerate
    $ref->{exchangerate} = $form->get_exchangerate($dbh, $ref->{curr}, $ref->{transdate}, $buysell) if ($form->{currency} ne $form->{defaultcurrency});
    push @{ $form->{PR} }, $ref;
  }
  
  $sth->finish;
  $dbh->disconnect;

}



sub process_payment {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $sth;
  
  my ($paymentaccno) = split /--/, $form->{account};
  
  # if currency ne defaultcurrency update exchangerate
  if ($form->{currency} ne $form->{defaultcurrency}) {
    $form->{exchangerate} = $form->parse_amount($myconfig, $form->{exchangerate});

    if ($form->{vc} eq 'customer') {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{datepaid}, $form->{exchangerate}, 0);
    } else {
      $form->update_exchangerate($dbh, $form->{currency}, $form->{datepaid}, 0, $form->{exchangerate});
    }
  } else {
    $form->{exchangerate} = 1;
  }

  my $query = qq|SELECT fxgain_accno_id, fxloss_accno_id
                 FROM defaults|;
  my ($fxgain_accno_id, $fxloss_accno_id) = $dbh->selectrow_array($query);

  my ($buysell);
  
  if ($form->{vc} eq 'customer') {
    $buysell = "buy";
  } else {
    $buysell = "sell";
  }

  my $ml;
  my $where;
  
  if ($form->{ARAP} eq 'AR') {
    $ml = 1;
    $where = qq|
		(c.link = 'AR'
		OR c.link LIKE 'AR:%')
		|;
  } else {
    $ml = -1;
    $where = qq|
                (c.link = 'AP'
                OR c.link LIKE '%:AP'
		OR c.link LIKE '%:AP:%')
		|;
  }
  
  my $paymentamount = $form->parse_amount($myconfig, $form->{amount});
  
  my $null;
  ($null, $form->{department_id}) = split /--/, $form->{department};
  $form->{department_id} *= 1;


  # query to retrieve paid amount
  $query = qq|SELECT paid FROM $form->{arap}
              WHERE id = ?
 	      FOR UPDATE|;
  my $pth = $dbh->prepare($query) || $form->dberror($query);

  my %audittrail;
 
  # go through line by line
  for my $i (1 .. $form->{rowcount}) {

    $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
    $form->{"due_$i"} = $form->parse_amount($myconfig, $form->{"due_$i"});
    
    if ($form->{"checked_$i"} && $form->{"paid_$i"}) {

      $paymentamount -= $form->{"paid_$i"};
      
      # get exchangerate for original 
      $query = qq|SELECT $buysell
                  FROM exchangerate e
                  JOIN $form->{arap} a ON (a.transdate = e.transdate)
		  WHERE e.curr = '$form->{currency}'
		  AND a.id = $form->{"id_$i"}|;
      my ($exchangerate) = $dbh->selectrow_array($query);

      $exchangerate = 1 unless $exchangerate;

      $query = qq|SELECT c.id
                  FROM chart c
		  JOIN acc_trans a ON (a.chart_id = c.id)
	  	  WHERE $where
		  AND a.trans_id = $form->{"id_$i"}|;
      my ($id) = $dbh->selectrow_array($query);
     
      $amount = $form->round_amount($form->{"paid_$i"} * $exchangerate, 2);
      
      # add AR/AP
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate,
                  amount)
                  VALUES ($form->{"id_$i"}, $id, '$form->{datepaid}',
		  $amount * $ml)|;
      $dbh->do($query) || $form->dberror($query);
      
      # add payment
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate,
                  amount, source, memo)
                  VALUES ($form->{"id_$i"},
		         (SELECT id FROM chart
		          WHERE accno = '$paymentaccno'),
		  '$form->{datepaid}', $form->{"paid_$i"} * $ml * -1, |
		  .$dbh->quote($form->{source}).qq|, |
		  .$dbh->quote($form->{memo}).qq|)|;
      $dbh->do($query) || $form->dberror($query);

      # add exchangerate difference if currency ne defaultcurrency
      $amount = $form->round_amount($form->{"paid_$i"} * ($form->{exchangerate} - 1), 2);

      if ($amount != 0) {
        # exchangerate difference
	$query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate,
		    amount, cleared, fx_transaction)
		    VALUES ($form->{"id_$i"},
		           (SELECT id FROM chart
			    WHERE accno = '$paymentaccno'),
		  '$form->{datepaid}', $amount * $ml * -1, '0', '1')|;
	$dbh->do($query) || $form->dberror($query);

        # gain/loss
	$amount = $form->round_amount($form->{"paid_$i"} * ($exchangerate - $form->{exchangerate}) * $ml * -1, 2);
	if ($amount != 0) {
	  my $accno_id = ($amount > 0) ? $fxgain_accno_id : $fxloss_accno_id;
	  $query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate,
		      amount, cleared, fx_transaction)
		      VALUES ($form->{"id_$i"}, $accno_id,
		      '$form->{datepaid}', $amount, '0', '1')|;
	  $dbh->do($query) || $form->dberror($query);
	}
      }

      $form->{"paid_$i"} = $form->round_amount($form->{"paid_$i"} * $exchangerate, 2);

      $pth->execute($form->{"id_$i"}) || $form->dberror;
      ($amount) = $pth->fetchrow_array;
      $pth->finish;

      $amount += $form->{"paid_$i"};
		  
      # update AR/AP transaction
      $query = qq|UPDATE $form->{arap} set
		  paid = $amount,
		  datepaid = '$form->{datepaid}'
		  WHERE id = $form->{"id_$i"}|;
      $dbh->do($query) || $form->dberror($query);
      
      %audittrail = ( tablename  => $form->{arap},
                      reference  => $form->{source},
		      formname   => $form->{formname},
		      action     => 'posted',
		      id         => $form->{"id_$i"} );
 
      $form->audittrail($dbh, "", \%audittrail);
      
    }
  }


  # record a AR/AP with a payment
  if ($form->round_amount($paymentamount, 2) != 0) {
    $form->{invnumber} = "";
    OP::overpayment("", $myconfig, $form, $dbh, $paymentamount, $ml, 1);
  }

  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


1;

