package FS::part_export::artera_turbo;

use vars qw(@ISA %info);
use Tie::IxHash;
use FS::Record qw(qsearch);
use FS::part_export;
use FS::cust_svc;
use FS::svc_external;

@ISA = qw(FS::part_export);

tie my %options, 'Tie::IxHash',
  'rid'        => { 'label' => 'Reseller ID (RID)' },
  'username'   => { 'label' => 'Reseller username', },
  'password'   => { 'label' => 'Reseller password', },
  'pid'        => { 'label' => 'Artera Product ID', },
  'priceid'    => { 'label' => 'Artera Price ID', },
  'agent_aid'  => { 'label' => 'Export agentnum values to Artera AID',
                    'type'  => 'checkbox',
                  },
  'aid'        => { 'label' => 'Artera Agent ID to use if not using agentnum values', },
  'production' => { 'label' => 'Production mode (leave unchecked for staging)',
                    'type'  => 'checkbox',
                  },
  'debug'      => { 'label' => 'Enable debug logging',
                    'type'  => 'checkbox',
                  },
  'enable_edit' => { 'label' => 'Enable local editing of Artera serial numbers and key codes (note that the changes will NOT be exported to Artera)',
                     'type'  => 'checkbox',
                   },
;

%info = (
  'svc'      => 'svc_external',
  #'svc'      => [qw( svc_acct svc_forward )],
  'desc'     =>
    'Real-time export to Artera Turbo Reseller API',
  'options'  => \%options,
  #'nodomain' => 'Y',
  'no_machine' => 1,
  'notes'    => <<'END'
Real-time export to <a href="http://www.arteraturbo.com/">Artera Turbo</a>
Reseller API.  Requires installation of
<a href="http://search.cpan.org/dist/Net-Artera">Net::Artera</a>
from CPAN.  You probably also want to:
<UL>
  <LI>In the configuration UI section: set the <B>svc_external-skip_manual</B> and <B>svc_external-display_type</B> configuration values.
  <LI>In the message catalog: set <B>svc_external-id</B> to <I>Artera Serial Number</I> and set <B>svc_external-title</B> to <I>Artera Key Code</I>.
</UL>
END
);

sub rebless { shift; }

sub _new_Artera {
  my $self = shift;

  my $artera = new Net::Artera (
    map { $_ => $self->option($_) }
        qw( rid username password production )
  );
}


sub _export_insert {
  my($self, $svc_external) = (shift, shift);

  # want the ASN (serial) and AKC (key code) right away

  eval "use Net::Artera;";
  return $@ if $@;
  $Net::Artera::DEBUG = 1 if $self->option('debug');
  my $artera = $self->_new_Artera;

  my $cust_pkg = $svc_external->cust_svc->cust_pkg;
  my $part_pkg = $cust_pkg->part_pkg;
  my @svc_acct = grep { $_->table eq 'svc_acct' }
                 map { $_->svc_x }
                 sort { my $svcpart = $part_pkg->svcpart('svc_acct');
                        ($b->svcpart==$svcpart) cmp ($a->svcpart==$svcpart); }
                 qsearch('cust_svc', { 'pkgnum' => $cust_pkg->pkgnum } );
  my $email = scalar(@svc_acct) ? $svc_acct[0]->email : '';
  
  my $cust_main = $cust_pkg->cust_main;

  my $result = $artera->newOrder(
    'pid'     => $self->option('pid'),
    'priceid' => $self->option('priceid'),
    'email'   => $email,
    'cname'   => $cust_main->name,
    'ref'     => $svc_external->svcnum,
    'aid'     => ( $self->option('agent_aid')
                     ? $cust_main->agentnum
                     : $self->option('aid')   ),
    'add1'    => $cust_main->address1,
    'add2'    => $cust_main->address2,
    'add3'    => $cust_main->city,
    'add4'    => $cust_main->state,
    'zip'     => $cust_main->zip,
    'cid'     => $cust_main->country,
    'phone'   => $cust_main->daytime || $cust_main->night,
    'fax'     => $cust_main->fax,
  );

  if ( $result->{'id'} == 1 ) {
    my $new = new FS::svc_external { $svc_external->hash };
    $new->id(sprintf('%010d', $result->{'ASN'}));
    $new->title( substr('0000000000'.uc($result->{'AKC'}), -10) );
    $new->replace($svc_external);
  } else {
    $result->{'message'} || 'No response from Artera';
  }
}

sub _export_replace {
  my( $self, $new, $old ) = (shift, shift, shift);
  return '' if $self->option('enable_edit');
  return "can't change serial number with Artera"
    if $old->id != $new->id && $old->id;
  return "can't change key code with Artera"
    if $old->title ne $new->title && $old->title;
  '';
}

sub _export_delete {
  my( $self, $svc_external ) = (shift, shift);
  $self->queue_statusChange(17, $svc_external);
}

sub _export_suspend {
  my( $self, $svc_external ) = (shift, shift);
  $self->queue_statusChange(16, $svc_external);
}

sub _export_unsuspend {
  my( $self, $svc_external ) = (shift, shift);
  $self->queue_statusChange(15, $svc_external);
}

sub queue_statusChange {
  my( $self, $status, $svc_external ) = @_;

  my $queue = new FS::queue {
    'svcnum' => $svc_external->svcnum,
    'job'    => 'FS::part_export::artera_turbo::statusChange',
  };
  $queue->insert(
    ( map { $self->option($_) }
          qw( rid username password production ) ),
    $status,
    $svc_external->id,
    $svc_external->title,
    $self->option('debug'),
  );
}

sub statusChange {
  my( $rid, $username, $password, $prod, $status, $id, $title, $debug ) = @_;

  eval "use Net::Artera;";
  return $@ if $@;
  $Net::Artera::DEBUG = 1 if $debug;

  my $artera = new Net::Artera (
    'rid'        => $rid,
    'username'   => $username,
    'password'   => $password,
    'production' => $prod,
  );

  my $result = $artera->statusChange(
    'asn'      => sprintf('%010d', $id),
    'akc'      => substr("0000000000$title", -10),
    'statusid' => $status,
  );

  die $result->{'message'} unless $result->{'id'} == 1;

}

1;

