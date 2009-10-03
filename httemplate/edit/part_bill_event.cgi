<% include('/elements/header.html',
      "$action Invoice Event Definition",
      menubar(
        'View all invoice events' => popurl(2). 'browse/part_bill_event.cgi',
      )
    )
%>

<% include('/elements/error.html') %>

<FORM ACTION="<% popurl(1) %>process/part_bill_event.cgi" NAME="editEvent" METHOD=POST>
<INPUT TYPE="hidden" NAME="eventpart" VALUE="<% $part_bill_event->eventpart %>">
Invoice Event #<% $hashref->{eventpart} ? $hashref->{eventpart} : "(NEW)" %>

<%  ntable("#cccccc",2) %>

  <TR>
    <TD ALIGN="right">Event name </TD>
    <TD><INPUT TYPE="text" NAME="event" VALUE="<% $hashref->{event} %>"></TD>
  </TR>

  <TR>
    <TD ALIGN="right">For </TD>
    <TD>
      <SELECT NAME="payby" <% $hashref->{eventpart} ? '' : 'MULTIPLE SIZE=7'%>>
% tie my %payby, 'Tie::IxHash', FS::payby->cust_payby2longname;
%           foreach my $payby ( keys %payby ) {
          <OPTION VALUE="<% $payby %>"<% ($part_bill_event->payby eq $payby) ? ' SELECTED' : '' %>><% $payby{$payby} %></OPTION>
% } 
      </SELECT> customers
    </TD>
  </TR>
% my $days = $hashref->{seconds}/86400; 


  <TR>
    <TD ALIGN="right">After</TD>
    <TD><INPUT TYPE="text" NAME="days" VALUE="<% $days %>"> days</TD>
  </TR>

  <TR>
    <TD ALIGN="right">Test event</TD>
    <TD>
      <SELECT NAME="freq">
% tie my %freq, 'Tie::IxHash', '1d' => 'daily', '1m' => 'monthly';
%           foreach my $freq ( keys %freq ) {
%        


          <OPTION VALUE="<% $freq %>"<% ($part_bill_event->freq eq $freq) ? ' SELECTED' : '' %>><% $freq{$freq} %></OPTION>
% } 


      </SELECT>
    </TD>
  </TR>


  <TR>
    <TD ALIGN="right">Disabled</TD>
    <TD>
      <INPUT TYPE="checkbox" NAME="disabled" VALUE="Y"<% $hashref->{disabled} eq 'Y' ? ' CHECKED' : '' %>>
    </TD>
  </TR>

  <TR>
    <TD VALIGN="top" ALIGN="right">Action</TD>
    <TD>
