#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 1998-2002
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors: Benjamin Lee <benjaminlee@consultant.com>
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
# backend code for reports
#
#======================================================================

package RP;


sub income_statement {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my @categories = qw(I E);
  my $category;

  $form->{decimalplaces} *= 1;

  &get_accounts($dbh, $last_period, $form->{fromdate}, $form->{todate}, $form, \@categories);
  
  # if there are any compare dates
  if ($form->{comparefromdate} || $form->{comparetodate}) {
    $last_period = 1;

    &get_accounts($dbh, $last_period, $form->{comparefromdate}, $form->{comparetodate}, $form, \@categories);
  }  

  
  # disconnect
  $dbh->disconnect;


  # now we got $form->{I}{accno}{ }
  # and $form->{E}{accno}{  }
  
  my %account = ( 'I' => { 'label' => 'income',
                           'labels' => 'income',
			   'ml' => 1 },
		  'E' => { 'label' => 'expense',
		           'labels' => 'expenses',
			   'ml' => -1 }
		);
  
  my $str;
  
  foreach $category (@categories) {
    
    foreach $key (sort keys %{ $form->{$category} }) {
      # push description onto array
      
      $str = ($form->{l_heading}) ? $form->{padding} : "";
      
      if ($form->{$category}{$key}{charttype} eq "A") {
	$str .= ($form->{l_accno}) ? "$form->{$category}{$key}{accno} - $form->{$category}{$key}{description}" : "$form->{$category}{$key}{description}";
      }
      if ($form->{$category}{$key}{charttype} eq "H") {
	if ($account{$category}{subtotal} && $form->{l_subtotal}) {
	  $dash = "- ";
	  push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
	  push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  
	  if ($last_period) {
	    push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  }
	  
	}
	
	$str = "$form->{br}$form->{bold}$form->{$category}{$key}{description}$form->{endbold}";

	$account{$category}{subthis} = $form->{$category}{$key}{this};
	$account{$category}{sublast} = $form->{$category}{$key}{last};
	$account{$category}{subdescription} = $form->{$category}{$key}{description};
	$account{$category}{subtotal} = 1;

	$form->{$category}{$key}{this} = 0;
	$form->{$category}{$key}{last} = 0;

	next unless $form->{l_heading};

	$dash = " ";
      }
      
      push(@{$form->{"$account{$category}{label}_account"}}, $str);
      
      if ($form->{$category}{$key}{charttype} eq 'A') {
	$form->{"total_$account{$category}{labels}_this_period"} += $form->{$category}{$key}{this} * $account{$category}{ml};
	$dash = "- ";
      }
      
      push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{this} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      
      # add amount or - for last period
      if ($last_period) {
	$form->{"total_$account{$category}{labels}_last_period"} += $form->{$category}{$key}{last} * $account{$category}{ml};

	push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig,$form->{$category}{$key}{last} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

    $str = ($form->{l_heading}) ? $form->{padding} : "";
    if ($account{$category}{subtotal} && $form->{l_subtotal}) {
      push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
      push(@{$form->{"$account{$category}{labels}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));

      if ($last_period) {
	push(@{$form->{"$account{$category}{labels}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }
      
  }

  
  # totals for income and expenses
  $form->{total_income_this_period} = $form->round_amount($form->{total_income_this_period}, $form->{decimalplaces});
  $form->{total_expenses_this_period} = $form->round_amount($form->{total_expenses_this_period}, $form->{decimalplaces});

  # total for income/loss
  $form->{total_this_period} = $form->{total_income_this_period} - $form->{total_expenses_this_period};
  
  if ($last_period) {
    # total for income/loss
    $form->{total_last_period} = $form->format_amount($myconfig, $form->{total_income_last_period} - $form->{total_expenses_last_period}, $form->{decimalplaces}, "- ");
    
    # totals for income and expenses for last_period
    $form->{total_income_last_period} = $form->format_amount($myconfig, $form->{total_income_last_period}, $form->{decimalplaces}, "- ");
    $form->{total_expenses_last_period} = $form->format_amount($myconfig, $form->{total_expenses_last_period}, $form->{decimalplaces}, "- ");

  }


  $form->{total_income_this_period} = $form->format_amount($myconfig,$form->{total_income_this_period}, $form->{decimalplaces}, "- ");
  $form->{total_expenses_this_period} = $form->format_amount($myconfig,$form->{total_expenses_this_period}, $form->{decimalplaces}, "- ");
  $form->{total_this_period} = $form->format_amount($myconfig,$form->{total_this_period}, $form->{decimalplaces}, "- ");

}



sub balance_sheet {
  my ($self, $myconfig, $form) = @_;
  
  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $last_period = 0;
  my @categories = qw(A L Q);

  # if there are any dates construct a where
  if ($form->{asofdate}) {
    
    $form->{this_period} = "$form->{asofdate}";
    $form->{period} = "$form->{asofdate}";
    
  }

  $form->{decimalplaces} *= 1;

  &get_accounts($dbh, $last_period, "", $form->{asofdate}, $form, \@categories);
  
  # if there are any compare dates
  if ($form->{compareasofdate}) {

    $last_period = 1;
    &get_accounts($dbh, $last_period, "", $form->{compareasofdate}, $form, \@categories);
  
    $form->{last_period} = "$form->{compareasofdate}";

  }  

  
  # disconnect
  $dbh->disconnect;


  # now we got $form->{A}{accno}{ }    assets
  # and $form->{L}{accno}{ }           liabilities
  # and $form->{Q}{accno}{ }           equity
  # build asset accounts
  
  my $str;
  my $key;
  
  my %account  = ( 'A' => { 'label' => 'asset',
                            'labels' => 'assets',
			    'ml' => -1 },
		   'L' => { 'label' => 'liability',
		            'labels' => 'liabilities',
			    'ml' => 1 },
		   'Q' => { 'label' => 'equity',
		            'labels' => 'equities',
			    'ml' => 1 }
		);	    
			    
  foreach $category (@categories) {

    foreach $key (sort keys %{ $form->{$category} }) {

      $str = ($form->{l_heading}) ? $form->{padding} : "";

      if ($form->{$category}{$key}{charttype} eq "A") {
	$str .= ($form->{l_accno}) ? "$form->{$category}{$key}{accno} - $form->{$category}{$key}{description}" : "$form->{$category}{$key}{description}";
      }
      if ($form->{$category}{$key}{charttype} eq "H") {
	if ($account{$category}{subtotal} && $form->{l_subtotal}) {
	  $dash = "- ";
	  push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
	  push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  
	  if ($last_period) {
	    push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
	  }
	}

	$str = "$form->{bold}$form->{$category}{$key}{description}$form->{endbold}";
	
	$account{$category}{subthis} = $form->{$category}{$key}{this};
	$account{$category}{sublast} = $form->{$category}{$key}{last};
	$account{$category}{subdescription} = $form->{$category}{$key}{description};
	$account{$category}{subtotal} = 1;
	
	$form->{$category}{$key}{this} = 0;
	$form->{$category}{$key}{last} = 0;

	next unless $form->{l_heading};

	$dash = " ";
      }
      
      # push description onto array
      push(@{$form->{"$account{$category}{label}_account"}}, $str);
      
      if ($form->{$category}{$key}{charttype} eq 'A') {
	$form->{"total_$account{$category}{labels}_this_period"} += $form->{$category}{$key}{this} * $account{$category}{ml};
	$dash = "- ";
      }

      push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{this} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      
      if ($last_period) {
	$form->{"total_$account{$category}{labels}_last_period"} += $form->{$category}{$key}{last} * $account{$category}{ml};

	push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $form->{$category}{$key}{last} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

    $str = ($form->{l_heading}) ? $form->{padding} : "";
    if ($account{$category}{subtotal} && $form->{l_subtotal}) {
      push(@{$form->{"$account{$category}{label}_account"}}, "$str$form->{bold}$account{$category}{subdescription}$form->{endbold}");
      push(@{$form->{"$account{$category}{label}_this_period"}}, $form->format_amount($myconfig, $account{$category}{subthis} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      
      if ($last_period) {
	push(@{$form->{"$account{$category}{label}_last_period"}}, $form->format_amount($myconfig, $account{$category}{sublast} * $account{$category}{ml}, $form->{decimalplaces}, $dash));
      }
    }

  }

  
  # totals for assets, liabilities
  $form->{total_assets_this_period} = $form->round_amount($form->{total_assets_this_period}, $form->{decimalplaces});
  $form->{total_liabilities_this_period} = $form->round_amount($form->{total_liabilities_this_period}, $form->{decimalplaces});
  

  # calculate retained earnings
  $form->{earnings_this_period} = $form->{total_assets_this_period} - $form->{total_liabilities_this_period} - $form->{total_equity_this_period};

  push(@{$form->{equity_this_period}}, $form->format_amount($myconfig, $form->{earnings_this_period}, $form->{decimalplaces}, "- "));
  
  $form->{total_equity_this_period} = $form->round_amount($form->{total_equity_this_period} + $form->{earnings_this_period}, $form->{decimalplaces});
  
  # add liability + equity
  $form->{total_this_period} = $form->format_amount($myconfig, $form->{total_liabilities_this_period} + $form->{total_equity_this_period}, $form->{decimalplaces}, "- ");


  if ($last_period) {
    # totals for assets, liabilities
    $form->{total_assets_last_period} = $form->round_amount($form->{total_assets_last_period}, $form->{decimalplaces});
    $form->{total_liabilities_last_period} = $form->round_amount($form->{total_liabilities_last_period}, $form->{decimalplaces});
    

    # calculate retained earnings
    $form->{earnings_last_period} = $form->{total_assets_last_period} - $form->{total_liabilities_last_period} - $form->{total_equity_last_period};

    push(@{$form->{equity_last_period}}, $form->format_amount($myconfig,$form->{earnings_last_period}, $form->{decimalplaces}, "- "));
    
    $form->{total_equity_last_period} = $form->round_amount($form->{total_equity_last_period} + $form->{earnings_last_period}, $form->{decimalplaces});

    # add liability + equity
    $form->{total_last_period} = $form->format_amount($myconfig, $form->{total_liabilities_last_period} + $form->{total_equity_last_period}, $form->{decimalplaces}, "- ");

  }

  
  $form->{total_liabilities_last_period} = $form->format_amount($myconfig, $form->{total_liabilities_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_liabilities_last_period} != 0);
  
  $form->{total_equity_last_period} = $form->format_amount($myconfig, $form->{total_equity_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_equity_last_period} != 0);
  
  $form->{total_assets_last_period} = $form->format_amount($myconfig, $form->{total_assets_last_period}, $form->{decimalplaces}, "- ") if ($form->{total_assets_last_period} != 0);
  
  $form->{total_assets_this_period} = $form->format_amount($myconfig, $form->{total_assets_this_period}, $form->{decimalplaces}, "- ");
  
  $form->{total_liabilities_this_period} = $form->format_amount($myconfig, $form->{total_liabilities_this_period}, $form->{decimalplaces}, "- ");
  
  $form->{total_equity_this_period} = $form->format_amount($myconfig, $form->{total_equity_this_period}, $form->{decimalplaces}, "- ");
  
}



sub get_accounts {
  my ($dbh, $last_period, $fromdate, $todate, $form, $categories) = @_;

  my $query;
  my $where = "WHERE 1 = 1";
  my $subwhere;
  my $item;
 
  my $category = "AND (";
  foreach $item (@{ $categories }) {
    $category .= qq|c.category = '$item' OR |;
  }
  $category =~ s/OR $/\)/;


  # get headings
  $query = qq|SELECT accno, description, category
	      FROM chart c
	      WHERE c.charttype = 'H'
	      $category
	      ORDER by c.accno|;

  if ($form->{accounttype} eq 'gifi')
  {
    $query = qq|SELECT g.accno, g.description, c.category
		FROM gifi g
		JOIN chart c ON (c.gifi_accno = g.accno)
		WHERE c.charttype = 'H'
		$category
		ORDER BY g.accno|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  my @headingaccounts = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc))
  {
    $form->{$ref->{category}}{$ref->{accno}}{description} = "$ref->{description}";
    $form->{$ref->{category}}{$ref->{accno}}{charttype} = "H";
    $form->{$ref->{category}}{$ref->{accno}}{accno} = $ref->{accno};
    
    push @headingaccounts, $ref->{accno};
  }

  $sth->finish;


  $where .= " AND ac.transdate >= '$fromdate'" if $fromdate;

  if ($todate) {
    $where .= " AND ac.transdate <= '$todate'";
    $subwhere = " AND transdate <= '$todate'";
  }
    

  if ($form->{project_id})
  {
    $project = qq|
                 AND ac.project_id = $form->{project_id}
		 |;
  }


  if ($form->{accounttype} eq 'gifi')
  {
    
    if ($form->{method} eq 'cash')
    {

	$query = qq|
	
	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ar a ON (a.id = ac.trans_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
		 $where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AR_paid%'
		     $subwhere
		   )
		 $project
		 GROUP BY g.accno, g.description, c.category
		 
       UNION
       
		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ar a ON (a.id = ac.trans_id)
		 $where
		 $category
		 AND c.gifi_accno = ''
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AR_paid%'
		     $subwhere
		   )
		 $project
		 GROUP BY c.category

       UNION

       	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ap a ON (a.id = ac.trans_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
		 $where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AP_paid%'
		     $subwhere
		   )
		 $project
		 GROUP BY g.accno, g.description, c.category
		 
       UNION
       
		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN ap a ON (a.id = ac.trans_id)
		 $where
		 $category
		 AND c.gifi_accno = ''
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AP_paid%'
		     $subwhere
		   )
		 $project
		 GROUP BY c.category

       UNION

-- add gl
	
	         SELECT g.accno, sum(ac.amount) AS amount,
		 g.description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN gifi g ON (g.accno = c.gifi_accno)
	         JOIN gl a ON (a.id = ac.trans_id)
		 $where
		 $category
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY g.accno, g.description, c.category
		 
       UNION
       
		 SELECT '' AS accno, SUM(ac.amount) AS amount,
		 '' AS description, c.category
		 FROM acc_trans ac
	         JOIN chart c ON (c.id = ac.chart_id)
	         JOIN gl a ON (a.id = ac.trans_id)
		 $where
		 $category
		 AND c.gifi_accno = ''
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY c.category
		 |;

    } else {

      $query = qq|
      
	      SELECT g.accno, SUM(ac.amount) AS amount,
	      g.description, c.category
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      JOIN gifi g ON (c.gifi_accno = g.accno)
	      $where
	      $category
	      $project
	      GROUP BY g.accno, g.description, c.category
	      
	   UNION
	   
	      SELECT '' AS accno, SUM(ac.amount) AS amount,
	      '' AS description, c.category
	      FROM acc_trans ac
	      JOIN chart c ON (c.id = ac.chart_id)
	      $where
	      $category
	      AND c.gifi_accno = ''
	      $project
	      GROUP by c.category
	      |;
	      
    }
    
  } else {

    if ($form->{method} eq 'cash')
    {


      $query = qq|
	
	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN ar a ON (a.id = ac.trans_id)
		 $where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AR_paid%'
		     $subwhere
		   )
		     
		 $project
		 GROUP BY c.accno, c.description, c.category
		 
	UNION
	
	         SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN ap a ON (a.id = ac.trans_id)
		 $where
		 $category
		 AND ac.trans_id IN
		   (
		     SELECT trans_id
		     FROM acc_trans
		     JOIN chart ON (chart_id = id)
		     WHERE link LIKE '%AP_paid%'
		     $subwhere
		   )
		     
		 $project
		 GROUP BY c.accno, c.description, c.category
		 
        UNION

		 SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 JOIN gl a ON (a.id = ac.trans_id)
		 $where
		 $category
		 AND NOT (c.link = 'AR' OR c.link = 'AP')
		 $project
		 GROUP BY c.accno, c.description, c.category
		 |;
		 
    } else {
     
      $query = qq|
      
		 SELECT c.accno, sum(ac.amount) AS amount,
		 c.description, c.category
		 FROM acc_trans ac
		 JOIN chart c ON (c.id = ac.chart_id)
		 $where
		 $category
		 $project
		 GROUP BY c.accno, c.description, c.category
		 |;

    }
    
  }


  my @accno;
  my $accno;
  my $ref;
  
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ($ref = $sth->fetchrow_hashref(NAME_lc))
  {

    if ($ref->{category} eq 'C') {
      $ref->{category} = 'A';
    }
      
    # get last heading account
    @accno = grep { $_ le "$ref->{accno}" } @headingaccounts;
    $accno = pop @accno;
    if ($accno) {
      if ($last_period)
      {
	$form->{$ref->{category}}{$accno}{last} += $ref->{amount};
      } else {
	$form->{$ref->{category}}{$accno}{this} += $ref->{amount};
      }
    }
    
    $form->{$ref->{category}}{$ref->{accno}}{accno} = $ref->{accno};
    $form->{$ref->{category}}{$ref->{accno}}{description} = $ref->{description};
    $form->{$ref->{category}}{$ref->{accno}}{charttype} = "A";
    
    if ($last_period)
    {
      $form->{$ref->{category}}{$ref->{accno}}{last} += $ref->{amount};
    } else {
      $form->{$ref->{category}}{$ref->{accno}}{this} += $ref->{amount};
    }
  }
  $sth->finish;

  
  # remove accounts with zero balance
  foreach $category (@{ $categories }) {
    foreach $accno (keys %{ $form->{$category} }) {
      $form->{$category}{$accno}{last} = $form->round_amount($form->{$category}{$accno}{last}, $form->{decimalplaces});
      $form->{$category}{$accno}{this} = $form->round_amount($form->{$category}{$accno}{this}, $form->{decimalplaces});

      delete $form->{$category}{$accno} if ($form->{$category}{$accno}{this} == 0 && $form->{$category}{$accno}{last} == 0);
    }
  }

}



sub trial_balance_details {
  my ($self, $myconfig, $form) = @_;

  my $dbh = $form->dbconnect($myconfig);

  my ($query, $sth, $ref);
  my %balance = ();
  my %trb = ();

  my $where = "WHERE 1 = 1";

  if ($form->{project_id}) {
    $where .= qq|
                AND a.project_id = $form->{project_id}
		|;
  }
  
  # get beginning balances
  if ($form->{fromdate}) {

    if ($form->{accounttype} eq 'gifi') {
      
      $query = qq|SELECT g.accno, c.category, SUM(a.amount) AS amount,
                  g.description
		  FROM acc_trans a
		  JOIN chart c ON (a.chart_id = c.id)
		  JOIN gifi g ON (c.gifi_accno = g.accno)
		  $where
		  AND a.transdate < '$form->{fromdate}'
		  GROUP BY g.accno, c.category, g.description
		  |;
   
    } else {
      
      $query = qq|SELECT c.accno, c.category, SUM(a.amount) AS amount,
                  c.description
		  FROM acc_trans a
		  JOIN chart c ON (a.chart_id = c.id)
		  $where
		  AND a.transdate < '$form->{fromdate}'
		  GROUP BY c.accno, c.category, c.description
		  |;
    }

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $balance{$ref->{accno}} = $ref->{amount};

      if ($ref->{amount} != 0 && $form->{all_accounts}) {
	$trb{$ref->{accno}}{description} = $ref->{description};
	$trb{$ref->{accno}}{charttype} = 'A';
	$trb{$ref->{accno}}{category} = $ref->{category};
      }

    }
    $sth->finish;

  }


  # get headings
  $query = qq|SELECT c.accno, c.description, c.category
	      FROM chart c
	      WHERE c.charttype = 'H'
	      ORDER by c.accno|;

  if ($form->{accounttype} eq 'gifi')
  {
    $query = qq|SELECT g.accno, g.description, c.category
		FROM gifi g
		JOIN chart c ON (c.gifi_accno = g.accno)
		WHERE c.charttype = 'H'
		ORDER BY g.accno|;
  }

  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
  
  my @headingaccounts = ();
  while ($ref = $sth->fetchrow_hashref(NAME_lc))
  {
    $trb{$ref->{accno}}{description} = $ref->{description};
    $trb{$ref->{accno}}{charttype} = 'H';
    $trb{$ref->{accno}}{category} = $ref->{category};
   
    push @headingaccounts, $ref->{accno};
  }

  $sth->finish;


  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $where .= " AND a.transdate >= '$form->{fromdate}'";
    }
    if ($form->{todate}) {
      $where .= " AND a.transdate <= '$form->{todate}'";
    }
  }


  if ($form->{accounttype} eq 'gifi') {

    $query = qq|SELECT g.accno, g.description, c.category,
                SUM(a.amount) AS amount
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		JOIN gifi g ON (c.gifi_accno = g.accno)
		$where
		GROUP BY g.accno, g.description, c.category
		
	      UNION

		SELECT '' AS accno, '' AS description, c.category,
		SUM(a.amount) AS amount
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		$where
		AND c.gifi_accno = ''
		GROUP BY c.category
		ORDER BY accno|;
    
  } else {

    $query = qq|SELECT c.accno, c.description, c.category,
                SUM(a.amount) AS amount
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		$where
		GROUP BY c.accno, c.description, c.category
                ORDER BY accno|;

  }
  
  $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);


  # prepare query for each account
    
  $query = qq|SELECT (SELECT SUM(a.amount) * -1
	      FROM acc_trans a
	      JOIN chart c ON (c.id = a.chart_id)
	      $where
	      AND a.amount < 0
	      AND c.accno = ?) AS debit,
	     (SELECT SUM(a.amount)
	      FROM acc_trans a
	      JOIN chart c ON (c.id = a.chart_id)
	      $where
	      AND a.amount > 0
	      AND c.accno = ?) AS credit
	      |;

  if ($form->{accounttype} eq 'gifi') {

    $query = qq|SELECT (SELECT SUM(a.amount) * -1
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		$where
		AND a.amount < 0
		AND c.gifi_accno = ?) AS debit,
	       (SELECT SUM(a.amount)
		FROM acc_trans a
		JOIN chart c ON (c.id = a.chart_id)
		$where
		AND a.amount > 0
		AND c.gifi_accno = ?) AS credit|;
  
  }
   
  $drcr = $dbh->prepare($query);
  
  # calculate the debit and credit in the period
  while ($ref = $sth->fetchrow_hashref(NAME_lc)) {
    $trb{$ref->{accno}}{description} = $ref->{description};
    $trb{$ref->{accno}}{charttype} = 'A';
    $trb{$ref->{accno}}{category} = $ref->{category};
    $trb{$ref->{accno}}{amount} += $ref->{amount};

  }
  $sth->finish;

  my ($debit, $credit);
  
  foreach my $accno (sort keys %trb) {
    $ref = ();

    $ref->{accno} = $accno;
    map { $ref->{$_} = $trb{$accno}{$_} } qw(description category charttype amount);
    
    $ref->{balance} = $form->round_amount($balance{$ref->{accno}}, 2);

    if ($trb{$accno}{charttype} eq 'A') {
      # get DR/CR
      $drcr->execute($ref->{accno}, $ref->{accno}) || $form->dberror($query);
      
      ($debit, $credit) = (0,0);
      while (($debit, $credit) = $drcr->fetchrow_array) {
	$ref->{debit} += $debit;
	$ref->{credit} += $credit;
      }
      $drcr->finish;

      $ref->{debit} = $form->round_amount($ref->{debit}, 2);
      $ref->{credit} = $form->round_amount($ref->{credit}, 2);
    
    }


    # add subtotal
    @accno = grep { $_ le "$ref->{accno}" } @headingaccounts;
    $accno = pop @accno;
    if ($accno) {
      $trb{$accno}{debit} += $ref->{debit};
      $trb{$accno}{credit} += $ref->{credit};
    }
   
    push @{ $form->{TB} }, $ref;
    
  }

  $dbh->disconnect;

  # debits and credits for headings
  foreach $accno (@headingaccounts) {
    foreach $ref (@{ $form->{TB} }) {
      if ($accno eq $ref->{accno}) {
        $ref->{debit} = $trb{$accno}{debit};
        $ref->{credit} = $trb{$accno}{credit};
      }
    }
  }

}



sub aging {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);
  my $invoice = ($form->{arap} eq 'ar') ? 'is' : 'ir';
  
  $form->{todate} = $form->current_date($myconfig) unless ($form->{todate});

  my $where = "1 = 1";
  my $name;

  if ($form->{"$form->{ct}_id"}) {
    $where .= qq| AND ct.id = $form->{"$form->{ct}_id"}|;
  } else {
    if ($form->{$form->{ct}}) {
      $name = $form->like(lc $form->{$form->{ct}});
      $where .= qq| AND lower(ct.name) LIKE '$name'| if $form->{$form->{ct}};
    }
  }

  # select outstanding vendors or customers, depends on $ct
  my $query = qq|SELECT DISTINCT ct.id, ct.name
                 FROM $form->{ct} ct, $form->{arap} a
		 WHERE $where
                 AND a.$form->{ct}_id = ct.id
                 AND a.paid != a.amount
                 AND (a.transdate <= '$form->{todate}')
                 ORDER BY ct.name|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  my $buysell = ($form->{arap} eq 'ar') ? 'buy' : 'sell';
  
  # for each company that has some stuff outstanding
  while ( my ($id) = $sth->fetchrow_array ) {
  
    $query = qq|

-- between 0-30 days

	SELECT $form->{ct}.id AS ctid, $form->{ct}.name,
	addr1, addr2, addr3, addr4, contact,
	phone as customerphone, fax as customerfax, $form->{ct}number,
	"invnumber", "transdate",
	(amount - paid) as "c0", 0.00 as "c30", 0.00 as "c60", 0.00 as "c90",
	"duedate", invoice, $form->{arap}.id,
	  (SELECT $buysell FROM exchangerate
	   WHERE $form->{arap}.curr = exchangerate.curr
	   AND exchangerate.transdate = $form->{arap}.transdate) AS exchangerate
  FROM $form->{arap}, $form->{ct} 
	WHERE paid != amount
	AND $form->{arap}.$form->{ct}_id = $form->{ct}.id
	AND $form->{ct}.id = $id
	AND (
	        transdate <= (date '$form->{todate}' - interval '0 days') 
	        AND transdate >= (date '$form->{todate}' - interval '30 days')
	    )
	
	UNION

-- between 31-60 days

	SELECT $form->{ct}.id AS ctid, $form->{ct}.name,
	addr1, addr2, addr3, addr4, contact,
	phone as customerphone, fax as customerfax, $form->{ct}number,
	"invnumber", "transdate", 
	0.00 as "c0", (amount - paid) as "c30", 0.00 as "c60", 0.00 as "c90",
	"duedate", invoice, $form->{arap}.id,
	  (SELECT $buysell FROM exchangerate
	   WHERE $form->{arap}.curr = exchangerate.curr
	   AND exchangerate.transdate = $form->{arap}.transdate) AS exchangerate
  FROM $form->{arap}, $form->{ct}
	WHERE paid != amount 
	AND $form->{arap}.$form->{ct}_id = $form->{ct}.id 
	AND $form->{ct}.id = $id
	AND (
		transdate < (date '$form->{todate}' - interval '30 days') 
		AND transdate >= (date '$form->{todate}' - interval '60 days')
		)

	UNION
  
-- between 61-90 days

	SELECT $form->{ct}.id AS ctid, $form->{ct}.name,
	addr1, addr2, addr3, addr4, contact,
	phone as customerphone, fax as customerfax, $form->{ct}number,
	"invnumber", "transdate", 
	0.00 as "c0", 0.00 as "c30", (amount - paid) as "c60", 0.00 as "c90",
	"duedate", invoice, $form->{arap}.id,
	  (SELECT $buysell FROM exchangerate
	   WHERE $form->{arap}.curr = exchangerate.curr
	   AND exchangerate.transdate = $form->{arap}.transdate) AS exchangerate
	FROM $form->{arap}, $form->{ct} 
	WHERE paid != amount
	AND $form->{arap}.$form->{ct}_id = $form->{ct}.id 
	AND $form->{ct}.id = $id
	AND (
		transdate < (date '$form->{todate}' - interval '60 days') 
		AND transdate >= (date '$form->{todate}' - interval '90 days')
		)

	UNION
  
-- over 90 days

	SELECT $form->{ct}.id AS ctid, $form->{ct}.name,
	addr1, addr2, addr3, addr4, contact,
	phone as customerphone, fax as customerfax, $form->{ct}number,
	"invnumber", "transdate", 
	0.00 as "c0", 0.00 as "c30", 0.00 as "c60", (amount - paid) as "c90",
	"duedate", invoice, $form->{arap}.id,
	  (SELECT $buysell FROM exchangerate
	   WHERE $form->{arap}.curr = exchangerate.curr
	   AND exchangerate.transdate = $form->{arap}.transdate) AS exchangerate
	FROM $form->{arap}, $form->{ct} 
	WHERE paid != amount
	AND $form->{arap}.$form->{ct}_id = $form->{ct}.id 
	AND $form->{ct}.id = $id
	AND transdate < (date '$form->{todate}' - interval '90 days') 

	ORDER BY
  
  ctid, invnumber, transdate
  
		|;

    my $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror;

    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{module} = ($ref->{invoice}) ? $invoice : $form->{arap};
      $ref->{exchangerate} = 1 unless $ref->{exchangerate};
      push @{ $form->{AG} }, $ref;
    }
    
    $sth->finish;

  }

  $sth->finish;
  # disconnect
  $dbh->disconnect;

}


sub get_customer {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  my $query = qq|SELECT name, email, cc, bcc
                 FROM $form->{ct} ct
		 WHERE ct.id = $form->{"$form->{ct}_id"}|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  ($form->{$form->{ct}}, $form->{email}, $form->{cc}, $form->{bcc}) = $sth->fetchrow_array;
  $sth->finish;
  $dbh->disconnect;

}


sub get_taxaccounts {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # get tax accounts
  my $query = qq|SELECT accno, description
                 FROM chart
		 WHERE link LIKE '%CT_tax%'
                 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  while ( my ($accno, $description) = $sth->fetchrow_array ) {
    push @{ $form->{taxaccounts} }, "$accno--$description";
  }
  $sth->finish;

  # get gifi tax accounts
  my $query = qq|SELECT DISTINCT ON (g.accno) g.accno, g.description
                 FROM gifi g, chart c
		 WHERE g.accno = c.gifi_accno
		 AND c.link LIKE '%CT_tax%'
                 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror;

  while ( my ($accno, $description) = $sth->fetchrow_array ) {
    push @{ $form->{gifi_taxaccounts} }, "$accno--$description";
  }
  $sth->finish;

  $dbh->disconnect;

}



sub tax_report {
  my ($self, $myconfig, $form) = @_;

  # connect to database
  my $dbh = $form->dbconnect($myconfig);

  # build WHERE
  my $where = qq|WHERE ac.trans_id = a.id
	         AND ac.chart_id = ch.id|;
		 

  if ($form->{accno} =~ /^gifi_/) {
    my ($null, $accno) = split /_/, $form->{accno};
    $where .= qq| AND ch.gifi_accno = '$accno'|;
  } else {
    $where .= qq| AND ch.accno = '$form->{accno}'|;
  }

  my $table;
  
  if ($form->{db} eq 'ar') {
    $where .= " AND n.id = a.customer_id";
    $table = "customer";
  }
  if ($form->{db} eq 'ap') {
    $where .= " AND n.id = a.vendor_id";
    $table = "vendor";
  }

  my $transdate = ($form->{cashbased}) ? "a.datepaid" : "ac.transdate";
  if ($form->{cashbased}) {
    $where .= " AND a.amount = a.paid";
  }

  # if there are any dates construct a where
  if ($form->{fromdate} || $form->{todate}) {
    if ($form->{fromdate}) {
      $where .= " AND $transdate >= '$form->{fromdate}'";
    }
    if ($form->{todate}) {
      $where .= " AND $transdate <= '$form->{todate}'";
    }
  }
  
  my $query = qq|SELECT a.id, a.invoice, $transdate AS transdate, a.invnumber,
                        n.name, a.netamount,|;
  my $sortorder = join ', ', $form->sort_columns(qw(transdate invnumber name));
  $sortorder = $form->{sort} unless $sortorder;
  
  if ($form->{db} eq 'ar') {
    $query .= " ac.amount AS tax";
  }
  if ($form->{db} eq 'ap') {
    $query .= " ac.amount * -1 AS tax";
  }

  $query .= qq|
               FROM acc_trans ac, "$form->{db}" a, "$table" n, chart ch
	       $where
	       ORDER by $sortorder|;

  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);

  while ( my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{TR} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

}


sub paymentaccounts {
  my ($self, $myconfig, $form) = @_;
 
  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $arap = uc $form->{db};
  $arap .= "_paid";
  
  # get A(R|P)_paid accounts
  my $query = qq|SELECT accno, description
                 FROM chart
                 WHERE link LIKE '%$arap%'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $form->dberror($query);
 
  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $form->{PR} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

}

 
sub payments {
  my ($self, $myconfig, $form) = @_;

  # connect to database, turn AutoCommit off
  my $dbh = $form->dbconnect_noauto($myconfig);

  my $ml = 1;
  if ($form->{db} eq 'ar') {
    $table = 'customer';
    $ml = -1;
  }
  if ($form->{db} eq 'ap') {
    $table = 'vendor';
  }
  
  my ($query, $sth);
  
  # cycle through each id
  foreach my $accno (split(/ /, $form->{paymentaccounts})) {

    $query = qq|SELECT id, accno, description
                FROM chart
		WHERE accno = '$accno'|;
    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    my $ref = $sth->fetchrow_hashref(NAME_lc);
    push @{ $form->{PR} }, $ref;
    $sth->finish;

    $query = qq|SELECT c.name, a.invnumber, a.ordnumber,
		ac.transdate,
		ac.amount * $ml AS paid, ac.source, a.invoice, a.id,
		'$form->{db}' AS module
		FROM $table c, acc_trans ac, $form->{db} a
		WHERE c.id = a.${table}_id
		AND ac.trans_id = a.id
		AND ac.chart_id = $ref->{id}|;
		
    $query .= " AND ac.transdate >= '$form->{fromdate}'" if $form->{fromdate};
    $query .= " AND ac.transdate <= '$form->{todate}'" if $form->{todate};

    $query .= qq|
 	UNION
		SELECT g.description, g.reference, NULL AS ordnumber,
		 ac.transdate,
		 ac.amount * $ml AS paid, ac.source, '0' as invoice, g.id,
		 'gl' AS module
		 FROM gl g, acc_trans ac
		 WHERE g.id = ac.trans_id
		 AND ac.chart_id = $ref->{id}
		 AND (ac.amount * $ml) > 0
		|;

    $query .= " AND ac.transdate >= '$form->{fromdate}'" if $form->{fromdate};
    $query .= " AND ac.transdate <= '$form->{todate}'" if $form->{todate};


    my $sortorder = join ', ', $form->sort_columns(qw(name invnumber ordnumber transdate source));
    
    $query .= " ORDER BY $sortorder";

    $sth = $dbh->prepare($query);
    $sth->execute || $form->dberror($query);

    while (my $pr = $sth->fetchrow_hashref(NAME_lc)) {
      push @{ $form->{$ref->{id}} }, $pr;
    }
    $sth->finish;

  }
  
  $dbh->disconnect;
  
}


1;


