package FS::domain_record;

use strict;
use vars qw( @ISA $noserial_hack $DEBUG $me );
use FS::Conf;
#use FS::Record qw( qsearch qsearchs );
use FS::Record qw( qsearchs dbh );
use FS::svc_domain;
use FS::svc_www;

@ISA = qw(FS::Record);

$DEBUG = 0;
$me = '[FS::domain_record]';

=head1 NAME

FS::domain_record - Object methods for domain_record records

=head1 SYNOPSIS

  use FS::domain_record;

  $record = new FS::domain_record \%hash;
  $record = new FS::domain_record { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::domain_record object represents an entry in a DNS zone.
FS::domain_record inherits from FS::Record.  The following fields are currently
supported:

=over 4

=item recnum - primary key

=item svcnum - Domain (see L<FS::svc_domain>) of this entry

=item reczone - partial (or full) zone for this entry

=item recaf - address family for this entry, currently only `IN' is recognized.

=item rectype - record type for this entry (A, MX, etc.)

=item recdata - data for this entry

=item ttl - time to live

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new entry.  To add the entry to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'domain_record'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

sub insert {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( $self->rectype eq '_mstr' ) { #delete all other records
    foreach my $domain_record ( reverse $self->svc_domain->domain_record ) {
      my $error = $domain_record->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return $error;
      }
    }
  }

  my $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  unless ( $self->rectype =~ /^(SOA|_mstr)$/ ) {
    my $error = $self->increment_serial;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $conf = new FS::Conf;
  if ( $self->rectype =~ /^A$/ && ! $conf->exists('disable_autoreverse') ) {
    my $reverse = $self->reverse_record;
    if ( $reverse && ! $reverse->recnum ) {
      my $error = $reverse->insert;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error adding corresponding reverse-ARPA record: $error";
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item delete

Delete this record from the database.

=cut

sub delete {
  my $self = shift;

  return "Can't delete a domain record which has a website!"
    if qsearchs( 'svc_www', { 'recnum' => $self->recnum } );

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::delete;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  unless ( $self->rectype =~ /^(SOA|_mstr)$/ ) {
    my $error = $self->increment_serial;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  my $conf = new FS::Conf;
  if ( $self->rectype =~ /^A$/ && ! $conf->exists('disable_autoreverse') ) {
    my $reverse = $self->reverse_record;
    if ( $reverse && $reverse->recnum && $reverse->recdata eq $self->zone.'.' ){
      my $error = $reverse->delete;
      if ( $error ) {
        $dbh->rollback if $oldAutoCommit;
        return "error removing corresponding reverse-ARPA record: $error";
      }
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

sub replace {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->SUPER::replace(@_);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  unless ( $self->rectype eq 'SOA' ) {
    my $error = $self->increment_serial;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';

}

=item check

Checks all fields to make sure this is a valid entry.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('recnum')
    || $self->ut_number('svcnum')
  ;
  return $error if $error;

  return "Unknown svcnum (in svc_domain)"
    unless qsearchs('svc_domain', { 'svcnum' => $self->svcnum } );

  my $conf = new FS::Conf;

  if ( $conf->exists('zone-underscore') ) {
    $self->reczone =~ /^(@|[a-z0-9_\.\-\*]+)$/i
      or return "Illegal reczone: ". $self->reczone;
    $self->reczone($1);
  } else {
    $self->reczone =~ /^(@|[a-z0-9\.\-\*]+)$/i
      or return "Illegal reczone: ". $self->reczone;
    $self->reczone($1);
  }

  $self->recaf =~ /^(IN)$/ or return "Illegal recaf: ". $self->recaf;
  $self->recaf($1);

  $self->ttl =~ /^([0-9]{0,6})$/ or return "Illegal ttl: ". $self->ttl;        
  $self->ttl($1); 

  my %rectypes = map { $_=>1 } ( @{ $self->rectypes }, '_mstr' );
  return 'Illegal rectype: '. $self->rectype
    unless exists $rectypes{$self->rectype} && $rectypes{$self->rectype};

  return "Illegal reczone for ". $self->rectype. ": ". $self->reczone
    if $self->rectype !~ /^MX$/i && $self->reczone =~ /\*/;

  if ( $self->rectype eq 'SOA' ) {
    my $recdata = $self->recdata;
    $recdata =~ s/\s+/ /g;
    $recdata =~ /^([a-z0-9\.\-]+ [\w\-\+]+\.[a-z0-9\.\-]+ \( ((\d+|((\d+[WDHMS])+)) ){5}\))$/i
      or return "Illegal data for SOA record: $recdata";
    $self->recdata($1);
  } elsif ( $self->rectype eq 'NS' ) {
    $self->recdata =~ /^([a-z0-9\.\-]+)$/i
      or return "Illegal data for NS record: ". $self->recdata;
    $self->recdata($1);
  } elsif ( $self->rectype eq 'MX' ) {
    $self->recdata =~ /^(\d+)\s+([a-z0-9\.\-]+)$/i
      or return "Illegal data for MX record: ". $self->recdata;
    $self->recdata("$1 $2");
  } elsif ( $self->rectype eq 'A' ) {
    $self->recdata =~ /^((\d{1,3}\.){3}\d{1,3})$/
      or return "Illegal data for A record: ". $self->recdata;
    $self->recdata($1);
  } elsif ( $self->rectype eq 'AAAA' ) {
    $self->recdata =~ /^([\da-z:]+)$/
      or return "Illegal data for AAAA record: ". $self->recdata;
    $self->recdata($1);
  } elsif ( $self->rectype eq 'PTR' ) {
    if ( $conf->exists('zone-underscore') ) {
      $self->recdata =~ /^([a-z0-9_\.\-]+)$/i
        or return "Illegal data for PTR record: ". $self->recdata;
      $self->recdata($1);
    } else {
      $self->recdata =~ /^([a-z0-9\.\-]+)$/i
        or return "Illegal data for PTR record: ". $self->recdata;
      $self->recdata($1);
    }
  } elsif ( $self->rectype eq 'CNAME' ) {
    $self->recdata =~ /^([a-z0-9\.\-]+|\@)$/i
      or return "Illegal data for CNAME record: ". $self->recdata;
    $self->recdata($1);
  } elsif ( $self->rectype eq 'TXT' ) {
    if ( $self->recdata =~ /^((?:\S+)|(?:".+"))$/ ) {
      $self->recdata($1);
    } else {
      $self->recdata('"'. $self->recdata. '"'); #?
    }
    #  or return "Illegal data for TXT record: ". $self->recdata;
  } elsif ( $self->rectype eq 'SRV' ) {                                        
    $self->recdata =~ /^(\d+)\s+(\d+)\s+(\d+)\s+([a-z0-9\.\-]+)$/i             
      or return "Illegal data for SRV record: ". $self->recdata;               
    $self->recdata("$1 $2 $3 $4");                        
  } elsif ( $self->rectype eq '_mstr' ) {
    $self->recdata =~ /^((\d{1,3}\.){3}\d{1,3})$/
      or return "Illegal data for _master pseudo-record: ". $self->recdata;
  } else {
    warn "$me no specific check for ". $self->rectype. " records yet";
    $error = $self->ut_text('recdata');
    return $error if $error;
  }

  $self->SUPER::check;
}

=item increment_serial

=cut

sub increment_serial {
  return '' if $noserial_hack;
  my $self = shift;

  my $soa = qsearchs('domain_record', {
    svcnum  => $self->svcnum,
    reczone => '@',
    recaf   => 'IN',
    rectype => 'SOA', } )
  || qsearchs('domain_record', {
    svcnum  => $self->svcnum,
    reczone => $self->svc_domain->domain.'.',
    recaf   => 'IN',
    rectype => 'SOA', 
  } )
  or return "soa record not found; can't increment serial";

  my $data = $soa->recdata;
  $data =~ s/(\(\D*)(\d+)/$1.($2+1)/e; #well, it works.

  my %hash = $soa->hash;
  $hash{recdata} = $data;
  my $new = new FS::domain_record \%hash;
  $new->replace($soa);
}

=item svc_domain

Returns the domain (see L<FS::svc_domain>) for this record.

=cut

sub svc_domain {
  my $self = shift;
  qsearchs('svc_domain', { svcnum => $self->svcnum } );
}

=item zone

Returns the canonical zone name.

=cut

sub zone {
  my $self = shift;
  my $zone = $self->reczone; # or die ?
  if ( $zone =~ /\.$/ ) {
    $zone =~ s/\.$//;
  } else {
    my $svc_domain = $self->svc_domain; # or die ?
    $zone .= '.'. $svc_domain->domain;
    $zone =~ s/^\@\.//;
  }
  $zone;
}

=item reverse_record 

Returns the corresponding reverse-ARPA record as another FS::domain_record
object.  If the specific record does not exist in the database but the 
reverse-ARPA zone itself does, an appropriate new record is created.  If no
reverse-ARPA zone is available at all, returns false.

(You can test whether or not record itself exists in the database or is a new
object that might need to be inserted by checking the recnum field)

Mostly used by the insert and delete methods - probably should see them for
examples.

=cut

sub reverse_record {
  my $self = shift;
  warn "reverse_record called\n" if $DEBUG;
  #should support classless reverse-ARPA ala rfc2317 too
  $self->recdata =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/
    or return '';
  my $domain = "$3.$2.$1.in-addr.arpa"; 
  my $ptr_reczone = $4;
  warn "reverse_record: searching for domain: $domain\n" if $DEBUG;
  my $svc_domain = qsearchs('svc_domain', { 'domain' => $domain } )
    or return '';
  warn "reverse_record: found domain: $domain\n" if $DEBUG;
  my %hash = (
    'svcnum'  => $svc_domain->svcnum,
    'reczone' => $ptr_reczone,
    'recaf'   => 'IN',
    'rectype' => 'PTR',
  );
  qsearchs('domain_record', \%hash )
    or new FS::domain_record { %hash, 'recdata' => $self->zone.'.' };
}

=item rectypes

=cut
#http://en.wikipedia.org/wiki/List_of_DNS_record_types
#DHCID?  other things?
sub rectypes {
  [ qw(A AAAA CNAME MX NS PTR SPF SRV TXT), #most common types
    #qw(DNAME), #uncommon types
    qw(DLV DNSKEY DS NSEC NSEC3 NSEC3PARAM RRSIG), #DNSSEC types
  ];
}

=back

=head1 BUGS

The data validation doesn't check everything it could.  In particular,
there is no protection against bad data that passes the regex, duplicate
SOA records, forgetting the trailing `.', impossible IP addersses, etc.  Of
course, it's still better than editing the zone files directly.  :)

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=cut

1;