%
%
%#print ntable();
%
%sub select_pkgpart {
%  my $label = shift;
%  my $plandata = shift;
%  my %selected = map { $_=>1 } split(/,\s*/, $plandata->{$label});
%  qq(<SELECT NAME="$label" MULTIPLE>).
%  join("\n", map {
%    '<OPTION VALUE="'. $_->pkgpart. '"'.
%    ( $selected{$_->pkgpart} ? ' SELECTED' : '' ).
%    '>'. $_->pkg_comment
%  } qsearch('part_pkg', { 'disabled' => '' } ) ).
%  '</SELECT>';
%}
%
%sub select_agentnum {
%  my $plandata = shift;
%  #my $agentnum = $plandata->{'agentnum'};
%  my %agentnums = map { $_=>1 } split(/,\s*/, $plandata->{'agentnum'});
%  '<SELECT NAME="agentnum" MULTIPLE>'.
%  join("\n", map {
%    '<OPTION VALUE="'. $_->agentnum. '"'.
%    ( $agentnums{$_->agentnum} ? ' SELECTED' : '' ).
%    '>'. $_->agent
%  } qsearch('agent', { 'disabled' => '' } ) ).
%  '</SELECT>';
%}
%
%sub honor_dundate {
%  my $label = shift;
%  my $plandata = shift;
%  '<TABLE>'.
%  '<TR><TD ALIGN="right">Allow delay until dun date? </TD>'.
%  qq(<TD><INPUT TYPE="checkbox" NAME="$label" VALUE="$label => 1," ).
%    ( $plandata->{$label} eq "$label => 1," ? 'CHECKED' : '' ).
%  '>'.
%  '</TD></TR>'.
%  '</TABLE>'
%}
%
%my $conf = new FS::Conf;
%my $money_char = $conf->config('money_char') || '$';
%
%my $late_taxclass = '';
%my $late_percent_taxclass = '';
%if ( $conf->exists('enable_taxclasses') ) {
%  $late_taxclass =
%    '<BR>Taxclass '.
%    include('/elements/select-taxclass.html',
%              'curr_value' => '%%%late_taxclass%%%',
%              'name' => 'late_taxclass' );
%  $late_percent_taxclass =
%    '<BR>Taxclass '.
%    include('/elements/select-taxclass.html',
%              'curr_value' => '%%%late_percent_taxclass%%%',
%              'name' => 'late_percent_taxclass' );
%}
%
%#this is pretty kludgy right here.
%tie my %events, 'Tie::IxHash',
%
%  'fee' => {
%    'name'   => 'Late fee (flat)',
%    'code'   => '$cust_main->charge( %%%charge%%%, \'%%%reason%%%\', \'$%%%charge%%%\', \'%%%late_taxclass%%%\' );',
%    'html'   => 
%      'Amount <INPUT TYPE="text" SIZE="7" NAME="charge" VALUE="%%%charge%%%">'.
%      '<BR>Reason <INPUT TYPE="text" NAME="reason" VALUE="%%%reason%%%">'.
%      $late_taxclass,
%    'weight' => 10,
%  },
%  'fee_percent' => {
%    'name'   => 'Late fee (percentage)',
%    'code'   => '$cust_main->charge( sprintf(\'%.2f\', $cust_bill->owed * %%%percent%%% / 100 ), \'%%%percent_reason%%%\', \'%%%percent%%% percent\', \'%%%late_percent_taxclass%%%\' );',
%    'html'   => 
%      'Percent <INPUT TYPE="text" SIZE="2" NAME="percent" VALUE="%%%percent%%%">%'.
%      '<BR>Reason <INPUT TYPE="text" NAME="percent_reason" VALUE="%%%percent_reason%%%">'.
%      $late_percent_taxclass,
%    'weight' => 10,
%  },
%  'suspend' => {
%    'name'   => 'Suspend',
%    'code'   => '$cust_main->suspend(reason => %%%sreason%%%, %%%honor_dundate%%% );',
%    'html'   => sub { &honor_dundate('honor_dundate', @_) },
%    'weight' => 10,
%    'reason' => 'S',
%  },
%  'suspend-if-balance' => {
%    'name'   => 'Suspend if balance (this invoice and previous) over',
%    'code'   => '$cust_bill->cust_suspend_if_balance_over( %%%balanceover%%%, reason => %%%sreason%%%, %%%balance_honor_dundate%%% );',
%    'html'   => sub { " $money_char ". '<INPUT TYPE="text" SIZE="7" NAME="balanceover" VALUE="%%%balanceover%%%"> '. &honor_dundate('balance_honor_dundate', @_) },
%    'weight' => 10,
%    'reason' => 'S',
%  },
%  'suspend-if-pkgpart' => {
%    'name'   => 'Suspend packages',
%    'code'   => '$cust_main->suspend_if_pkgpart({pkgparts => [%%%if_pkgpart%%%,], reason => %%%sreason%%%, %%%if_pkgpart_honor_dundate%%% });',
%    'html'   => sub { &select_pkgpart('if_pkgpart', @_). &honor_dundate('if_pkgpart_honor_dundate', @_) },
%    'weight' => 10,
%    'reason' => 'S',
%  },
%  'suspend-unless-pkgpart' => {
%    'name'   => 'Suspend packages except',
%    'code'   => '$cust_main->suspend_unless_pkgpart({unless_pkgpart => [%%%unless_pkgpart%%%], reason => %%%sreason%%%, %%%unless_pkgpart_honor_dundate%%% });',
%    'html'   => sub { &select_pkgpart('unless_pkgpart', @_). &honor_dundate('unless_pkgpart_honor_dundate' => @_) },
%    'weight' => 10,
%    'reason' => 'S',
%  },
%  'cancel' => {
%    'name'   => 'Cancel',
%    'code'   => '$cust_main->cancel(reason => %%%creason%%%);',
%    'weight' => 80, #10,
%    'reason' => 'C',
%  },
%
%  'addpost' => {
%    'name' => 'Add postal invoicing',
%    'code' => '$cust_main->invoicing_list_addpost(); "";',
%    'weight'  => 20,
%  },
%
%  'comp' => {
%    'name' => 'Pay invoice with a complimentary "payment"',
%    'code' => '$cust_bill->comp();',
%    'weight' => 90, #30,
%  },
%
%  'credit' => {
%    'name'   => "Create and apply a credit for the customer's balance (i.e. write off as bad debt)",
%    'code'   => '$cust_main->credit( $cust_main->balance, \'%%%credit_reason%%%\' );',
%    'html'   => '<INPUT TYPE="text" NAME="credit_reason" VALUE="%%%credit_reason%%%">',
%    'weight' => 30,
%  },
%
%  'realtime-card' => {
%    'name' => 'Run card with a <a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a> realtime gateway',
%    'code' => '$cust_bill->realtime_card();',
%    'weight' => 30,
%  },
%
%  'realtime-check' => {
%    'name' => 'Run check with a <a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a> realtime gateway',
%    'code' => '$cust_bill->realtime_ach();',
%    'weight' => 30,
%  },
%
%  'realtime-lec' => {
%    'name' => 'Run phone bill ("LEC") billing with a <a href="http://search.cpan.org/search?mode=module&query=Business%3A%3AOnlinePayment">Business::OnlinePayment</a> realtime gateway',
%    'code' => '$cust_bill->realtime_lec();',
%    'weight' => 30,
%  },
%
%  'batch-card' => {
%    'name' => 'Add card or check to a pending batch',
%    'code' => '$cust_bill->batch_card(%options);',
%    'weight' => 40,
%  },
%
%  
%  #'retriable' => {
%  #  'name' => 'Mark batched card event as retriable',
%  #  'code' => '$cust_pay_batch->retriable();',
%  #  'weight' => 60,
%  #},
%
%  'send' => {
%    'name' => 'Send invoice (email/print/fax)',
%    'code' => '$cust_bill->send();',
%    'weight' => 50,
%  },
%
%  'send_email' => {
%    'name' => 'Send invoice (email only)',
%    'code' => '$cust_bill->email();',
%    'weight' => 50,
%  },
%
%  'send_alternate' => {
%    'name' => 'Send invoice (email/print/fax) with alternate template',
%    'code' => '$cust_bill->send(\'%%%templatename%%%\');',
%    'html' =>
%        '<INPUT TYPE="text" NAME="templatename" VALUE="%%%templatename%%%">',
%    'weight' => 50,
%  },
%
%  'send_if_newest' => {
%    'name' => 'Send invoice (email/print/fax) with alternate template, if it is still the newest invoice (useful for late notices - set to 31 days or later)',
%    'code' => '$cust_bill->send_if_newest(\'%%%if_newest_templatename%%%\');',
%    'html' =>
%        '<INPUT TYPE="text" NAME="if_newest_templatename" VALUE="%%%if_newest_templatename%%%">',
%    'weight' => 50,
%  },
%
%  'send_agent' => {
%    'name' => 'Send invoice (email/print/fax) ',
%    'code' => '$cust_bill->send( \'%%%agent_templatename%%%\',
%                                 [ %%%agentnum%%% ],
%                                 \'%%%agent_invoice_from%%%\',
%                                 %%%agent_balanceover%%%
%                               );',
%    'html' => sub {
%        '<TABLE BORDER=0>
%          <TR>
%            <TD ALIGN="right">only for agent(s) </TD>
%            <TD>'. &select_agentnum(@_). '</TD>
%          </TR>
%          <TR>
%            <TD ALIGN="right">with template </TD>
%            <TD>
%              <INPUT TYPE="text" NAME="agent_templatename" VALUE="%%%agent_templatename%%%">
%            </TD>
%          </TR>
%          <TR>
%            <TD ALIGN="right">email From: </TD>
%            <TD>
%              <INPUT TYPE="text" NAME="agent_invoice_from" VALUE="%%%agent_invoice_from%%%">
%            </TD>
%          </TR>
%          <TR>
%            <TD ALIGN="right">if balance (this invoice and previous) over
%            </TD>
%            <TD>
%              '. $money_char. '<INPUT TYPE="text" SIZE="7" NAME="agent_balanceover" VALUE="%%%agent_balanceover%%%">
%            </TD>
%          </TR>
%        </TABLE>';
%    },
%    'weight' => 50,
%  },
%
%  'send_csv_ftp' => {
%    'name' => 'Upload CSV invoice data to an FTP server',
%    'code' => '$cust_bill->send_csv( protocol   => \'ftp\',
%                                     server     => \'%%%ftpserver%%%\',
%                                     username   => \'%%%ftpusername%%%\',
%                                     password   => \'%%%ftppassword%%%\',
%                                     dir        => \'%%%ftpdir%%%\',
%                                     \'format\' => \'%%%ftpformat%%%\',
%                                   );',
%    'html' =>
%        '<TABLE BORDER=0>'.
%        '<TR><TD ALIGN="right">Format ("default" or "billco"): </TD>'.
%          '<TD>'.
%            '<!--'.
%            '<SELECT NAME="ftpformat">'.
%              '<OPTION VALUE="default">Default'.
%              '<OPTION VALUE="billco">Billco'.
%            '</SELECT>'.
%            '-->'.
%            '<INPUT TYPE="text" NAME="ftpformat" VALUE="%%%ftpformat%%%">'.
%          '</TD></TR>'.
%        '<TR><TD ALIGN="right">FTP server: </TD>'.
%          '<TD><INPUT TYPE="text" NAME="ftpserver" VALUE="%%%ftpserver%%%">'.
%          '</TD></TR>'.
%        '<TR><TD ALIGN="right">FTP username: </TD><TD>'.
%          '<INPUT TYPE="text" NAME="ftpusername" VALUE="%%%ftpusername%%%">'.
%          '</TD></TR>'.
%        '<TR><TD ALIGN="right">FTP password: </TD><TD>'.
%          '<INPUT TYPE="text" NAME="ftppassword" VALUE="%%%ftppassword%%%">'.
%          '</TD></TR>'.
%        '<TR><TD ALIGN="right">FTP directory: </TD>'.
%          '<TD><INPUT TYPE="text" NAME="ftpdir" VALUE="%%%ftpdir%%%">'.
%          '</TD></TR>'.
%        '</TABLE>',
%    'weight' => 50,
%  },
%
%  'spool_csv' => {
%    'name' => 'Spool CSV invoice data',
%    'code' => '$cust_bill->spool_csv(
%                 \'format\' => \'%%%spoolformat%%%\',
%                 \'dest\'   => \'%%%spooldest%%%\',
%                 \'balanceover\' => \'%%%spoolbalanceover%%%\',
%                 \'agent_spools\' => \'%%%spoolagent_spools%%%\',
%               );',
%    'html' => sub {
%       my $plandata = shift;
%
%       my $html =
%       '<TABLE BORDER=0>'.
%       '<TR><TD ALIGN="right">Format: </TD>'.
%         '<TD>'.
%           '<SELECT NAME="spoolformat">';
%
%       foreach my $option (qw( default billco )) {
%         $html .= qq(<OPTION VALUE="$option");
%         $html .= ' SELECTED' if $option eq $plandata->{'spoolformat'};
%         $html .= ">\u$option";
%       }
%
%       $html .= 
%           '</SELECT>'.
%         '</TD></TR>'.
%       '<TR><TD ALIGN="right">For destination: </TD>'.
%         '<TD>'.
%           '<SELECT NAME="spooldest">';
%
%       tie my %dest, 'Tie::IxHash', 
%         ''      => '(all)',
%         'POST'  => 'Postal Mail',
%         'EMAIL' => 'Email',
%         'FAX'   => 'Fax',
%       ;
%
%       foreach my $dest (keys %dest) {
%         $html .= qq(<OPTION VALUE="$dest");
%         $html .= ' SELECTED' if $dest eq $plandata->{'spooldest'};
%         $html .= '>'. $dest{$dest};
%       }
%
%       $html .=
%           '</SELECT>'.
%         '</TD></TR>'.
%
%       '<TR>'.
%         '<TD ALIGN="right">if balance (this invoice and previous) over </TD>'.
%         '<TD>'.
%           "$money_char ".
%           '<INPUT TYPE="text" SIZE="7" NAME="spoolbalanceover" VALUE="%%%spoolbalanceover%%%">'.
%         '</TD>'.
%       '<TR><TD ALIGN="right">Individual per-agent spools? </TD>'.
%         '<TD><INPUT TYPE="checkbox" NAME="spoolagent_spools" VALUE="1" '.
%           ( $plandata->{'spoolagent_spools'} ? 'CHECKED' : '' ).
%           '>'.
%         '</TD></TR>'.
%       '</TABLE>';
%
%       $html;
%    },
%    'weight' => 50,
%  },
%
%  'bill' => {
%    'name' => 'Generate invoices (normally only used with a <i>Late Fee</i> event)',
%    'code' => '$cust_main->bill();',
%    'weight'  => 60,
%  },
%
%  'apply' => {
%    'name' => 'Apply unapplied payments and credits',
%    'code' => '$cust_main->apply_payments_and_credits; "";',
%    'weight'  => 70,
%  },
%
%;
%
<SCRIPT TYPE="text/javascript">var myreasons = new Array();</SCRIPT>
%foreach my $event ( keys %events ) {
%  my %plandata = map { /^(\w+) (.*)$/; ($1, $2); }
%                   split(/\n/, $part_bill_event->plandata);
%  my $html = $events{$event}{html};
%  if ( ref($html) eq 'CODE' ) {
%    $html = &{$html}(\%plandata);
%  }
%  while ( $html =~ /%%%(\w+)%%%/ ) {
%    my $field = $1;
%    $html =~ s/%%%$field%%%/$plandata{$field}/;
%  }
%
<SCRIPT TYPE="text/javascript">myreasons.push('<% $events{$event}{reason} %>');
</SCRIPT>
%  if ($event eq $part_bill_event->plan){
%    $currentreasonclass=$events{$event}{reason};
%  }
%  print ntable( "#cccccc", 2).
%        qq!<TR><TD><INPUT TYPE="radio" NAME="plan_weight_eventcode" !;
%  print "CHECKED " if $event eq $part_bill_event->plan;
%  print qq!onClick="showhide_table()" !;
%  print qq!VALUE="!.  $event. ":". $events{$event}{weight}. ":".
%        encode_entities($events{$event}{code}).
%        qq!">$events{$event}{name}</TD>!;
%  print '<TD>'. $html. '</TD>' if $html;
%  print qq!</TR>!;
%  print '</TABLE>';
%  print qq!<HR WIDTH="90%">!;
%}
%
%  if ($currentreasonclass eq 'C'){
%    if ($cgi->param('creason') =~ /^(-?\d+)$/){
%      $creason =  $1;
%    }else{
%      $creason = $part_bill_event->reason;
%    }
%    if ($cgi->param('newcreasonT') =~ /^(\d+)$/){
%      $newcreasonT =  $1;
%    }
%    if ($cgi->param('newcreason') =~ /^([\w\s]+)$/){
%      $newcreason =  $1;
%    }
%  }elsif ($currentreasonclass eq 'S'){
%    if ($cgi->param('sreason') =~ /^(-?\d+)$/){
%      $sreason =  $1;
%    }else{
%      $sreason = $part_bill_event->reason;
%    }
%    if ($cgi->param('newsreasonT') =~ /^(\d+)$/){
%      $newsreasonT =  $1;
%    }
%    if ($cgi->param('newsreason') =~ /^([\w\s]+)$/){
%      $newsreason =  $1;
%    }
%  }
%

