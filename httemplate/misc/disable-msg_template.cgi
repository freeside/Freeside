% if ( @error ) {
<& /elements/errorpage-popup.html, @error &>
% } else {
<& /elements/header-popup.html, "Template ${actioned}" &>
  <SCRIPT TYPE="text/javascript">
    window.top.location.reload();
  </SCRIPT>
</BODY>
</HTML>
% }
<%init>

my $curuser = $FS::CurrentUser::CurrentUser;
my $conf = FS::Conf->new;
my @error;
my $actioned;

die "access denied"
  unless $curuser->access_right([ 'Edit templates', 'Edit global templates' ]);

my $msgnum = $cgi->param('msgnum');
$msgnum =~ /^\d+$/ or die "bad msgnum '$msgnum'";
my $msg_template = qsearchs({
  table     => 'msg_template',
  hashref   => { msgnum => $msgnum },
  extra_sql => ' AND '.
    $curuser->agentnums_sql(null_right => 'Edit global templates'),
});
die "unknown msgnum $msgnum" unless $msg_template;

if ( $cgi->param('enable') ) {
  $actioned = 'enabled';
  $msg_template->set('disabled' => '');
} else {
  $actioned = 'disabled';
  # make sure it's not in use anywhere
  my @inuse;

  # notice, letter, notice_to events (if they're enabled)
  my @events = qsearch({
    table     => 'part_event_option',
    addl_from => ' JOIN part_event USING (eventpart)',
    hashref   => {
      optionname => 'msgnum',
      optionvalue => $msgnum,
    },
    extra_sql => ' AND disabled IS NULL',
  });
  push @inuse, map {"Billing event #".$_->eventpart} @events;

  # send_email and rt_ticket exports
  my @exports = qsearch( 'part_export_option', {
    optionname => { op => 'LIKE', value => '%_template' },
    optionvalue => $msgnum,
  });
  push @inuse, map {"Export #".$_->exportnum} @exports;

  # payment_receipt_msgnum, decline_msgnum, etc.
  my @confs = qsearch( 'conf', {
    name => { op => 'LIKE', value => '%_msgnum' },
    value => $msgnum,
  });
  push @inuse, map {"Configuration setting ".$_->name} @confs;
  # XXX pending queue jobs?
  if (@inuse) {
    @error = ("This template is in use.  Check the following settings:",
              @inuse);
  }

  # good to go
  $msg_template->set(disabled => 'Y');
}
if (!@error) {
  my $error = $msg_template->replace;
  push @error, $error if $error;
}
</%init>
