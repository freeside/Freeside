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
# chart of accounts
#
# CHANGE LOG:
#   DS. 2000-07-04  Created
#
#======================================================================


package CA;


sub all_accounts {
  my ($self, $myconfig, $form) = @_;

  my $amount = ();
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT accno,
                 SUM(acc_trans.amount) AS amount
                 FROM chart, acc_trans
		 WHERE chart.id = acc_trans.chart_id
		 GROUP BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    $amount{$ref->{accno}} = $ref->{amount}
  }
  $sth->finish;
 
  $query = qq|SELECT accno, description
              FROM gifi|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my $gifi = ();
  while (my ($accno, $description) = $sth->fetchrow_array) {
    $gifi{$accno} = $description;
  }
  $sth->finish;

  $query = qq|SELECT c.id, c.accno, c.description, c.charttype, c.gifi_accno,
              c.category, c.link
              FROM chart c
	      ORDER BY accno|;
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
 
  while (my $ca = $sth->fetchrow_hashref(NAME_lc)) {
    $ca->{amount} = $amount{$ca->{accno}};
    $ca->{gifi_description} = $gifi{$ca->{gifi_accno}};
    if ($ca->{amount} < 0) {
      $ca->{debit} = $ca->{amount} * -1;
    } else {
      $ca->{credit} = $ca->{amount};
    }
    push @{ $form->{CA} }, $ca;
  }

  $sth->finish;
  $dbh->disconnect;

}


sub all_transactions {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get chart_id
  my $query = qq|SELECT id FROM chart
                 WHERE accno = '$form->{accno}'|;
  if ($form->{accounttype} eq 'gifi') {
    $query = qq|SELECT id FROM chart
                WHERE gifi_accno = '$form->{gifi_accno}'|;
  }
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  my @id = ();
  while (my ($id) = $sth->fetchrow_array) {
    push @id, $id;
  }

  $sth->finish;

  my $where = '1 = 1';
  # build WHERE clause from dates if any
  if ($form->{fromdate}) {
    $where .= " AND ac.transdate >= '$form->{fromdate}'";
  }
  if ($form->{todate}) {
    $where .= " AND ac.transdate <= '$form->{todate}'";
  }

  my $sortorder = join ', ', $form->sort_columns(qw(transdate reference description));
  my $false = ($myconfig->{dbdriver} eq 'Pg') ? FALSE : q|'0'|;
  
  # Oracle workaround, use ordinal positions
  my %ordinal = ( transdate => 4,
		  reference => 2,
		  description => 3 );
  map { $sortorder =~ s/$_/$ordinal{$_}/ } keys %ordinal;

   
  if ($form->{accno}) {
    # get category for account
    $query = qq|SELECT category
                FROM chart
		WHERE accno = '$form->{accno}'|;
    $sth = $dbh->prepare($query);

    $sth->execute || $form->dberror($query);
    ($form->{category}) = $sth->fetchrow_array;
    $sth->finish;
    
    if ($form->{fromdate}) {
      # get beginning balance
      $query = qq|SELECT SUM(ac.amount)
		  FROM acc_trans ac, chart c
		  WHERE ac.chart_id = c.id
		  AND c.accno = '$form->{accno}'
		  AND ac.transdate < date '$form->{fromdate}'
		  |;
      $sth = $dbh->prepare($query);

      $sth->execute || $form->dberror($query);
      ($form->{balance}) = $sth->fetchrow_array;
      $sth->finish;
    }
  }
  
  if ($form->{accounttype} eq 'gifi' && $form->{gifi_accno}) {
    # get category for account
    $query = qq|SELECT category
                FROM chart
		WHERE gifi_accno = '$form->{gifi_accno}'|;
    $sth = $dbh->prepare($query);

    $sth->execute || $form->dberror($query);
    ($form->{category}) = $sth->fetchrow_array;
    $sth->finish;
 
    if ($form->{fromdate}) {
      # get beginning balance
      $query = qq|SELECT SUM(ac.amount)
		  FROM acc_trans ac, chart c
		  WHERE ac.chart_id = c.id
		  AND c.gifi_accno = '$form->{gifi_accno}'
		  AND ac.transdate < date '$form->{fromdate}'
		  |;
      $sth = $dbh->prepare($query);

      $sth->execute || $form->dberror($query);
      ($form->{balance}) = $sth->fetchrow_array;
      $sth->finish;
    }
  }
 
  $query = "";
  
  foreach my $id (@id) {
    
    # get all transactions
    $query .= qq|
      SELECT g.id, g.reference, g.description, ac.transdate,
		$false AS invoice,
		ac.amount, 'gl' as charttype
		FROM gl g, acc_trans ac
		WHERE $where
		AND ac.chart_id = $id
		AND ac.trans_id = g.id
      UNION ALL
      SELECT a.id, a.invnumber, c.name, ac.transdate,
		a.invoice,
		ac.amount, 'ar' as charttype
		FROM ar a, acc_trans ac, customer c
		WHERE $where
		AND ac.chart_id = $id
		AND ac.trans_id = a.id
		AND a.customer_id = c.id
      UNION ALL
      SELECT a.id, a.invnumber, v.name, ac.transdate,
		a.invoice,
		ac.amount, 'ap' as charttype
		FROM ap a, acc_trans ac, vendor v
		WHERE $where
		AND ac.chart_id = $id
		AND ac.trans_id = a.id
		AND a.vendor_id = v.id
      UNION ALL|;
  }

  $query =~ s/UNION ALL$//;
  $query .= qq|
      ORDER BY $sortorder|;

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while (my $ca = $sth->fetchrow_hashref(NAME_lc)) {

    # gl
    if ($ca->{charttype} eq "gl") {
      $ca->{module} = "gl";
    }

    # ap
    if ($ca->{charttype} eq "ap") {
      $ca->{module} = ($ca->{invoice}) ? 'ir' : 'ap';
    }

    # ar
    if ($ca->{charttype} eq "ar") {
      $ca->{module} = ($ca->{invoice}) ? 'is' : 'ar';
    }

    if ($ca->{amount} < 0) {
      $ca->{debit} = $ca->{amount} * -1;
      $ca->{credit} = 0;
    } else {
      $ca->{credit} = $ca->{amount};
      $ca->{debit} = 0;
    }

    push @{ $form->{CA} }, $ca;

  }
 
  $sth->finish;
  $dbh->disconnect;

}

1;