</TD></TR>
</TABLE>

<SCRIPT TYPE="text/javascript">
  function showhide_table()
  {
    for(i=0;i<document.editEvent.plan_weight_eventcode.length;i++){
      if (document.editEvent.plan_weight_eventcode[i].checked == true){
        currentevent=i;
      }
    }
    if(myreasons[currentevent] == 'C'){
      document.getElementById('Ctable').style.display = 'inline';
      document.getElementById('Stable').style.display = 'none';
    }else if(myreasons[currentevent] == 'S'){
      document.getElementById('Ctable').style.display = 'none';
      document.getElementById('Stable').style.display = 'inline';
    }else{
      document.getElementById('Ctable').style.display = 'none';
      document.getElementById('Stable').style.display = 'none';
    }
  }
</SCRIPT>

<TABLE BGCOLOR="#cccccc" BORDER=0 WIDTH="100%">
<TR><TD>
<TABLE BORDER=0 id="Ctable" style="display:<% $currentreasonclass eq 'C' ? 'inline' : 'none' %>">
<% include('/elements/tr-select-reason.html',
             'field'          => 'creason',
             'reason_class'   => 'C',
             'curr_value'     => $creason,
             'init_type'      => $newcreasonT,
             'init_newreason' => $newcreason
          )
%>
</TABLE>
</TR></TD>
</TABLE>

