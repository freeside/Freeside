#=====================================================================
# SQL-Ledger Accounting
# Copyright (c) 2003
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
# 
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
#
# printing routines for ar, ap
#

# any custom scripts for this one
if (-f "$form->{path}/custom_arapprn.pl") {
    eval { require "$form->{path}/custom_arapprn.pl"; };
}
if (-f "$form->{path}/$form->{login}_arapprn.pl") {
    eval { require "$form->{path}/$form->{login}_arapprn.pl"; };
}


1;
# end of main


sub print {
  
  if ($form->{AP}) {
    $form->{vc} = "vendor";
    $form->{ARAP} = "AP";
    $invfld = "vinumber";
  }
  if ($form->{AR}) {
    $form->{vc} = "customer";
    $form->{ARAP} = "AR";
    $invfld = "sinumber";
  }
  
  if ($form->{media} !~ /screen/) {
    $form->error($locale->text('Select postscript or PDF!')) if $form->{format} !~ /(postscript|pdf)/;
  }

  if ($form->{media} eq 'screen' && $form->{formname} =~ /(check|receipt)/) {
    $form->error($locale->text('Select postscript or PDF!')) if $form->{format} !~ /(postscript|pdf)/;
  }
  
  if (! $form->{invnumber}) {
    $form->{invnumber} = $form->update_defaults(\%myconfig, $invfld);
    if ($form->{media} eq 'screen') {
      if ($form->{media} eq 'screen') {
	&update;
	exit;
      }
    }
  }

  if ($form->{formname} =~ /(check|receipt)/) {
    if ($form->{media} ne 'screen') {
      map { delete $form->{$_} } qw(action header);
      $form->{invtotal} = $form->{oldinvtotal};
      
      foreach $key (keys %$form) {
	$form->{$key} =~ s/&/%26/g;
	$form->{previousform} .= qq|$key=$form->{$key}&|;
      }
      chop $form->{previousform};
      $form->{previousform} = $form->escape($form->{previousform}, 1);
    }

    if ($form->{paidaccounts} > 1) {
      if ($form->{"paid_$form->{paidaccounts}"}) {
	&update;
	exit;
      } elsif ($form->{paidaccounts} > 2) {
	# select payment
	&select_payment;
	exit;
      }
    } else {
      $form->error($locale->text('Nothing to print!'));
    }
    
  }

  &{ "print_$form->{formname}" }(1);

}


