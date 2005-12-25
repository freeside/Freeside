<!-- mason kludge -->
<%

if ( $cgi->param('eventpart') && $cgi->param('eventpart') =~ /^(\d+)$/ ) {
  $cgi->param('eventpart', $1);
} else {
  $cgi->param('eventpart', '');
}

my ($query) = $cgi->keywords;
my $action = '';
my $part_bill_event = '';
if ( $cgi->param('error') ) {
  $part_bill_event = new FS::part_bill_event ( {
    map { $_, scalar($cgi->param($_)) } fields('part_bill_event')
  } );
}
if ( $query && $query =~ /^(\d+)$/ ) {
  $part_bill_event ||= qsearchs('part_bill_event',{'eventpart'=>$1});
} else {
  $part_bill_event ||= new FS::part_bill_event {};
}
$action ||= $part_bill_event->eventpart ? 'Edit' : 'Add';
my $hashref = $part_bill_event->hashref;

print header("$action Invoice Event Definition", menubar(
  'Main Menu' => popurl(2),
  'View all invoice events' => popurl(2). 'browse/part_bill_event.cgi',
));

print qq!<FONT SIZE="+1" COLOR="#ff0000">Error: !, $cgi->param('error'),
      "</FONT>"
  if $cgi->param('error');

print '<FORM ACTION="', popurl(1), 'process/part_bill_event.cgi" METHOD=POST>'.
      '<INPUT TYPE="hidden" NAME="eventpart" VALUE="'.
      $part_bill_event->eventpart  .'">';
print "Invoice Event #", $hashref->{eventpart} ? $hashref->{eventpart} : "(NEW)";

print ntable("#cccccc",2), <<END;
<TR><TD ALIGN="right">Payby</TD><TD><SELECT NAME="payby">
END

for (qw(CARD DCRD CHEK DCHK LECB BILL COMP)) {
  print qq!<OPTION VALUE="$_"!;
  if ($part_bill_event->payby eq $_) {
    print " SELECTED>$_</OPTION>";
  } else {
    print ">$_</OPTION>";
  }
}

my $days = $hashref->{seconds}/86400;

print <<END;
</SELECT></TD></TR>
<TR><TD ALIGN="right">Event</TD><TD><INPUT TYPE="text" NAME="event" VALUE="$hashref->{event}"></TD></TR>
<TR><TD ALIGN="right">After</TD><TD><INPUT TYPE="text" NAME="days" VALUE="$days"> days</TD></TR>
END

print '<TR><TD ALIGN="right">Disabled</TD><TD>';
print '<INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"';
print ' CHECKED' if $hashref->{disabled} eq "Y";
print '>';
print '</TD></TR>';

print '<TR><TD ALIGN="right">Action</TD><TD>';

#print ntable();

sub select_pkgpart {
  my $label = shift;
  my $plandata = shift;
  my %selected = map { $_=>1 } split(/,\s*/, $plandata->{$label});
  qq(<SELECT NAME="$label" MULTIPLE>).
  join("\n", map {
    '<OPTION VALUE="'. $_->pkgpart. '"'.
    ( $selected{$_->pkgpart} ? ' SELECTED' : '' ).
    '>'. $_->pkg. ' - '. $_->comment
  } qsearch('part_pkg', { 'disabled' => '' } ) ).
  '</SELECT>';
}

sub select_agentnum {
  my $plandata = shift;
  #my $agentnum = $plandata->{'agentnum'};
  my %agentnums = map { $_=>1 } split(/,\s*/, $plandata->{'agentnum'});
  '<SELECT NAME="agentnum" MULTIPLE>'.
  join("\n", map {
    '<OPTION VALUE="'. $_->agentnum. '"'.
    ( $agentnums{$_->agentnum} ? ' SELECTED' : '' ).
    '>'. $_->agent
  } qsearch('agent', { 'disabled' => '' } ) ).
  '</SELECT>';
}

my $conf = new FS::Conf;
my $money_char = $conf->config('money_char') || '$';

