package FS::svc_domain;

use strict;
use vars qw( @ISA $whois_hack $conf $mydomain $smtpmachine
  $tech_contact $from $to @nameservers @nameserver_ips @template
  @mxmachines @nsmachines $soadefaultttl $soaemail $soaexpire $soamachine
  $soarefresh $soaretry
);
use Carp;
use Mail::Internet;
use Mail::Header;
use Date::Format;
use Net::Whois 1.0;
use FS::Record qw(fields qsearch qsearchs dbh);
use FS::Conf;
use FS::svc_Common;
use FS::cust_svc;
use FS::svc_acct;
use FS::cust_pkg;
use FS::cust_main;
use FS::domain_record;

@ISA = qw( FS::svc_Common );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::domain'} = sub { 
  $conf = new FS::Conf;

  $mydomain = $conf->config('domain');
  $smtpmachine = $conf->config('smtpmachine');

  my($internic)="/registries/internic";
  $tech_contact = $conf->config("$internic/tech_contact");
  $from = $conf->config("$internic/from");
  $to = $conf->config("$internic/to");
  my(@ns) = $conf->config("$internic/nameservers");
  @nameservers=map {
    /^\s*\d+\.\d+\.\d+\.\d+\s+([^\s]+)\s*$/
      or die "Illegal line in $internic/nameservers";
    $1;
  } @ns;
  @nameserver_ips=map {
    /^\s*(\d+\.\d+\.\d+\.\d+)\s+([^\s]+)\s*$/
      or die "Illegal line in $internic/nameservers!";
    $1;
  } @ns;
  @template = map { $_. "\n" } $conf->config("$internic/template");

  @mxmachines    = $conf->config('mxmachines');
  @nsmachines    = $conf->config('nsmachines');
  $soadefaultttl = $conf->config('soadefaultttl');
  $soaemail      = $conf->config('soaemail');
  $soaexpire     = $conf->config('soaexpire');
  $soamachine    = $conf->config('soamachine');
  $soarefresh    = $conf->config('soarefresh');
  $soaretry      = $conf->config('soaretry');

};

=head1 NAME

FS::svc_domain - Object methods for svc_domain records

=head1 SYNOPSIS

  use FS::svc_domain;

  $record = new FS::svc_domain \%hash;
  $record = new FS::svc_domain { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $error = $record->cancel;

=head1 DESCRIPTION

An FS::svc_domain object represents a domain.  FS::svc_domain inherits from
FS::svc_Common.  The following fields are currently supported:

=over 4

=item svcnum - primary key (assigned automatically for new accounts)

=item domain

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new domain.  To add the domain to the database, see L<"insert">.

=cut

sub table { 'svc_domain'; }

=item insert

Adds this domain to the database.  If there is an error, returns the error,
otherwise returns false.

The additional fields I<pkgnum> and I<svcpart> (see L<FS::cust_svc>) should be 
defined.  An FS::cust_svc record will be created and inserted.

The additional field I<action> should be set to I<N> for new domains or I<M>
for transfers.

A registration or transfer email will be submitted unless
$FS::svc_domain::whois_hack is true.

The additional field I<email> can be used to manually set the admin contact
email address on this email.  Otherwise, the svc_acct records for this package 
(see L<FS::cust_pkg>) are searched.  If there is exactly one svc_acct record
in the same package, it is automatically used.  Otherwise an error is returned.

If any I<soamachine> configuration file exists, an SOA record is added to
the domain_record table (see <FS::domain_record>).

If any machines are defined in the I<nsmachines> configuration file, NS
records are added to the domain_record table (see L<FS::domain_record>).

If any machines are defined in the I<mxmachines> configuration file, MX
records are added to the domain_record table (see L<FS::domain_record>).

Any problems adding FS::domain_record records will emit warnings, but will
not return errors from this method.  If your configuration files are correct
you shouln't have any problems.

=cut

sub insert {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  $error = $self->check;
  return $error if $error;

  return "Domain in use (here)"
    if qsearchs( 'svc_domain', { 'domain' => $self->domain } );

  my $whois = $self->whois;
  if ( $self->action eq "N" && ! $whois_hack && $whois ) {
    $dbh->rollback if $oldAutoCommit;
    return "Domain in use (see whois)";
  }
  if ( $self->action eq "M" && ! $whois ) {
    $dbh->rollback if $oldAutoCommit;
    return "Domain not found (see whois)";
  }

  $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $self->submit_internic unless $whois_hack;

  if ( $soamachine ) {
    my $soa = new FS::domain_record {
      'svcnum'  => $self->svcnum,
      'reczone' => '@',
      'recaf'   => 'IN',
      'rectype' => 'SOA',
      'recdata' => "$soamachine $soaemail ( ". time2str("%Y%m%e", time). "00 ".
                   "$soarefresh $soaretry $soaexpire $soadefaultttl )"
    };
    $error = $soa->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "couldn't insert SOA record for new domain: $error";
    }

    foreach my $nsmachine ( @nsmachines ) {
      my $ns = new FS::domain_record {
        'svcnum'  => $self->svcnum,
        'reczone' => '@',
        'recaf'   => 'IN',
        'rectype' => 'NS',
        'recdata' => $nsmachine,
      };
      my $error = $ns->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "couldn't insert NS record for new domain: $error";
      }
    }

    foreach my $mxmachine ( @mxmachines ) {
      my $mx = new FS::domain_record {
        'svcnum'  => $self->svcnum,
        'reczone' => '@',
        'recaf'   => 'IN',
        'rectype' => 'MX',
        'recdata' => $mxmachine,
      };
      my $error = $mx->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "couldn't insert MX record for new domain: $error";
      }
    }

  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  ''; #no error
}