sub print_check {
  my ($i) = @_;
  
  $display_form = ($form->{display_form}) ? $form->{display_form} : "display_form";

  if ($form->{"paid_$i"}) {
    @a = ();
    
    if (exists $form->{longformat}) {
      $form->{"datepaid_$i"} = $locale->date(\%myconfig, $form->{"datepaid_$i"}, $form->{longformat});
    }

    push @a, "source_$i", "memo_$i";
    $form->format_string(@a);
  }

  $form->{amount} = $form->{"paid_$i"};
  map { $form->{$_} = $form->{"${_}_$i"} } qw(datepaid source memo);

  
  &{ "$form->{vc}_details" };
  @a = qw(name address1 address2 city state zipcode country);
 
  foreach $item (qw(invnumber ordnumber)) {
    $temp{$item} = $form->{$item};
    delete $form->{$item};
    push(@{ $form->{$item} }, $temp{$item});
  }
  push(@{ $form->{invdate} }, $form->{transdate});
  push(@{ $form->{due} }, $form->format_amount(\%myconfig, $form->{oldinvtotal}, 2));
  push(@{ $form->{paid} }, $form->{"paid_$i"});

  use SL::CP;
  if ($form->{language_code}) {
    $c = new CP $form->{language_code};
  } else {
    $c = new CP $myconfig->{countrycode};
  } 
  $c->init;
  ($whole, $form->{decimal}) = split /\./, $form->{amount};
  $form->{decimal} .= "00";
  $form->{decimal} = substr($form->{decimal}, 0, 2);
  $form->{text_amount} = $c->num2text($whole); 
  
  ($form->{employee}) = split /--/, $form->{employee};

  $form->{notes} =~ s/^\s+//g;
  push @a, "notes";

  map { $form->{$_} = $myconfig{$_} } (qw(company address tel fax businessnumber));
  push @a, qw(company address tel fax businessnumber);
  
  $form->format_string(@a);

  $form->{templates} = "$myconfig{templates}";
  $form->{IN} = ($form->{formname} eq 'transaction') ? lc $form->{ARAP} . "_$form->{formname}.html" : "$form->{formname}.html";

  if ($form->{format} =~ /(postscript|pdf)/) {
    $form->{IN} =~ s/html$/tex/;
  }

  if ($form->{media} !~ /(screen|queue)/) {
    $form->{OUT} = "| $printer{$form->{media}}";
    
    $reference = $form->{invnumber};
    
    if ($form->{formname} =~ /(check|receipt)/) {
      $form->{rowcount} = 1;
      $form->{"id_1"} = $form->{id};
      $form->{"checked_1"} = 1;
      $form->{account} = $form->{"$form->{ARAP}_paid_$i"};
      $reference = $form->{"source_$i"};
    }
      
    if ($form->{printed} !~ /$form->{formname}/) {

      $form->{printed} .= " $form->{formname}";
      $form->{printed} =~ s/^ //;

      $form->update_status(\%myconfig);
    }

    %audittrail = ( tablename   => lc $form->{ARAP},
                    reference   => $reference,
		    formname    => $form->{formname},
		    action      => 'printed',
		    id          => $form->{id} );
    
    %status = ();
    map { $status{$_} = $form->{$_} } qw(printed queued audittrail);
    
    $status{audittrail} .= $form->audittrail("", \%myconfig, \%audittrail);

  }

  if ($form->{media} eq 'queue') {
    %queued = split / /, $form->{queued};
    
    $reference = $form->{invnumber};
 
    if ($form->{formname} =~ /(check|receipt)/) {
      $form->{rowcount} = 1;
      $form->{"id_1"} = $form->{id};
      $form->{"checked_1"} = 1;
      $form->{account} = $form->{"$form->{ARAP}_paid_$i"};
      $reference = $form->{"source_$i"};
    }
 
    if ($filename = $queued{$form->{formname}}) {
      $form->{queued} =~ s/$form->{formname} $filename//;
      unlink "$spool/$filename";
      $filename =~ s/\..*$//g;
    } else {
      $filename = time;
      $filename .= $$;
    }

    $filename .= ($form->{format} eq 'postscript') ? '.ps' : '.pdf';
    $form->{OUT} = ">$spool/$filename";

    $form->{queued} .= " $form->{formname} $filename";
    $form->{queued} =~ s/^ //;

    # save status
    $form->update_status(\%myconfig);

    %audittrail = ( tablename   => lc $form->{ARAP},
                    reference   => $reference,
		    formname    => $form->{formname},
		    action      => 'queued',
		    id          => $form->{id} );

    %status = ();
    map { $status{$_} = $form->{$_} } qw(printed queued audittrail);

    $status{audittrail} .= $form->audittrail("", \%myconfig, \%audittrail);

  }

  $form->{fileid} = $invnumber;
  $form->{fileid} =~ s/(\s|\W)+//g;

  $form->parse_template(\%myconfig, $userspath);

  if ($form->{previousform}) {
  
    $previousform = $form->unescape($form->{previousform});

    map { delete $form->{$_} } keys %$form;

    foreach $item (split /&/, $previousform) {
      ($key, $value) = split /=/, $item, 2;
      $value =~ s/%26/&/g;
      $form->{$key} = $value;
    }

    map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate creditlimit creditremaining);

    map { $form->{"amount_$_"} = $form->parse_amount(\%myconfig, $form->{"amount_$_"}) } (1 .. $form->{rowcount});
    map { $form->{"tax_$_"} = $form->parse_amount(\%myconfig, $form->{"tax_$_"}) } split / /, $form->{taxaccounts};

    for $i (1 .. $form->{paidaccounts}) {
      map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);
    }

    map { $form->{$_} = $status{$_} } qw(printed queued audittrail);

    &{ "$display_form" };
    
  }

}


sub print_receipt { &print_check; }