#this is pretty kludgy right here.
tie my %events, 'Tie::IxHash',

  'fee' => {
    'name'   => 'Late fee',
    'code'   => '$cust_main->charge( %%%charge%%%, \'%%%reason%%%\' );',
    'html'   => 
      'Amount <INPUT TYPE="text" SIZE="7" NAME="charge" VALUE="%%%charge%%%">'.
      '<BR>Reason <INPUT TYPE="text" NAME="reason" VALUE="%%%reason%%%">',
    'weight' => 10,
  },
  'suspend' => {
    'name'   => 'Suspend',
    'code'   => '$cust_main->suspend();',
    'weight' => 10,
  },
  'suspend' => {
    'name'   => 'Suspend if balance (this invoice and previous) over',
    'code'   => '$cust_bill->cust_suspend_if_balance_over( %%%balanceover%%% );',
    'html'   => " $money_char ". '<INPUT TYPE="text" SIZE="7" NAME="balanceover" VALUE="%%%balanceover%%%">',
    'weight' => 10,
  },
  'suspend-if-pkgpart' => {
    'name'   => 'Suspend packages',
    'code'   => '$cust_main->suspend_if_pkgpart(%%%if_pkgpart%%%);',
    'html'   => sub { &select_pkgpart('if_pkgpart', @_) },
    'weight' => 10,
  },
  'suspend-unless-pkgpart' => {
    'name'   => 'Suspend packages except',
    'code'   => '$cust_main->suspend_unless_pkgpart(%%%unless_pkgpart%%%);',
    'html'   => sub { &select_pkgpart('unless_pkgpart', @_) },
    'weight' => 10,
  },
  'cancel' => {
    'name'   => 'Cancel',
    'code'   => '$cust_main->cancel();',
    'weight' => 10,
  },

  'addpost' => {
    'name' => 'Add postal invoicing',
    'code' => '$cust_main->invoicing_list_addpost(); "";',
    'weight'  => 20,
  },

  'comp' => {
    'name' => 'Pay invoice with a complimentary "payment"',
    'code' => '$cust_bill->comp();',
    'weight' => 30,
  },

  'realtime-card' => {
    'name' => 'Run card with a <a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a> realtime gateway',
    'code' => '$cust_bill->realtime_card();',
    'weight' => 30,
  },

  'realtime-check' => {
    'name' => 'Run check with a <a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a> realtime gateway',
    'code' => '$cust_bill->realtime_ach();',
    'weight' => 30,
  },

  'realtime-lec' => {
    'name' => 'Run phone bill ("LEC") billing with a <a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a> realtime gateway',
    'code' => '$cust_bill->realtime_lec();',
    'weight' => 30,
  },

  'batch-card' => {
    'name' => 'Add card to the pending credit card batch',
    'code' => '$cust_bill->batch_card();',
    'weight' => 40,
  },

  'send' => {
    'name' => 'Send invoice (email/print)',
    'code' => '$cust_bill->send();',
    'weight' => 50,
  },

  'send_alternate' => {
    'name' => 'Send invoice (email/print) with alternate template',
    'code' => '$cust_bill->send(\'%%%templatename%%%\');',
    'html' =>
        '<INPUT TYPE="text" NAME="templatename" VALUE="%%%templatename%%%">',
    'weight' => 50,
  },

  'send_if_newest' => {
    'name' => 'Send invoice (email/print) with alternate template, if it is still the newest invoice (useful for late notices - set to 31 days or later)',
    'code' => '$cust_bill->send_if_newest(\'%%%if_newest_templatename%%%\');',
    'html' =>
        '<INPUT TYPE="text" NAME="if_newest_templatename" VALUE="%%%if_newest_templatename%%%">',
    'weight' => 50,
  },

  'send_agent' => {
    'name' => 'Send invoice (email/print) ',
    'code' => '$cust_bill->send(\'%%%agent_templatename%%%\', [ %%%agentnum%%% ], \'%%%agent_invoice_from%%%\');',
    'html' => sub {
        '<TABLE BORDER=0>
          <TR>
            <TD ALIGN="right">only for agent(s) </TD>
            <TD>'. &select_agentnum(@_). '</TD>
          </TR>
          <TR>
            <TD ALIGN="right">with template </TD>
            <TD>
              <INPUT TYPE="text" NAME="agent_templatename" VALUE="%%%agent_templatename%%%">
            </TD>
          </TR>
          <TR>
            <TD ALIGN="right">email From: </TD>
            <TD>
              <INPUT TYPE="text" NAME="agent_invoice_from" VALUE="%%%agent_invoice_from%%%">
            </TD>
          </TR>
        </TABLE>';
    },
    'weight' => 50,
  },

  'send_csv_ftp' => {
    'name' => 'Upload CSV invoice data to an FTP server',
    'code' => '$cust_bill->send_csv( protocol   => \'ftp\',
                                     server     => \'%%%ftpserver%%%\',
                                     username   => \'%%%ftpusername%%%\',
                                     password   => \'%%%ftppassword%%%\',
                                     dir        => \'%%%ftpdir%%%\',
                                     \'format\' => \'%%%ftpformat%%%\',
                                   );',
    'html' =>
        '<TABLE BORDER=0>'.
        '<TR><TD ALIGN="right">Format ("default" or "billco"): </TD>'.
          '<TD>'.
            '<!--'.
            '<SELECT NAME="ftpformat">'.
              '<OPTION VALUE="default">Default'.
              '<OPTION VALUE="billco">Billco'.
            '</SELECT>'.
            '-->'.
            '<INPUT TYPE="text" NAME="ftpformat" VALUE="%%%ftpformat%%%">'.
          '</TD></TR>'.
        '<TR><TD ALIGN="right">FTP server: </TD>'.
          '<TD><INPUT TYPE="text" NAME="ftpserver" VALUE="%%%ftpserver%%%">'.
          '</TD></TR>'.
        '<TR><TD ALIGN="right">FTP username: </TD><TD>'.
          '<INPUT TYPE="text" NAME="ftpusername" VALUE="%%%ftpusername%%%">'.
          '</TD></TR>'.
        '<TR><TD ALIGN="right">FTP password: </TD><TD>'.
          '<INPUT TYPE="text" NAME="ftppassword" VALUE="%%%ftppassword%%%">'.
          '</TD></TR>'.
        '<TR><TD ALIGN="right">FTP directory: </TD>'.
          '<TD><INPUT TYPE="text" NAME="ftpdir" VALUE="%%%ftpdir%%%">'.
          '</TD></TR>'.
        '</TABLE>',
    'weight' => 50,
  },

  'spool_csv' => {
    'name' => 'Spool CSV invoice data',
    'code' => '$cust_bill->spool_csv(
                 \'format\' => \'%%%spoolformat%%%\',
                 \'dest\'   => \'%%%spooldest%%%\',
                 \'agent_spools\' => \'%%%spoolagent_spools%%%\',
               );',
    'html' => sub {
       my $plandata = shift;

       my $html =
       '<TABLE BORDER=0>'.
       '<TR><TD ALIGN="right">Format: </TD>'.
         '<TD>'.
           '<SELECT NAME="spoolformat">';

       foreach my $option (qw( default billco )) {
         $html .= qq(<OPTION VALUE="$option");
         $html .= ' SELECTED' if $option eq $plandata->{'spoolformat'};
         $html .= ">\u$option";
       }

       $html .= 
           '</SELECT>'.
         '</TD></TR>'.
       '<TR><TD ALIGN="right">For destination: </TD>'.
         '<TD>'.
           '<SELECT NAME="spooldest">';

       tie my %dest, 'Tie::IxHash', 
         ''      => '(all)',
         'POST'  => 'Postal Mail',
         'EMAIL' => 'Email',
         'FAX'   => 'Fax',
       ;

       foreach my $dest (keys %dest) {
         $html .= qq(<OPTION VALUE="$dest");
         $html .= ' SELECTED' if $dest eq $plandata->{'spooldest'};
         $html .= '>'. $dest{$dest};
       }

       $html .=
           '</SELECT>'.
         '</TD></TR>'.
       '<TR><TD ALIGN="right">Individual per-agent spools? </TD>'.
         '<TD><INPUT TYPE="checkbox" NAME="spoolagent_spools" VALUE="1" '.
           ( $plandata->{'spoolagent_spools'} ? 'CHECKED' : '' ).
           '>'.
         '</TD></TR>'.
       '</TABLE>';

       $html;
    },
    'weight' => 50,
  },

  'bill' => {
    'name' => 'Generate invoices (normally only used with a <i>Late Fee</i> event)',
    'code' => '$cust_main->bill();',
    'weight'  => 60,
  },

  'apply' => {
    'name' => 'Apply unapplied payments and credits',
    'code' => '$cust_main->apply_payments; $cust_main->apply_credits; "";',
    'weight'  => 70,
  },

  'collect' => {
    'name' => 'Collect on invoices (normally only used with a <i>Late Fee</i> and <i>Generate Invoice</i> events)',
    'code' => '$cust_main->collect();',
    'weight'  => 80,
  },

