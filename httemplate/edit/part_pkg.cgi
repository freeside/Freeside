<!-- mason kludge -->
<%

if ( $cgi->param('clone') && $cgi->param('clone') =~ /^(\d+)$/ ) {
  $cgi->param('clone', $1);
} else {
  $cgi->param('clone', '');
}
if ( $cgi->param('pkgnum') && $cgi->param('pkgnum') =~ /^(\d+)$/ ) {
  $cgi->param('pkgnum', $1);
} else {
  $cgi->param('pkgnum', '');
}

my ($query) = $cgi->keywords;
my $action = '';
my $part_pkg = '';
if ( $cgi->param('error') ) {
  $part_pkg = new FS::part_pkg ( {
    map { $_, scalar($cgi->param($_)) } fields('part_pkg')
  } );
}
if ( $cgi->param('clone') ) {
  $action='Custom Pricing';
  my $old_part_pkg =
    qsearchs('part_pkg', { 'pkgpart' => $cgi->param('clone') } );
  $part_pkg ||= $old_part_pkg->clone;
  $part_pkg->disabled('Y');
} elsif ( $query && $query =~ /^(\d+)$/ ) {
  $part_pkg ||= qsearchs('part_pkg',{'pkgpart'=>$1});
} else {
  unless ( $part_pkg ) {
    $part_pkg = new FS::part_pkg {};
    $part_pkg->plan('flat');
  }
}
unless ( $part_pkg->plan ) { #backwards-compat
  $part_pkg->plan('flat');
  $part_pkg->plandata("setup_fee=". $part_pkg->setup. "\n".
                      "recur_fee=". $part_pkg->recur. "\n");
}
$action ||= $part_pkg->pkgpart ? 'Edit' : 'Add';
my $hashref = $part_pkg->hashref;


print header("$action Package Definition", menubar(
  'Main Menu' => popurl(2),
  'View all packages' => popurl(2). 'browse/part_pkg.cgi',
));
#), ' onLoad="visualize()"');

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

#print '<FORM ACTION="', popurl(1), 'process/part_pkg.cgi" METHOD=POST>';
print '<FORM NAME="dummy">';

#if ( $cgi->param('clone') ) {
#  print qq!<INPUT TYPE="hidden" NAME="clone" VALUE="!, $cgi->param('clone'), qq!">!;
#}
#if ( $cgi->param('pkgnum') ) {
#  print qq!<INPUT TYPE="hidden" NAME="pkgnum" VALUE="!, $cgi->param('pkgnum'), qq!">!;
#}
#
#print qq!<INPUT TYPE="hidden" NAME="pkgpart" VALUE="$hashref->{pkgpart}">!,
print "Package Part #", $hashref->{pkgpart} ? $hashref->{pkgpart} : "(NEW)";

print ntable("#cccccc",2), <<END;
<TR><TD ALIGN="right">Package (customer-visible)</TD><TD><INPUT TYPE="text" NAME="pkg" SIZE=32 VALUE="$hashref->{pkg}"></TD></TR>
<TR><TD ALIGN="right">Comment (customer-hidden)</TD><TD><INPUT TYPE="text" NAME="comment" SIZE=32 VALUE="$hashref->{comment}"></TD></TR>
<TR><TD ALIGN="right">Frequency (months) of recurring fee</TD><TD><INPUT TYPE="text" NAME="freq" VALUE="$hashref->{freq}" SIZE=3>&nbsp;&nbsp;<I>0=no recurring fee, 1=monthly, 3=quarterly, 12=yearly</TD></TR>
<TR><TD ALIGN="right">Setup fee tax exempt</TD><TD>
END

print '<INPUT TYPE="checkbox" NAME="setuptax" VALUE="Y"';
print ' CHECKED' if $hashref->{setuptax} eq "Y";
print '>';

print <<END;
</TD></TR>
<TR><TD ALIGN="right">Recurring fee tax exempt</TD><TD>
END

print '<INPUT TYPE="checkbox" NAME="recurtax" VALUE="Y"';
print ' CHECKED' if $hashref->{recurtax} eq "Y";
print '>';

print '</TD></TR>';