sub print_transaction {
 
  $display_form = ($form->{display_form}) ? $form->{display_form} : "display_form";
 
  if ($form->{media} !~ /screen/) {
    $old_form = new Form;
    map { $old_form->{$_} = $form->{$_} } keys %$form;
  }
 
  &{ "$form->{vc}_details" };
  @a = qw(name address1 address2 city state zipcode country);
  
  
  $form->{invtotal} = 0;
  foreach $i (1 .. $form->{rowcount} - 1) {
    ($form->{tempaccno}, $form->{tempaccount}) = split /--/, $form->{"$form->{ARAP}_amount_$i"};
    ($form->{tempprojectnumber}) = split /--/, $form->{"projectnumber_$i"};
    
    $form->format_string(qw(tempaccno tempaccount tempprojectnumber));
    
    push(@{ $form->{accno} }, $form->{tempaccno});
    push(@{ $form->{account} }, $form->{tempaccount});
    push(@{ $form->{projectnumber} }, $form->{tempprojectnumber});

    push(@{ $form->{amount} }, $form->{"amount_$i"});

    $form->{subtotal} += $form->parse_amount(\%myconfig, $form->{"amount_$i"});
    
  }

  foreach $accno (split / /, $form->{taxaccounts}) {
    if ($form->{"tax_$accno"}) {
      $tax += $form->parse_amount(\%myconfig, $form->{"tax_$accno"});
      push(@{ $form->{tax} }, $form->{"tax_$accno"});
      push(@{ $form->{taxdescription} }, $form->{"${accno}_description"});
      push(@{ $form->{taxrate} }, $form->{"${accno}_rate"} * 100);
      push(@{ $form->{taxnumber} }, $form->{"${accno}_taxnumber"});
    }
  }
    
 
  push @a, $form->{ARAP};
  $form->format_string(@a);
  
  $form->{paid} = 0;
  for $i (1 .. $form->{paidaccounts} - 1) {

    if ($form->{"paid_$i"}) {
    @a = ();
    $form->{paid} += $form->parse_amount(\%myconfig, $form->{"paid_$i"});
    
    if (exists $form->{longformat}) {
      $form->{"datepaid_$i"} = $locale->date(\%myconfig, $form->{"datepaid_$i"}, $form->{longformat});
    }

    push @a, "$form->{ARAP}_paid_$i", "source_$i", "memo_$i";
    $form->format_string(@a);
    
    ($accno, $account) = split /--/, $form->{"$form->{ARAP}_paid_$i"};
    
    push(@{ $form->{payment} }, $form->{"paid_$i"});
    push(@{ $form->{paymentdate} }, $form->{"datepaid_$i"});
    push(@{ $form->{paymentaccount} }, $account);
    push(@{ $form->{paymentsource} }, $form->{"source_$i"});
    push(@{ $form->{paymentmemo} }, $form->{"memo_$i"});
    }
    
  }


  $form->{invtotal} = $form->{subtotal} + $tax;
  $form->{total} = $form->{invtotal} - $form->{paid};
  
  use SL::CP;
  if ($form->{language_code}) {
    $c = new CP $form->{language_code};
  } else {
    $c = new CP $myconfig->{countrycode};
  } 
  $c->init;
  ($whole, $form->{decimal}) = split /\./, $form->{invtotal};
  $form->{decimal} .= "00";
  $form->{decimal} = substr($form->{decimal}, 0, 2);
  $form->{text_amount} = $c->num2text($whole); 
  
  map { $form->{$_} = $form->format_amount(\%myconfig, $form->{$_}, 2) } qw(invtotal subtotal paid total);
  
  ($form->{employee}) = split /--/, $form->{employee};

  if (exists $form->{longformat}) {
    map { $form->{$_} = $locale->date(\%myconfig, $form->{$_}, $form->{longformat}) } ("duedate", "transdate");
  }

  $form->{notes} =~ s/^\s+//g;

  push @a, ("invnumber", "transdate", "duedate", "notes");

  map { $form->{$_} = $myconfig{$_} } (qw(company address tel fax businessnumber));
  push @a, qw(company address tel fax businessnumber);
  
  $form->format_string(@a);

  $form->{invdate} = $form->{transdate};

  $form->{templates} = "$myconfig{templates}";
  $form->{IN} = ($form->{formname} eq 'transaction') ? lc $form->{ARAP} . "_$form->{formname}.html" : "$form->{formname}.html";

  if ($form->{format} =~ /(postscript|pdf)/) {
    $form->{IN} =~ s/html$/tex/;
  }

  if ($form->{media} !~ /(screen|queue)/) {
    $form->{OUT} = "| $printer{$form->{media}}";
    
    if ($form->{printed} !~ /$form->{formname}/) {

      $form->{printed} .= " $form->{formname}";
      $form->{printed} =~ s/^ //;

      $form->update_status(\%myconfig);
    }

    $old_form->{printed} = $form->{printed};
    
    %audittrail = ( tablename   => lc $form->{ARAP},
                    reference   => $form->{"invnumber"},
		    formname    => $form->{formname},
		    action      => 'printed',
		    id          => $form->{id} );
    
    $old_form->{audittrail} .= $form->audittrail("", \%myconfig, \%audittrail);

  }

  if ($form->{media} eq 'queue') {
    %queued = split / /, $form->{queued};

    if ($filename = $queued{$form->{formname}}) {
      $form->{queued} =~ s/$form->{formname} $filename//;
      unlink "$spool/$filename";
      $filename =~ s/\..*$//g;
    } else {
      $filename = time;
      $filename .= $$;
    }

    $filename .= ($form->{format} eq 'postscript') ? '.ps' : '.pdf';
    $form->{OUT} = ">$spool/$filename";

    $form->{queued} .= " $form->{formname} $filename";
    $form->{queued} =~ s/^ //;

    # save status
    $form->update_status(\%myconfig);

    $old_form->{queued} = $form->{queued};

    %audittrail = ( tablename   => lc $form->{ARAP},
                    reference   => $form->{invnumber},
		    formname    => $form->{formname},
		    action      => 'queued',
		    id          => $form->{id} );
    $old_form->{audittrail} .= $form->audittrail("", \%myconfig, \%audittrail);

  }

  $form->{fileid} = $form->{invnumber};
  $form->{fileid} =~ s/(\s|\W)+//g;

  $form->parse_template(\%myconfig, $userspath);

  if ($old_form) {
    $old_form->{invnumber} = $form->{invnumber};
    $old_form->{invtotal} = $form->{invtotal};

    map { delete $form->{$_} } keys %$form;
    map { $form->{$_} = $old_form->{$_} } keys %$old_form;

    if (! $form->{printandpost}) {
      map { $form->{$_} = $form->parse_amount(\%myconfig, $form->{$_}) } qw(exchangerate creditlimit creditremaining);

      map { $form->{"amount_$_"} = $form->parse_amount(\%myconfig, $form->{"amount_$_"}) } (1 .. $form->{rowcount});
      map { $form->{"tax_$_"} = $form->parse_amount(\%myconfig, $form->{"tax_$_"}) } split / /, $form->{taxaccounts};

      for $i (1 .. $form->{paidaccounts}) {
	map { $form->{"${_}_$i"} = $form->parse_amount(\%myconfig, $form->{"${_}_$i"}) } qw(paid exchangerate);
      }
    }
    
    &{ "$display_form" };

  }
}