=item delete

Deletes this domain from the database.  If there is an error, returns the
error, otherwise returns false.

The corresponding FS::cust_svc record will be deleted as well.

=item replace OLD_RECORD

Replaces OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my ( $new, $old ) = ( shift, shift );
  my $error;

  return "Can't change domain - reorder."
    if $old->getfield('domain') ne $new->getfield('domain'); 

  $new->SUPER::replace($old);

}

=item suspend

Just returns false (no error) for now.

Called by the suspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item unsuspend

Just returns false (no error) for now.

Called by the unsuspend method of FS::cust_pkg (see L<FS::cust_pkg>).

=item cancel

Just returns false (no error) for now.

Called by the cancel method of FS::cust_pkg (see L<FS::cust_pkg>).

=item check

Checks all fields to make sure this is a valid domain.  If there is an error,
returns the error, otherwise returns false.  Called by the insert and replace
methods.

Sets any fixed values; see L<FS::part_svc>.

=cut

sub check {
  my $self = shift;
  my $error;

  my $x = $self->setfixed;
  return $x unless ref($x);
  my $part_svc = $x;

  #hmm
  my $pkgnum;
  if ( $self->svcnum ) {
    my $cust_svc = qsearchs( 'cust_svc', { 'svcnum' => $self->svcnum } );
    $pkgnum = $cust_svc->pkgnum;
  } else {
    $pkgnum = $self->pkgnum;
  }

  my($recref) = $self->hashref;

  unless ( $whois_hack ) {
    unless ( $self->email ) { #find out an email address
      my @svc_acct;
      foreach ( qsearch( 'cust_svc', { 'pkgnum' => $pkgnum } ) ) {
        my $svc_acct = qsearchs( 'svc_acct', { 'svcnum' => $_->svcnum } );
        push @svc_acct, $svc_acct if $svc_acct;
      }

      if ( scalar(@svc_acct) == 0 ) {
        return "Must order an account in package ". $pkgnum. " first";
      } elsif ( scalar(@svc_acct) > 1 ) {
        return "More than one account in package ". $pkgnum. ": specify admin contact email";
      } else {
        $self->email($svc_acct[0]->username. '@'. $mydomain);
      }
    }
  }

  #if ( $recref->{domain} =~ /^([\w\-\.]{1,22})\.(com|net|org|edu)$/ ) {
  if ( $recref->{domain} =~ /^([\w\-]{1,22})\.(com|net|org|edu)$/ ) {
    $recref->{domain} = "$1.$2";
  # hmmmmmmmm.
  } elsif ( $whois_hack && $recref->{domain} =~ /^([\w\-\.]+)$/ ) {
    $recref->{domain} = $1;
  } else {
    return "Illegal domain ". $recref->{domain}.
           " (or unknown registry - try \$whois_hack)";
  }

  $recref->{action} =~ /^(M|N)$/ or return "Illegal action";
  $recref->{action} = $1;

  $self->ut_textn('purpose');

}

=item whois

Returns the Net::Whois::Domain object (see L<Net::Whois>) for this domain, or
undef if the domain is not found in whois.

(If $FS::svc_domain::whois_hack is true, returns that in all cases instead.)

=cut