my $conf = new FS::Conf;
#false laziness w/ view/cust_main.cgi quick order
if ( $conf->exists('enable_taxclasses') ) {
  print '<TR><TD ALIGN="right">Tax class</TD><TD><SELECT NAME="taxclass">';
  my $sth = dbh->prepare('SELECT DISTINCT taxclass FROM cust_main_county')
    or die dbh->errstr;
  $sth->execute or die $sth->errstr;
  foreach my $taxclass ( map $_->[0], @{$sth->fetchall_arrayref} ) {
    print qq!<OPTION VALUE="$taxclass"!;
    print ' SELECTED' if $taxclass eq $hashref->{taxclass};
    print qq!>$taxclass</OPTION>!;
  }
  print '</SELECT></TD></TR>';
} else {
  print
    '<INPUT TYPE="hidden" NAME="taxclass" VALUE="'. $hashref->{taxclass}. '">';
}

print '<TR><TD ALIGN="right">Disable new orders</TD><TD>';
print '<INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"';
print ' CHECKED' if $hashref->{disabled} eq "Y";
print '>';
print '</TD></TR></TABLE>';

my $thead =  "\n\n". ntable('#cccccc', 2). <<END;
<TR><TH BGCOLOR="#dcdcdc"><FONT SIZE=-1>Quan.</FONT></TH><TH BGCOLOR="#dcdcdc">Service</TH></TR>
END

#unless ( $cgi->param('clone') ) {
#dunno why...
unless ( 0 ) {
  #print <<END, $thead;
  print <<END, itable(), '<TR><TD VALIGN="top">', $thead;
<BR><BR>Enter the quantity of each service this package includes.<BR><BR>
END
}

my @fixups = ();
my $count = 0;
my $columns = 3;
my @part_svc = qsearch( 'part_svc', { 'disabled' => '' } );
foreach my $part_svc ( @part_svc ) {
  my $svcpart = $part_svc->svcpart;
  my $pkg_svc = qsearchs( 'pkg_svc', {
    'pkgpart'  => $cgi->param('clone') || $part_pkg->pkgpart,
    'svcpart'  => $svcpart,
  } ) || new FS::pkg_svc ( {
    'pkgpart'  => $cgi->param('clone') || $part_pkg->pkgpart,
    'svcpart'  => $svcpart,
    'quantity' => 0,
  });
  #? #next unless $pkg_svc;

  push @fixups, "pkg_svc$svcpart";

  #unless ( defined ($cgi->param('clone')) && $cgi->param('clone') ) {
  #dunno why...
  unless ( 0 ) {
    print '<TR>'; # if $count == 0 ;
    print qq!<TD><INPUT TYPE="text" NAME="pkg_svc$svcpart" SIZE=4 MAXLENGTH=3 VALUE="!,
          $cgi->param("pkg_svc$svcpart") || $pkg_svc->quantity || 0,
          qq!"></TD><TD><A HREF="part_svc.cgi?!,$part_svc->svcpart,
          qq!">!, $part_svc->getfield('svc'), "</A></TD></TR>";
#    print "</TABLE></TD><TD>$thead" if ++$count == int(scalar(@part_svc) / 2);
    $count+=1;
    foreach ( 1 .. $columns-1 ) {
      print "</TABLE></TD><TD VALIGN=\"top\">$thead"
        if $count == int( $_ * scalar(@part_svc) / $columns );
    }
  } else {
    print qq!<INPUT TYPE="hidden" NAME="pkg_svc$svcpart" VALUE="!,
          $cgi->param("pkg_svc$svcpart") || $pkg_svc->quantity || 0, qq!">\n!;
  }
}

#unless ( $cgi->param('clone') ) {
#dunno why...
unless ( 0 ) {
  print "</TR></TABLE></TD></TR></TABLE>";
  #print "</TR></TABLE>";
}

foreach my $f ( qw( clone pkgnum ) ) {
  print qq!<INPUT TYPE="hidden" NAME="$f" VALUE="!. $cgi->param($f). '">';
}
print '<INPUT TYPE="hidden" NAME="pkgpart" VALUE="'. $part_pkg->pkgpart. '">';