<TABLE BGCOLOR="#cccccc" BORDER=0 WIDTH="100%">
<TR><TD>
<TABLE BORDER=0 id="Stable" style="display:<% $currentreasonclass eq 'S' ? 'inline' : 'none' %>">
<% include('/elements/tr-select-reason.html',
             'field'          => 'sreason',
             'reason_class'   => 'S',
             'curr_value'     => $sreason,
             'init_type'      => $newsreasonT,
             'init_newreason' => $newsreason
          )
%>
</TABLE>
</TR></TD>
</TABLE>
    
%
%print qq!<INPUT TYPE="submit" VALUE="!,
%      $hashref->{eventpart} ? "Apply changes" : "Add invoice event",
%      qq!">!;
%


    </FORM>

<% include('/elements/footer.html') %>

<%init>

die "access denied"
  unless $FS::CurrentUser::CurrentUser->access_right('Configuration');

if ( $cgi->param('eventpart') && $cgi->param('eventpart') =~ /^(\d+)$/ ) {
  $cgi->param('eventpart', $1);
} else {
  $cgi->param('eventpart', '');
}

my ($creason, $newcreasonT, $newcreason);
my ($sreason, $newsreasonT, $newsreason);

my ($query) = $cgi->keywords;
my $action = '';
my $part_bill_event = '';
my $currentreasonclass = '';
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

</%init>