sub vendor_details { IR->vendor_details(\%myconfig, \%$form) };
sub customer_details { IS->customer_details(\%myconfig, \%$form) };


sub select_payment {

  @column_index = ("ndx", "datepaid", "source", "memo", "paid", "$form->{ARAP}_paid");

  # list payments with radio button on a form
  $form->header;

  $title = $locale->text('Select payment');

  $column_data{ndx} = qq|<th width=1%>&nbsp;</th>|;
  $column_data{datepaid} = qq|<th>|.$locale->text('Date').qq|</th>|;
  $column_data{source} = qq|<th>|.$locale->text('Source').qq|</th>|;
  $column_data{memo} = qq|<th>|.$locale->text('Memo').qq|</th>|;
  $column_data{paid} = qq|<th>|.$locale->text('Amount').qq|</th>|;
  $column_data{"$form->{ARAP}_paid"} = qq|<th>|.$locale->text('Account').qq|</th>|;

  print qq|
<body>

<form method=post action=$form->{script}>

<table width=100%>
  <tr>
    <th class=listtop>$title</th>
  </tr>
  <tr space=5></tr>
  <tr>
    <td>
      <table width=100%>
	<tr class=listheading>|;

  map { print "\n$column_data{$_}" } @column_index;
  
  print qq|
	</tr>
|;

  foreach $i (1 .. $form->{paidaccounts} - 1) {
   $checked = ($i == 1) ? "checked" : "";

   map { $column_data{$_} = qq|<td>$form->{"${_}_$i"}</td>| } @column_index;
   $column_data{ndx} = qq|<td><input name=ndx class=radio type=radio value=$i $checked></td>|;
   $column_data{paid} = qq|<td align=right>$form->{"paid_$i"}</td>|;
    
    $j++; $j %= 2;
    print qq|
	<tr class=listrow$j>|;

    map { print "\n$column_data{$_}" } @column_index;

    print qq|
	</tr>
|;

  }
  
  print qq|
      </table>
    </td>
  </tr>
  <tr>
    <td><hr size=3 noshade></td>
  </tr>
</table>
|;

  $form->{nextsub} = "payment_selected";

  $form->hide_form();
  
  print qq|

<br>
<input class=submit type=submit name=action value="|.$locale->text('Continue').qq|">
</form>

</body>
</html>
|;
  
}

