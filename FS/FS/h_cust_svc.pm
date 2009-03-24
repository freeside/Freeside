package FS::h_cust_svc;

use strict;
use vars qw( @ISA $DEBUG );
use Carp;
use FS::Record qw(qsearchs);
use FS::h_Common;
use FS::cust_svc;

@ISA = qw( FS::h_Common FS::cust_svc );

$DEBUG = 0;

sub table { 'h_cust_svc'; }

=head1 NAME

FS::h_cust_svc - Object method for h_cust_svc objects

=head1 SYNOPSIS

=head1 DESCRIPTION

An FS::h_cust_svc object  represents a historical service.  FS::h_cust_svc
inherits from FS::h_Common and FS::cust_svc.

=head1 METHODS

=over 4

=item date_deleted

Returns the date this service was deleted, if any.

=cut

sub date_deleted {
  my $self = shift;
  $self->h_date('delete');
}

=item label END_TIMESTAMP [ START_TIMESTAMP ] 

Returns a label for this historical service, if the service was created before
END_TIMESTAMP and (optionally) not deleted before START_TIMESTAMP.  Otherwise,
returns an empty list.

If a service is found, returns a list consisting of:
- The name of this historical service (from part_svc)
- A meaningful identifier (username, domain, or mail alias)
- The table name (i.e. svc_domain) for this historical service

=cut

sub label      { shift->_label('svc_label',      @_); }
sub label_long { shift->_label('svc_label_long', @_); }

sub _label {
  my $self = shift;
  my $method = shift;

  #carp "FS::h_cust_svc::_label called on $self" if $DEBUG;
  warn "FS::h_cust_svc::_label called on $self for $method" if $DEBUG;
  my $svc_x = $self->h_svc_x(@_);
  return () unless $svc_x;
  my $part_svc = $self->part_svc;

  unless ($svc_x) {
    carp "can't find h_". $self->part_svc->svcdb. '.svcnum '. $self->svcnum if $DEBUG;
    return $part_svc->svc, 'n/a', $part_svc->svcdb;
  }

  my @label;
  eval { @label = $self->$method($svc_x, @_); };

  if ($@) {
    carp 'while resolving history record for svcdb/svcnum ' . 
         $part_svc->svcdb . '/' . $self->svcnum . ': ' . $@ if $DEBUG;
    return $part_svc->svc, 'n/a', $part_svc->svcdb;
  } else {
    return @label;
  }

}

=item h_svc_x END_TIMESTAMP [ START_TIMESTAMP ] 

Returns the FS::h_svc_XXX object for this service as of END_TIMESTAMP (i.e. an
FS::h_svc_acct object or FS::h_svc_domain object, etc.) and (optionally) not
cancelled before START_TIMESTAMP.

=cut

#false laziness w/cust_pkg::h_cust_svc
sub h_svc_x {
  my $self = shift;
  my $svcdb = $self->part_svc->svcdb;

  warn "requiring FS/h_$svcdb.pm" if $DEBUG;
  require "FS/h_$svcdb.pm";
  my $svc_x = qsearchs(
    "h_$svcdb",
    { 'svcnum' => $self->svcnum, },
    "FS::h_$svcdb"->sql_h_searchs(@_),
  ) || $self->SUPER::svc_x;

  if ($svc_x) {
    carp "Using $svcdb in place of missing h_${svcdb} record."
      if ($svc_x->isa('FS::' . $svcdb) and $DEBUG);
    return $svc_x;
  } else {
    return '';
  }

}

# _upgrade_data
#
# Used by FS::Upgrade to migrate to a new database.

use FS::UID qw( driver_name dbh );

sub _upgrade_data {  # class method
  my ($class, %opts) = @_;

  warn "[FS::h_cust_svc] upgrading $class\n" if $DEBUG;

  return if driver_name =~ /^mysql/; #You can't specify target table 'h_cust_svc' for update in FROM clause

  my $sql = "
    DELETE FROM h_cust_svc
      WHERE history_action = 'delete'
        AND historynum != ( SELECT min(historynum) FROM h_cust_svc AS main
                              WHERE main.history_date = h_cust_svc.history_date
                                AND main.history_user = h_cust_svc.history_user
                                AND main.svcnum       = h_cust_svc.svcnum
                                AND main.svcpart      = h_cust_svc.svcpart
                                AND ( main.pkgnum     = h_cust_svc.pkgnum
                                      OR ( main.pkgnum IS NULL AND h_cust_svc.pkgnum IS NULL )
                                    )
                                AND ( main.overlimit  = h_cust_svc.overlimit
                                      OR ( main.overlimit IS NULL AND h_cust_svc.overlimit IS NULL )
                                    )
                          )
  ";

  warn $sql if $DEBUG;
  my $sth = dbh->prepare($sql) or die dbh->errstr;
  $sth->execute or die $sth->errstr;

}

=back

=head1 BUGS

=head1 SEE ALSO

L<FS::h_Common>, L<FS::cust_svc>, L<FS::Record>, schema.html from the base
documentation.

=cut

1;