# prolly should be in database
tie my %plans, 'Tie::IxHash',
  'flat' => {
    'name' => 'Flat rate (anniversary billing)',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                      },
    },
    'fieldorder' => [ 'setup_fee', 'recur_fee' ],
    'setup' => 'what.setup_fee.value',
    'recur' => 'what.recur_fee.value',
  },

  'flat_delayed' => {
    'name' => 'Free for X days, then flat rate (anniversary billing)',
    'fields' =>  {
      'free_days' => { 'name' => 'Initial free days',
                       'default' => 0,
                     },
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                      },
    },
    'fieldorder' => [ 'free_days', 'setup_fee', 'recur_fee' ],
    'setup' => '\'my $d = $cust_pkg->bill || $time; $d += 86400 * \' + what.free_days.value + \'; $cust_pkg->bill($d); $cust_pkg_mod_flag=1; \' + what.setup_fee.value',
    'recur' => 'what.recur_fee.value',
  },

  'prorate' => {
    'name' => 'First partial month pro-rated, then flat-rate (1st of month billing)',
    'fields' =>  {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                      },
    },
    'fieldorder' => [ 'setup_fee', 'recur_fee' ],
    'setup' => 'what.setup_fee.value',
    'recur' => '\'my $mnow = $sdate; my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($sdate) )[0,1,2,3,4,5]; my $mstart = timelocal(0,0,0,1,$mon,$year); my $mend = timelocal(0,0,0,1, $mon == 11 ? 0 : $mon+1, $year+($mon==11)); $sdate = $mstart; ( $part_pkg->freq - 1 ) * \' + what.recur_fee.value + \' / $part_pkg->freq + \' + what.recur_fee.value + \' / $part_pkg->freq * ($mend-$mnow) / ($mend-$mstart) ; \'',
  },

  'subscription' => {
    'name' => 'First partial month full charge, then flat-rate (1st of month billing)',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                      },
    },
    'fieldorder' => [ 'setup_fee', 'recur_fee' ],
    'setup' => 'what.setup_fee.value',
    'recur' => '\'my $mnow = $sdate; my ($sec,$min,$hour,$mday,$mon,$year) = (localtime($sdate) )[0,1,2,3,4,5]; $sdate = timelocal(0,0,0,1,$mon,$year); \' + what.recur_fee.value',
  },

  'flat_comission_cust' => {
    'name' => 'Flat rate with recurring commission per active customer',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                     },
      'comission_amount' => { 'name' => 'Commission amount per month (per active customer)',
                              'default' => 0,
                            },
      'comission_depth'  => { 'name' => 'Number of layers',
                              'default' => 1,
                            },
    },
    'fieldorder' => [ 'setup_fee', 'recur_fee', 'comission_depth', 'comission_amount' ],
    'setup' => 'what.setup_fee.value',
    'recur' => '\'my $error = $cust_pkg->cust_main->credit( \' + what.comission_amount.value + \' * scalar($cust_pkg->cust_main->referral_cust_main_ncancelled(\' + what.comission_depth.value+ \')), "commission" ); die $error if $error; \' + what.recur_fee.value + \';\'',
  },

  'flat_comission' => {
    'name' => 'Flat rate with recurring commission per (any) active package',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                     },
      'comission_amount' => { 'name' => 'Commission amount per month (per active package)',
                              'default' => 0,
                            },
      'comission_depth'  => { 'name' => 'Number of layers',
                              'default' => 1,
                            },
    },
    'fieldorder' => [ 'setup_fee', 'recur_fee', 'comission_depth', 'comission_amount' ],
    'setup' => 'what.setup_fee.value',
    'recur' => '\'my $error = $cust_pkg->cust_main->credit( \' + what.comission_amount.value + \' * scalar($cust_pkg->cust_main->referral_cust_pkg(\' + what.comission_depth.value+ \')), "commission" ); die $error if $error; \' + what.recur_fee.value + \';\'',
  },

  'flat_comission_pkg' => {
    'name' => 'Flat rate with recurring commission per (selected) active package',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_fee' => { 'name' => 'Recurring fee for this package',
                       'default' => 0,
                     },
      'comission_amount' => { 'name' => 'Commission amount per month (per uncancelled package)',
                              'default' => 0,
                            },
      'comission_depth'  => { 'name' => 'Number of layers',
                              'default' => 1,
                            },
      'comission_pkgpart' => { 'name' => 'Applicable packages<BR><FONT SIZE="-1">(hold <b>ctrl</b> to select multiple packages)</FONT>',
                               'type' => 'select_multiple',
                               'select_table' => 'part_pkg',
                               'select_hash'  => { 'disabled' => '' } ,
                               'select_key'   => 'pkgpart',
                               'select_label' => 'pkg',
                             },
    },
    'fieldorder' => [ 'setup_fee', 'recur_fee', 'comission_depth', 'comission_amount', 'comission_pkgpart' ],
    'setup' => 'what.setup_fee.value',
    'recur' => '""; var pkgparts = ""; for ( var c=0; c < document.flat_comission_pkg.comission_pkgpart.options.length; c++ ) { if (document.flat_comission_pkg.comission_pkgpart.options[c].selected) { pkgparts = pkgparts + document.flat_comission_pkg.comission_pkgpart.options[c].value + \', \'; } } what.recur.value = \'my $error = $cust_pkg->cust_main->credit( \' + what.comission_amount.value + \' * scalar( grep { my $pkgpart = $_->pkgpart; grep { $_ == $pkgpart } ( \' + pkgparts + \'  ) } $cust_pkg->cust_main->referral_cust_pkg(\' + what.comission_depth.value+ \')), "commission" ); die $error if $error; \' + what.recur_fee.value + \';\'',
  },



  'sesmon_hour' => {
    'name' => 'Base charge plus charge per-hour from the session monitor',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_flat' => { 'name' => 'Base monthly charge for this package',
                        'default' => 0,
                      },
      'recur_included_hours' => { 'name' => 'Hours included',
                                  'default' => 0,
                                },
      'recur_hourly_charge' => { 'name' => 'Additional charge per hour',
                                 'default' => 0,
                               },
    },
    'fieldorder' => [ 'setup_fee', 'recur_flat', 'recur_included_hours', 'recur_hourly_charge' ],
    'setup' => 'what.setup_fee.value',
    'recur' => '\'my $hours = $cust_pkg->seconds_since($cust_pkg->bill || 0) / 3600 - \' + what.recur_included_hours.value + \'; $hours = 0 if $hours < 0; \' + what.recur_flat.value + \' + \' + what.recur_hourly_charge.value + \' * $hours;\'',
  },

  'sesmon_minute' => {
    'name' => 'Base charge plus charge per-minute from the session monitor',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_flat' => { 'name' => 'Base monthly charge for this package',
                        'default' => 0,
                      },
      'recur_included_min' => { 'name' => 'Minutes included',
                                'default' => 0,
                                },
      'recur_minly_charge' => { 'name' => 'Additional charge per minute',
                                'default' => 0,
                              },
    },
    'fieldorder' => [ 'setup_fee', 'recur_flat', 'recur_included_min', 'recur_minly_charge' ],
    'setup' => 'what.setup_fee.value',
    'recur' => '\'my $min = $cust_pkg->seconds_since($cust_pkg->bill || 0) / 60 - \' + what.recur_included_min.value + \'; $min = 0 if $min < 0; \' + what.recur_flat.value + \' + \' + what.recur_minly_charge.value + \' * $min;\'',

  },

  'sqlradacct_hour' => {
    'name' => 'Base charge plus charge per-hour (and for data) from an external sqlradius radacct table',
    'fields' => {
      'setup_fee' => { 'name' => 'Setup fee for this package',
                       'default' => 0,
                     },
      'recur_flat' => { 'name' => 'Base monthly charge for this package',
                        'default' => 0,
                      },
      'recur_included_hours' => { 'name' => 'Hours included',
                                  'default' => 0,
                                },
      'recur_hourly_charge' => { 'name' => 'Additional charge per hour',
                                 'default' => 0,
                               },
      'recur_included_input' => { 'name' => 'Input megabytes included',
                                  'default' => 0,
                                },
      'recur_input_charge' => { 'name' =>
                                        'Additional charge per input megabyte',
                                'default' => 0,
                              },
      'recur_included_output' => { 'name' => 'Output megabytes included',
                                   'default' => 0,
                                },
      'recur_output_charge' => { 'name' =>
                                       'Additional charge per output megabyte',
                                'default' => 0,
                              },
      'recur_included_total' => { 'name' =>
                                       'Total input+output megabytes included',
                                  'default' => 0,
                                },
      'recur_total_charge' => { 'name' =>
                                 'Additional charge per input+output megabyte',
                                'default' => 0,
                              },
    },
    'fieldorder' => [qw( setup_fee recur_flat recur_included_hours recur_hourly_charge recur_included_input recur_input_charge recur_included_output recur_output_charge recur_included_total recur_total_charge )],
    'setup' => 'what.setup_fee.value',
    'recur' => '\'my $last_bill = $cust_pkg->last_bill; my $hours = $cust_pkg->seconds_since_sqlradacct($last_bill, $sdate ) / 3600 - \' + what.recur_included_hours.value + \'; $hours = 0 if $hours < 0; my $input = $cust_pkg->attribute_since_sqlradacct($last_bill, $sdate, \"AcctInputOctets\" ) / 1048576; my $output = $cust_pkg->attribute_since_sqlradacct($last_bill, $sdate, \"AcctOutputOctets\" ) / 1048576; my $total = $input + $output - \' + what.recur_included_total.value + \'; $total = 0 if $total < 0; my $input = $input - \' + what.recur_included_input.value + \'; $input = 0 if $input < 0; my $output = $output - \' + what.recur_included_output.value + \'; $output = 0 if $output < 0; \' + what.recur_flat.value + \' + \' + what.recur_hourly_charge.value + \' * $hours + \' + what.recur_input_charge.value + \' * $input + \' + what.recur_output_charge.value + \' * $output + \' + what.recur_total_charge.value + \' * $total ;\'',
  },