sub payment_selected {

  &{ "print_$form->{formname}" }($form->{ndx});

}


sub print_options {

  $form->{PD}{$form->{formname}} = "selected";
  $form->{DF}{$form->{format}} = "selected";

  if ($form->{selectlanguage}) {
    $form->{"selectlanguage"} = $form->unescape($form->{"selectlanguage"});
    $form->{"selectlanguage"} =~ s/ selected//;
    $form->{"selectlanguage"} =~ s/(<option value="\Q$form->{language_code}\E")/$1 selected/;
    $lang = qq|<select name=language_code>$form->{selectlanguage}</select>
    <input type=hidden name=selectlanguage value="|.
    $form->escape($form->{selectlanguage},1).qq|">|;
  }
  
  $type = qq|<select name=formname>
          <option value=transaction $form->{PD}{transaction}>|.$locale->text('Transaction');

  if ($form->{AR}) {
    $type .= qq|
          <option value=receipt $form->{PD}{receipt}>|.$locale->text('Receipt').qq|</select>|;
  }

  if ($form->{AP}) {
    $type .= qq|
          <option value=check $form->{PD}{check}>|.$locale->text('Check').qq|</select>|;
  }
	  
  $media = qq|<select name=media>
          <option value=screen>|.$locale->text('Screen');

  if (%printer && $latex) {
    map { $media .= qq| 
          <option value="$_">$_| } sort keys %printer;
  }

  $format = qq|<select name=format>
            <option value=html $form->{DF}{html}>html|;
	    
  if ($latex) {
# disable for now
#    $media .= qq|
#          <option value="queue">|.$locale->text('Queue');
    $format .= qq|
            <option value=postscript $form->{DF}{postscript}>|.$locale->text('Postscript').qq|
	    <option value=pdf $form->{DF}{pdf}>|.$locale->text('PDF');
  }

  $format .= qq|</select>|;
  $media .= qq|</select>|;
  $media =~ s/(<option value="\Q$form->{media}\E")/$1 selected/;

  print qq|
  <table width=100%>
    <tr>
      <td>
  $type
  $lang
  $format
  $media
     </td>
     <td align=right>
  |;

  if ($form->{printed} =~ /$form->{formname}/) {
    print $locale->text('Printed').qq|<br>|;
  }

  if ($form->{queued} =~ /$form->{formname}/) {
    print $locale->text('Queued');
  }

  print qq|
      </td>
    </tr>
  </table>
|;

}


sub print_and_post {

  $form->error($locale->text('Select postscript or PDF!')) if $form->{format} !~ /(postscript|pdf)/;
  $form->error($locale->text('Select Printer or Queue!')) if $form->{media} eq 'screen';

  $form->{printandpost} = 1;
  $form->{display_form} = "post";
  &print;

}

