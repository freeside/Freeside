package FS::part_export::print_template;

use strict;

use base qw( FS::part_export );

use FS::Record qw(qsearchs);
use FS::Misc;
use FS::queue;

=pod

=head1 NAME

FS::part_export::print_template

=head1 SYNOPSIS

Print a document of a template.

=head1 DESCRIPTION

See the L<Text::Template> documentation and the billing documentation for details on the template substitution language.

Currently does not support printing during replace.

=cut

use vars qw( %info );

tie my %options, 'Tie::IxHash',
  'phase'           => { label => 'Print during',
                         type  => 'select',
                         options => [qw(insert delete suspend unsuspend)] },
  'template_text'   => { label => 'Template text',
                         type => 'textarea' },
;

%info = (
                       #unfortunately, FS::part_svc->svc_tables fails at this point, not sure why
  'svc'             => [ map { 'svc_'.$_ } qw(
                           acct domain cert forward mailinglist www broadband cable dsl 
                           conferencing video dish hardware phone pbx circuit port alarm external)
                       ],
  'desc'            => 'Print document during service change, for all services',
  'options'         => \%options,
  'no_machine'      => 1,
  'notes'           => <<'EOF',
Will use the print command configured by the lpr setting.
See the <a href="http://search.cpan.org/dist/Text-Template/lib/Text/Template.pm">Text::Template</a> documentation and the billing documentation for details on the template substitution language.
Fields from the customer and service records are available for substitution, as well as the following fields:

<ul>
<li>$payby - a friendler represenation of the field</li>
<li>$payinfo - the masked payment information</li>
<li>$expdate - the time at which the payment method expires (a UNIX timestamp)</li>
<li>$returnaddress - the invoice return address for this customer's agent</li>
<li>$logo_file - the image stored in the logo.eps setting
</ul>
EOF
);

=head1 Hook Methods

Each of these simply invoke this module's L<print_template> method,
passing the appropriate phase.

=cut

=head2 _export_insert

Hook that is called when service is initially provisioned.
To avoid confusion, don't use for anything else.

=cut

sub _export_insert {
  my $self = shift;
  return $self->print_template('insert',@_);
}

=head2 _export_delete

Hook that is called when service is unprovisioned.
To avoid confusion, don't use for anything else.

=cut

sub _export_delete {
  my $self = shift;
  return $self->print_template('delete',@_);
}

=head2 _export_replace

Hook that is called when provisioned service is edited.
To avoid confusion, don't use for anything else.

Currently not supported for this export.

=cut

sub _export_replace {
  return '';
}

=head2 _export_suspend

Hook that is called when service is suspended.
To avoid confusion, don't use for anything else.

=cut

sub _export_suspend {
  my $self = shift;
  return $self->print_template('suspend',@_);
}

=head2 _export_unsuspend

Hook that is called when service is unsuspended.
To avoid confusion, don't use for anything else.

=cut

sub _export_unsuspend {
  my $self = shift;
  return $self->print_template('unsuspend',@_);
}

=head1 Core Methods

=head2 print_template

Accepts $phase and $svc_x.
If phase matches the configured option, starts a L</process_print_template>
job in the queue.

=cut

sub print_template {
  my ($self, $phase, $svc_x) = @_;
  if ($self->option('phase') eq $phase) {
    my $queue = new FS::queue {
      'job' => 'FS::part_export::print_template::process_print_template',
    };
    my $error = $queue->insert(
      'svcnum'        => $svc_x->svcnum,
      'table'         => $svc_x->table,
      'template_text' => $self->option('template_text'),
    );
    return "can't start print job: $error" if $error;
  }
  return '';
}

=head2 process_print_template

For use as an FS::queue job.  Requires opts svcnum, table and template_text.
Constructs page from template and sends to printer.

=cut

sub process_print_template {
  my %opt = @_;

  my $svc_x = qsearchs($opt{'table'}, { 'svcnum' => $opt{'svcnum'} } )
    or die "invalid " . $opt{'table'} . " svcnum " . $opt{'svcnum'};
  my $cust_main = $svc_x->cust_svc->cust_pkg->cust_main
    or die "could not find customer for service";

  my $ps = $cust_main->print_ps(undef,
    'template_text' => $opt{'template_text'},
    'extra_fields' => {
      map { $_ => $svc_x->$_ } $svc_x->fields,
    },
  );
  my $error = FS::Misc::do_print(
    [ $ps ],
    'agentnum' => $cust_main->agentnum,
  );
  die $error if $error;
}

=head1 SEE ALSO

L<FS::part_export>

=head1 AUTHOR

Jonathan Prykop 
jonathan@freeside.biz

=cut

1;