;

my %plandata = map { /^(\w+)=(.*)$/; ( $1 => $2 ); }
                    split("\n", $part_pkg->plandata );

tie my %options, 'Tie::IxHash', map { $_=>$plans{$_}->{'name'} } keys %plans;

my @form_select = ();
if ( $conf->exists('enable_taxclasses') ) {
  push @form_select, 'taxclass';
} else {
  push @fixups, 'taxclass'; #hidden
}


my $widget = new HTML::Widgets::SelectLayers(
  'selected_layer' => $part_pkg->plan,
  'options'        => \%options,
  'form_name'      => 'dummy',
  'form_action'    => 'process/part_pkg.cgi',
  'form_text'      => [ qw(pkg comment freq clone pkgnum pkgpart), @fixups ],
  'form_checkbox'  => [ qw(setuptax recurtax disabled) ],
  'form_select'    => [ @form_select ],
  'fixup_callback' => sub {
                        #my $ = @_;
                        my $html = '';
                        for my $p ( keys %plans ) {
                          $html .= "if ( what.plan.value == \"$p\" ) {
                                      what.setup.value = $plans{$p}->{setup} ;
                                      what.recur.value = $plans{$p}->{recur} ;
                                    }\n";
                        }
                        $html;
                      },
  'layer_callback' => sub {
    my $layer = shift;
    my $html = qq!<INPUT TYPE="hidden" NAME="plan" VALUE="$layer">!.
               ntable("#cccccc",2);
    my $href = $plans{$layer}->{'fields'};
    foreach my $field ( exists($plans{$layer}->{'fieldorder'})
                          ? @{$plans{$layer}->{'fieldorder'}}
                          : keys %{ $href }
                      ) {

      $html .= '<TR><TD ALIGN="right">'. $href->{$field}{'name'}. '</TD><TD>';

      if ( ! exists($href->{$field}{'type'}) ) {
        $html .= qq!<INPUT TYPE="text" NAME="$field" VALUE="!.
                 ( exists($plandata{$field})
                     ? $plandata{$field}
                     : $href->{$field}{'default'} ).
                 qq!" onChange="fchanged(this)">!;
      } elsif ( $href->{$field}{'type'} eq 'select_multiple' ) {
        $html .= qq!<SELECT MULTIPLE NAME="$field" onChange="fchanged(this)">!;
        foreach my $record (
          qsearch( $href->{$field}{'select_table'},
                   $href->{$field}{'select_hash'}   )
        ) {
          my $value = $record->getfield($href->{$field}{'select_key'});
          $html .= qq!<OPTION VALUE="$value"!.
                   (  $plandata{$field} =~ /(^|, *)$value *(,|$)/
                        ? ' SELECTED'
                        : ''          ).
                   '>'. $record->getfield($href->{$field}{'select_label'})
        }
        $html .= '</SELECT>';
      }

      $html .= '</TD></TR>';
    }
    $html .= '</TABLE>';

    $html .= '<INPUT TYPE="hidden" NAME="plandata" VALUE="'.
             join(',', keys %{ $href } ). '">'.
             '<BR><BR>';
             
    $html .= '<INPUT TYPE="submit" VALUE="'.
             ( $hashref->{pkgpart} ? "Apply changes" : "Add package" ).
             '" onClick="fchanged(this)">';

    $html .= '<BR><BR>don\'t edit this unless you know what you\'re doing '.
             '<INPUT TYPE="button" VALUE="refresh expressions" '.
               'onClick="fchanged(this)">'.
             ntable("#cccccc",2).
             '<TR><TD>'.
             '<FONT SIZE="1">Setup expression<BR>'.
             '<INPUT TYPE="text" NAME="setup" SIZE="160" VALUE="'.
               $hashref->{setup}. '" onLoad="fchanged(this)">'.
             '</FONT><BR>'.
             '<FONT SIZE="1">Recurring espression<BR>'.
             '<INPUT TYPE="text" NAME="recur" SIZE="160" VALUE="'.
               $hashref->{recur}. '" onLoad="fchanged(this)">'.
             '</FONT>'.
             '</TR></TD>'.
             '</TABLE>';

    $html;

  },
);

%>

<BR>
Price plan <%= $widget->html %>
  </BODY>
</HTML>
