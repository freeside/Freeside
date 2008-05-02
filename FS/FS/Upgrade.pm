package FS::Upgrade;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Exporter;
use Tie::IxHash;
use FS::UID qw( dbh driver_name );
use FS::Record;

use FS::svc_domain;
$FS::svc_domain::whois_hack = 1;

@ISA = qw( Exporter );
@EXPORT_OK = qw( upgrade );

=head1 NAME

FS::Upgrade - Database upgrade routines

=head1 SYNOPSIS

  use FS::Upgrade;

=head1 DESCRIPTION

Currently this module simply provides a place to store common subroutines for
database upgrades.

=head1 SUBROUTINES

=over 4

=item

=cut

sub upgrade {
  my %opt = @_;

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  $FS::UID::AutoCommit = 0;

  my $data = upgrade_data(%opt);

  foreach my $table ( keys %$data ) {

    my $class = "FS::$table";
    eval "use $class;";
    die $@ if $@;

    if ( $class->can('_upgrade_data') ) {
      $class->_upgrade_data(%opt);
    } else {
      warn "WARNING: asked for upgrade of $table,".
           " but FS::$table has no _upgrade_data method\n";
    }

#    my @records = @{ $data->{$table} };
#
#    foreach my $record ( @records ) {
#      my $args = delete($record->{'_upgrade_args'}) || [];
#      my $object = $class->new( $record );
#      my $error = $object->insert( @$args );
#      die "error inserting record into $table: $error\n"
#        if $error;
#    }

  }

  if ( $oldAutoCommit ) {
    dbh->commit or die dbh->errstr;
  }

}


sub upgrade_data {
  my %opt = @_;

  tie my %hash, 'Tie::IxHash', 

    #reason type and reasons
    'reason_type' => [],
    'reason'      => [],

    #need part_pkg before cust_credit...
    'part_pkg' => [],

    #customer credits
    'cust_credit' => [],

    #duplicate history records
    'h_cust_svc'  => [],

    #populate cust_pay.otaker
    'cust_pay'    => [],

    #populate part_pkg_taxclass for starters
    'part_pkg_taxclass' => [],

  ;

  \%hash;

}


=back

=head1 BUGS

Sure.

=head1 SEE ALSO

=cut

1;