;

foreach my $event ( keys %events ) {
  my %plandata = map { /^(\w+) (.*)$/; ($1, $2); }
                   split(/\n/, $part_bill_event->plandata);
  my $html = $events{$event}{html};
  if ( ref($html) eq 'CODE' ) {
    $html = &{$html}(\%plandata);
  }
  while ( $html =~ /%%%(\w+)%%%/ ) {
    my $field = $1;
    $html =~ s/%%%$field%%%/$plandata{$field}/;
  }

  print ntable( "#cccccc", 2).
        qq!<TR><TD><INPUT TYPE="radio" NAME="plan_weight_eventcode" !;
  print "CHECKED " if $event eq $part_bill_event->plan;
  print qq!VALUE="!.  $event. ":". $events{$event}{weight}. ":".
        encode_entities($events{$event}{code}).
        qq!">$events{$event}{name}</TD>!;
  print '<TD>'. $html. '</TD>' if $html;
  print qq!</TR>!;
  print '</TABLE>';
}

#print '</TABLE>';

print <<END;
</TD></TR>
</TABLE>
END

print qq!<INPUT TYPE="submit" VALUE="!,
      $hashref->{eventpart} ? "Apply changes" : "Add invoice event",
      qq!">!;
%>

    </FORM>
  </BODY>
</HTML>

