#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2002
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
  
  my $query = qq|SELECT accno, description
                 FROM chart
		 WHERE link LIKE '%$form->{arap}_paid%'
		 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{PR} }, $ref;
  }
  $sth->finish;
  
  # get currencies and closedto
  $query = qq|SELECT curr, closedto
              FROM defaults|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  ($form->{currencies}, $form->{closedto}) = $sth->fetchrow_array;
  $sth->finish;

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
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  my ($count) = $sth->fetchrow_array;
  $sth->finish;

  # build selection list
  if ($count < $myconfig->{vclimit}) {
    $query = qq|SELECT DISTINCT ct.id, ct.name
                FROM $form->{vc} ct, $arap a
		WHERE a.$form->{vc}_id = ct.id
		AND a.amount != a.paid
		ORDER BY name|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{"all_$form->{vc}"} }, $ref;
    }

    $sth->finish;

  }

  $dbh->disconnect;

}


sub get_openinvoices {
  my ($self, $myconfig, $form) = @_;

  return unless $form->{"$form->{vc}_id"};

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $where = qq|WHERE $form->{vc}_id = $form->{"$form->{vc}_id"}
                 AND curr = '$form->{currency}'
	         AND NOT amount = paid|;
  
  if ($form->{transdatefrom}) {
    $where .= " AND transdate >= '$form->{transdatefrom}'";
  }
  if ($form->{transdateto}) {
    $where .= " AND transdate <= '$form->{transdateto}'";
  }
  
  my ($arap, $buysell);
  if ($form->{vc} eq 'customer') {
    $arap = "ar";
    $buysell = "buy";
  } else {
    $arap = "ap";
    $buysell = "sell";
  }
  
  my $query = qq|SELECT id, invnumber, transdate, amount, paid, curr
	         FROM $arap
		 $where
		 ORDER BY id|;
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
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my ($fxgain_accno_id, $fxloss_accno_id) = $sth->fetchrow_array;
  $sth->finish;

  my ($ARAP, $arap, $buysell);
  
  if ($form->{vc} eq 'customer') {
    $ARAP = "AR";
    $arap = "ar";
    $buysell = "buy";
  } else {
    $ARAP = "AP";
    $arap = "ap";
    $buysell = "sell";
  }
  
  # go through line by line
  for my $i (1 .. $form->{rowcount}) {

    if ($form->{"paid_$i"}) {

      $form->{"paid_$i"} = $form->parse_amount($myconfig, $form->{"paid_$i"});
      
      # get exchangerate for original 
      $query = qq|SELECT $buysell FROM exchangerate e, $arap a
		  WHERE e.curr = '$form->{currency}'
		  AND a.transdate = e.transdate
		  AND a.id = $form->{"id_$i"}|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      my ($exchangerate) = $sth->fetchrow_array;
      $sth->finish;

      $exchangerate = 1 unless $exchangerate;

      $query = qq|SELECT c.id FROM chart c, acc_trans a
                  WHERE a.chart_id = c.id
	  	  AND c.link = '$ARAP'
		  AND a.trans_id = $form->{"id_$i"}|;
      $sth = $dbh->prepare($query);
      $sth->execute || $form->dberror($query);

      my ($id) = $sth->fetchrow_array;
      $sth->finish;

      my $amount = $form->round_amount($form->{"paid_$i"} * $exchangerate * -1, 2);
      $ml = ($ARAP eq 'AR') ? -1 : 1;
      # add AR/AP
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate, amount)
                  VALUES ($form->{"id_$i"}, $id,
		  '$form->{datepaid}', $amount * $ml)|;
      $dbh->do($query) || $form->dberror($query);
      
      # add payment
      $query = qq|INSERT INTO acc_trans (trans_id, chart_id, transdate, amount,
                  source)
                  VALUES ($form->{"id_$i"},
		         (SELECT id FROM chart
		          WHERE accno = '$paymentaccno'),
		  '$form->{datepaid}', $form->{"paid_$i"} * $ml,
		  '$form->{source}')|;
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
		  '$form->{datepaid}', $amount * $ml, '0', '1')|;
	$dbh->do($query) || $form->dberror($query);

        # gain/loss
        
	$amount = $form->round_amount($form->{"paid_$i"} * ($exchangerate - $form->{exchangerate}) * $ml, 2);
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

      # update AR/AP transaction
      $query = qq|UPDATE $arap set
		  paid = paid + $form->{"paid_$i"},
		  datepaid = '$form->{datepaid}'
		  WHERE id = $form->{"id_$i"}|;
      $dbh->do($query) || $form->dberror($query);
    }
  }
  
  my $rc = $dbh->commit;
  $dbh->disconnect;

  $rc;

}


1;