sub whois {
  $whois_hack or new Net::Whois::Domain $_[0]->domain;
}

=item _whois

Depriciated.

=cut

sub _whois {
  die "_whois depriciated";
}

=item submit_internic

Submits a registration email for this domain.

=cut

sub submit_internic {
  my $self = shift;

  my $cust_pkg = qsearchs( 'cust_pkg', { 'pkgnum' => $self->pkgnum } );
  return unless $cust_pkg;
  my $cust_main = qsearchs( 'cust_main', { 'custnum' => $cust_pkg->custnum } );
  return unless $cust_main;

  my %subs = (
    'action'       => $self->action,
    'purpose'      => $self->purpose,
    'domain'       => $self->domain,
    'company'      => $cust_main->company 
                        || $cust_main->getfield('first'). ' '.
                           $cust_main->getfield('last')
                      ,
    'city'         => $cust_main->city,
    'state'        => $cust_main->state,
    'zip'          => $cust_main->zip,
    'country'      => $cust_main->country,
    'last'         => $cust_main->getfield('last'),
    'first'        => $cust_main->getfield('first'),
    'daytime'      => $cust_main->daytime,
    'fax'          => $cust_main->fax,
    'email'        => $self->email,
    'tech_contact' => $tech_contact,
    'primary'      => shift @nameservers,
    'primary_ip'   => shift @nameserver_ips,
  );

  #yuck
  my @xtemplate = @template;
  my @body;
  my $line;
  OLOOP: while ( defined( $line = shift @xtemplate ) ) {

    if ( $line =~ /^###LOOP###$/ ) {
      my(@buffer);
      LOADBUF: while ( defined( $line = shift @xtemplate ) ) {
        last LOADBUF if ( $line =~ /^###ENDLOOP###$/ );
        push @buffer, $line;
      }
      my %lubs = (
        'address'      => $cust_main->address2 
                            ? [ $cust_main->address1, $cust_main->address2 ]
                            : [ $cust_main->address1 ]
                          ,
        'secondary'    => [ @nameservers ],
        'secondary_ip' => [ @nameserver_ips ],
      );
      LOOP: while (1) {
        my @xbuffer = @buffer;
        SUBLOOP: while ( defined( $line = shift @xbuffer ) ) {
          if ( $line =~ /###(\w+)###/ ) {
            #last LOOP unless my($lub)=shift@{$lubs{$1}};
            next OLOOP unless my $lub = shift @{$lubs{$1}};
            $line =~ s/###(\w+)###/$lub/e;
            redo SUBLOOP;
          } else {
            push @body, $line;
          }
        } #SUBLOOP
      } #LOOP

    }

    if ( $line =~ /###(\w+)###/ ) {
      #$line =~ s/###(\w+)###/$subs{$1}/eg;
      $line =~ s/###(\w+)###/$subs{$1}/e;
      redo OLOOP;
    } else {
      push @body, $line;
    }

  } #OLOOP

  my $subject;
  if ( $self->action eq "M" ) {
    $subject = "MODIFY DOMAIN ". $self->domain;
  } elsif ( $self->action eq "N" ) { 
    $subject = "NEW DOMAIN ". $self->domain;
  } else {
    croak "submit_internic called with action ". $self->action;
  }

  $ENV{SMTPHOSTS} = $smtpmachine;
  $ENV{MAILADDRESS} = $from;
  my $header = Mail::Header->new( [
    "From: $from",
    "To: $to",
    "Sender: $from",
    "Reply-To: $from",
    "Date: ". time2str("%a, %d %b %Y %X %z", time),
    "Subject: $subject",
  ] );

  my($msg)=Mail::Internet->new(
    'Header' => $header,
    'Body' => \@body,
  );

  $msg->smtpsend or die "Can't send registration email"; #die? warn?

}

=back

=head1 VERSION

$Id: svc_domain.pm,v 1.11 2001-05-22 16:43:28 ivan Exp $

=head1 BUGS

All BIND/DNS fields should be included (and exported).

Delete doesn't send a registration template.

All registries should be supported.

Should change action to a real field.

The $recref stuff in sub check should be cleaned up.

=head1 SEE ALSO

L<FS::svc_Common>, L<FS::Record>, L<FS::Conf>, L<FS::cust_svc>,
L<FS::part_svc>, L<FS::cust_pkg>, L<Net::Whois>, L<ssh>,
L<dot-qmail>, schema.html from the base documentation, config.html from the
base documentation.

=cut

1;


